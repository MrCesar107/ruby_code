# frozen_string_literal: true

require_relative "../../tools/agent_cancelled_error"
require_relative "../../tools/tool_rejected_error"

module RubyCoded
  module Chat
    module BridgeCommon
      # Shared tool-confirmation flow and cancellation signaling.
      # Uses the State's condition variable to block the streaming
      # thread until the TUI supplies a decision (approve/reject/cancel).
      module ToolFlow
        def cancel!
          @cancel_requested = true
          @state.mutex.synchronize { @state.tool_cv.signal }
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

        private

        def poll_tool_decision
          @state.mutex.synchronize do
            loop do
              return :cancelled if @cancel_requested

              resp = @state.instance_variable_get(:@tool_confirmation_response)
              return resp if %i[approved rejected].include?(resp)

              @state.tool_cv.wait(@state.mutex, 0.1)
            end
          end
        end

        def apply_tool_decision(decision, display_name)
          case decision
          when :cancelled
            @state.clear_tool_confirmation!
            raise Tools::AgentCancelledError, "Operation cancelled by user"
          when :approved
            @state.resolve_tool_confirmation!(:approved)
          when :rejected
            @state.resolve_tool_confirmation!(:rejected)
            raise Tools::ToolRejectedError, "User rejected #{display_name}"
          end
        end
      end
    end
  end
end
