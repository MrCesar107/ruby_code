# frozen_string_literal: true

require "faraday"
require "json"
require "time"

require_relative "../tools/registry"
require_relative "../tools/system_prompt"
require_relative "../tools/plan_system_prompt"
require_relative "../tools/agent_cancelled_error"
require_relative "../tools/agent_iteration_limit_error"
require_relative "../auth/jwt_decoder"
require_relative "codex_bridge/request_builder"
require_relative "codex_bridge/sse_parser"
require_relative "codex_bridge/tool_handling"
require_relative "codex_bridge/token_manager"

module RubyCoded
  module Chat
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
      include RequestBuilder
      include SSEParser
      include ToolHandling
      include TokenManager

      CODEX_BASE_URL = "https://chatgpt.com"
      CODEX_RESPONSES_PATH = "/backend-api/codex/responses"
      DEFAULT_MODEL = "gpt-5.4"

      MAX_RATE_LIMIT_RETRIES = 2
      RATE_LIMIT_BASE_DELAY = 2
      MAX_WRITE_TOOL_ROUNDS = 50
      MAX_TOTAL_TOOL_ROUNDS = 200
      TOOL_ROUNDS_WARNING_THRESHOLD = 0.8
      MAX_TOOL_RESULT_CHARS = 10_000

      attr_reader :agentic_mode, :plan_mode, :project_root

      def initialize(state, credentials_store:, auth_manager:, project_root: Dir.pwd)
        @state = state
        @credentials_store = credentials_store
        @auth_manager = auth_manager
        @project_root = project_root
        @cancel_requested = false
        @agentic_mode = false
        @plan_mode = false
        @model = state.model
        @conversation_history = []
        @tool_registry = Tools::Registry.new(project_root: @project_root)
        @tool_call_count = 0
        @write_tool_call_count = 0
        @conn = build_connection
      end

      def send_async(input)
        auto_switch_to_agent! if should_auto_switch_to_agent?(input)
        reset_call_counts
        @cancel_requested = false
        @state.streaming = true
        @state.add_message(:assistant, "")

        @conversation_history << { role: "user", content: input }

        Thread.new do
          attempt_with_retries(input)
        ensure
          @state.streaming = false
        end
      end

      def cancel!
        @cancel_requested = true
        @state.mutex.synchronize { @state.tool_cv.signal }
      end

      def reset_chat!(model_name)
        @model = model_name
        @conversation_history = []
      end

      def toggle_agentic_mode!(enabled)
        @agentic_mode = enabled
        @state.agentic_mode = enabled
        if enabled && @plan_mode
          @plan_mode = false
          @state.deactivate_plan_mode!
        end
        @state.disable_auto_approve! unless enabled
      end

      def toggle_plan_mode!(enabled)
        @plan_mode = enabled
        if enabled && @agentic_mode
          @agentic_mode = false
          @state.agentic_mode = false
          @state.disable_auto_approve!
        end
      end

      def approve_tool!
        @state.tool_confirmation_response = :approved
      end

      def approve_all_tools!
        @state.enable_auto_approve!
        @state.tool_confirmation_response = :approved
      end

      def reject_tool!
        @state.tool_confirmation_response = :rejected
      end

      def reset_agent_session!
        @tool_call_count = 0
        @write_tool_call_count = 0
        @conversation_history = []
      end

      private

      def build_connection
        Faraday.new(url: CODEX_BASE_URL) do |f|
          f.options.timeout = 300
          f.options.open_timeout = 30
        end
      end

      def reset_call_counts
        @tool_call_count = 0
        @write_tool_call_count = 0
      end

      def should_auto_switch_to_agent?(input)
        @plan_mode && @state.respond_to?(:current_plan) && @state.current_plan &&
          input.match?(/\b(implement|go ahead|proceed|execut|ejecutar?|comenz|comienz|hazlo|constru[iy]|adelante|dale|do it|build it)\b/i)
      end

      def auto_switch_to_agent!
        toggle_agentic_mode!(true)
        @state.add_message(:system,
                           "Plan mode disabled — switching to agent mode to implement the plan.")
      end

      def attempt_with_retries(input, retries = 0)
        perform_codex_request(input)
      rescue Tools::AgentCancelledError, Tools::AgentIterationLimitError, Tools::ToolRejectedError => e
        @state.add_message(:system, e.message)
      rescue CodexAPIError => e
        @state.fail_last_assistant(e, friendly_message: codex_error_message(e))
      rescue Faraday::TooManyRequestsError => e
        retry if (retries = handle_rate_limit_retry(e, retries))
        @state.fail_last_assistant(e, friendly_message: rate_limit_message(e))
      rescue StandardError => e
        @state.fail_last_assistant(e, friendly_message: "Codex API error: #{e.message}")
      end

      def handle_rate_limit_retry(error, retries)
        return unless retries < MAX_RATE_LIMIT_RETRIES && !@cancel_requested

        retries += 1
        delay = RATE_LIMIT_BASE_DELAY * (2**(retries - 1))
        @state.fail_last_assistant(
          error,
          friendly_message: "Rate limit reached. Retrying in #{delay}s... (#{retries}/#{MAX_RATE_LIMIT_RETRIES})"
        )
        sleep(delay)
        @state.reset_last_assistant_content
        retries
      end

      def codex_error_message(error)
        case error.status
        when 401
          "Authentication failed. Your OAuth session may have expired. Try /login to re-authenticate. (#{error.message})"
        when 403
          "Access denied. Your ChatGPT subscription may not include Codex access. (#{error.message})"
        when 404
          "Codex endpoint not found. The API may have changed. (#{error.message})"
        when 429
          rate_limit_message(error)
        else
          "Codex API error: #{error.message}"
        end
      end

      def rate_limit_message(error)
        <<~MSG.strip
          ChatGPT usage limit reached. This may be a 5-hour or weekly limit on your Plus/Pro subscription.
          Wait and try again later. Detail: #{error.message}
        MSG
      end
    end
  end
end
