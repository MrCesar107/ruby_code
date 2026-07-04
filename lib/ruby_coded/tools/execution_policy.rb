# frozen_string_literal: true

require_relative "base_tool"
require_relative "agent_iteration_limit_error"

module RubyCoded
  module Tools
    # Centralizes runtime safety policy for tool execution:
    #
    # - risk lookup (delegated to the registry),
    # - call budgeting (write vs total rounds, warning threshold),
    # - confirmation requirement based on risk, mode, and auto-approve.
    #
    # Both LLMBridge and CodexBridge share a policy instance so
    # limits and approval rules stay consistent across backends.
    class ExecutionPolicy
      MAX_WRITE_TOOL_ROUNDS = 50
      MAX_TOTAL_TOOL_ROUNDS = 200
      WARNING_THRESHOLD_RATIO = 0.8

      def initialize(state:, registry:)
        @state = state
        @registry = registry
        reset_counters!
      end

      def reset_counters!
        @tool_call_count = 0
        @write_tool_call_count = 0
      end

      def risk_for(tool_name)
        @registry.risk_level_for(tool_name)
      end

      # Records the call, enforces hard limits, and returns the risk level.
      # Raises AgentIterationLimitError when the total budget is exceeded.
      def register_call!(tool_name)
        risk = risk_for(tool_name)
        @tool_call_count += 1
        @write_tool_call_count += 1 unless risk == BaseTool::SAFE_RISK
        enforce_limits!
        risk
      end

      def warn_if_approaching_limit!
        threshold = warning_threshold
        return unless @tool_call_count == threshold

        remaining = MAX_TOTAL_TOOL_ROUNDS - threshold
        @state.add_message(:system,
                           "Approaching total tool call limit: #{remaining} calls remaining. " \
                           "Prioritize completing the most important work.")
      end

      # True when the user must confirm this call before it runs.
      def requires_confirmation?(risk, mode)
        return false if risk == BaseTool::SAFE_RISK
        return false if @state.auto_approve_tools?

        mode.requires_confirmation?
      end

      def risk_label_for(risk)
        risk == BaseTool::DANGEROUS_RISK ? "DANGEROUS" : "WRITE"
      end

      private

      def warning_threshold
        (MAX_TOTAL_TOOL_ROUNDS * WARNING_THRESHOLD_RATIO).to_i
      end

      def enforce_limits!
        if @write_tool_call_count >= MAX_WRITE_TOOL_ROUNDS
          @write_tool_call_count = 0
          @state.add_message(:system,
                             "Write tool call budget (#{MAX_WRITE_TOOL_ROUNDS}) reached — auto-resetting counter.")
        end

        return unless @tool_call_count > MAX_TOTAL_TOOL_ROUNDS

        raise AgentIterationLimitError,
              "Reached maximum of #{MAX_TOTAL_TOOL_ROUNDS} total tool calls. " \
              "Send a new message to continue, or use /agent on to reset counters."
      end
    end
  end
end
