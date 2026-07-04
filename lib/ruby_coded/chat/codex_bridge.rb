# frozen_string_literal: true

require "faraday"
require "json"
require "time"

require_relative "../tools/registry"
require_relative "../tools/system_prompt"
require_relative "../tools/plan_system_prompt"
require_relative "../tools/agent_cancelled_error"
require_relative "../tools/agent_iteration_limit_error"
require_relative "../tools/execution_policy"
require_relative "../skills"
require_relative "../auth/jwt_decoder"
require_relative "runtime_mode"
require_relative "bridge_common"
require_relative "prompt_builder"
require_relative "codex_bridge/request_builder"
require_relative "codex_bridge/sse_parser"
require_relative "codex_bridge/tool_handling"
require_relative "codex_bridge/token_manager"
require_relative "codex_bridge/error_handling"

module RubyCoded
  module Chat
    # Raised when the Codex HTTP API returns a non-2xx response.
    class CodexAPIError < StandardError
      attr_reader :status

      def initialize(status, detail)
        @status = status
        super("HTTP #{status}: #{detail}")
      end
    end

    # HTTP client for the ChatGPT Codex backend (Responses API).
    # Implements the same public interface as LLMBridge so App can
    # swap between them based on the active auth_method.
    class CodexBridge
      include BridgeCommon
      include RequestBuilder
      include SSEParser
      include ToolHandling
      include TokenManager
      include ErrorHandling

      CODEX_BASE_URL = "https://chatgpt.com"
      CODEX_RESPONSES_PATH = "/backend-api/codex/responses"
      DEFAULT_MODEL = "gpt-5.4"

      MAX_RATE_LIMIT_RETRIES = 2
      RATE_LIMIT_BASE_DELAY = 2
      MAX_WRITE_TOOL_ROUNDS = Tools::ExecutionPolicy::MAX_WRITE_TOOL_ROUNDS
      MAX_TOTAL_TOOL_ROUNDS = Tools::ExecutionPolicy::MAX_TOTAL_TOOL_ROUNDS
      MAX_TOOL_RESULT_CHARS = 10_000

      attr_reader :mode, :project_root

      def initialize(state, credentials_store:, auth_manager:, project_root: Dir.pwd, skill_catalog: nil)
        @state = state
        @credentials_store = credentials_store
        @auth_manager = auth_manager
        @project_root = project_root
        @skill_catalog = skill_catalog || RubyCoded::Skills::Catalog.new(project_root: @project_root)
        initialize_runtime_state
      end

      def initialize_runtime_state
        @cancel_requested = false
        @mode = RuntimeMode.chat
        @model = @state.model
        @conversation_history = []
        setup_agent_pipeline!
        reset_call_counts
        @conn = build_connection
      end

      def send_async(input)
        prepare_send(input)
        @conversation_history << { role: "user", content: input }
        Thread.new do
          attempt_with_retries(input)
        ensure
          @state.streaming = false
        end
      end

      def reset_chat!(model_name)
        @model = model_name
        @conversation_history = []
      end

      def reset_agent_session!
        @policy.reset_counters!
        @conversation_history = []
      end

      private

      def setup_agent_pipeline!
        @tool_registry = Tools::Registry.new(project_root: @project_root)
        @policy = Tools::ExecutionPolicy.new(state: @state, registry: @tool_registry)
        @prompt_builder = PromptBuilder.new(
          project_root: @project_root,
          skill_catalog: @skill_catalog,
          chat_base: :simple
        )
      end
    end
  end
end
