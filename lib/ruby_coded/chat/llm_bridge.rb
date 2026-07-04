# frozen_string_literal: true

require "ruby_llm"
require_relative "../tools/registry"
require_relative "../tools/system_prompt"
require_relative "../tools/plan_system_prompt"
require_relative "../tools/agent_cancelled_error"
require_relative "../tools/agent_iteration_limit_error"
require_relative "../tools/execution_policy"
require_relative "../skills"
require_relative "plan_clarification_parser"
require_relative "runtime_mode"
require_relative "bridge_common"
require_relative "prompt_builder"
require_relative "llm_bridge/tool_call_handling"
require_relative "llm_bridge/streaming_retries"
require_relative "llm_bridge/plan_mode"
require_relative "llm_bridge/chat_configuration"

module RubyCoded
  module Chat
    # Sends prompts to RubyLLM and streams assistant output into State.
    class LLMBridge
      include BridgeCommon
      include ToolCallHandling
      include StreamingRetries
      include PlanMode
      include ChatConfiguration

      MAX_RATE_LIMIT_RETRIES = 2
      RATE_LIMIT_BASE_DELAY = 2
      MAX_WRITE_TOOL_ROUNDS = Tools::ExecutionPolicy::MAX_WRITE_TOOL_ROUNDS
      MAX_TOTAL_TOOL_ROUNDS = Tools::ExecutionPolicy::MAX_TOTAL_TOOL_ROUNDS
      MAX_TOOL_RESULT_CHARS = 10_000

      attr_reader :mode, :project_root

      def initialize(state, project_root: Dir.pwd, skill_catalog: nil)
        @state = state
        @chat_mutex = Mutex.new
        @cancel_requested = false
        @project_root = project_root
        @skill_catalog = skill_catalog || RubyCoded::Skills::Catalog.new(project_root: @project_root)
        @mode = RuntimeMode.chat
        setup_agent_pipeline!
        reset_chat!(@state.model)
      end

      def reset_chat!(model_name)
        @chat_mutex.synchronize do
          @chat = RubyLLM.chat(model: model_name)
          apply_mode_config!(@chat)
        end
      end

      def reset_agent_session!
        @policy.reset_counters!
        reset_chat!(@state.model)
      end

      def send_async(input)
        auto_switch_to_agent! if should_auto_switch_to_agent?(input)
        reset_call_counts
        chat = prepare_streaming
        Thread.new do
          response = attempt_with_retries(chat, input)
          update_response_tokens(response)
          post_process_plan_response if @mode.plan? && !@cancel_requested
        ensure
          @state.streaming = false
        end
      end

      private

      def setup_agent_pipeline!
        @tool_registry = Tools::Registry.new(project_root: @project_root)
        @policy = Tools::ExecutionPolicy.new(state: @state, registry: @tool_registry)
        @prompt_builder = PromptBuilder.new(
          project_root: @project_root,
          skill_catalog: @skill_catalog,
          chat_base: :agentic
        )
      end

      def reset_call_counts
        @policy.reset_counters!
      end

      # Called by BridgeCommon after any mode transition to
      # re-apply tools/instructions on the RubyLLM chat.
      def after_mode_change!
        reconfigure_chat!
      end
    end
  end
end
