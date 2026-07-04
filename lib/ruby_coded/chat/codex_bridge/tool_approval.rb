# frozen_string_literal: true

module RubyCoded
  module Chat
    class CodexBridge
      # Interactive approval flow for tool calls in the Codex backend.
      # Uses the shared ExecutionPolicy for the confirmation decision
      # and BridgeCommon for polling/applying the user's response.
      module ToolApproval
        private

        def request_approval(_tool_call, display_name, args, risk)
          args_summary = args.map { |k, v| "#{k}: #{v}" }.join(", ")

          if @policy.requires_confirmation?(risk, @mode)
            @state.request_tool_confirmation!(display_name, args,
                                              risk_label: @policy.risk_label_for(risk))
            decision = poll_tool_decision
            apply_tool_decision(decision, display_name)
          else
            @state.add_message(:tool_call, "[#{display_name}] #{args_summary}")
          end
        end
      end
    end
  end
end
