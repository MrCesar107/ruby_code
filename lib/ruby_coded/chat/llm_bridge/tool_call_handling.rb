# frozen_string_literal: true

module RubyCoded
  module Chat
    class LLMBridge
      # Handles tool call lifecycle: invocation, confirmation, limits, and results.
      module ToolCallHandling
        private

        def configure_agentic!(chat)
          chat.with_tools(*@tool_registry.build_tools, replace: true)
          apply_instructions_if_supported(chat, @prompt_builder.build(RuntimeMode.agent))

          chat.on_tool_call { |tool_call| handle_tool_call(tool_call) }
          chat.on_tool_result { |result| handle_tool_result(result) }
        end

        def handle_tool_call(tool_call)
          raise Tools::AgentCancelledError, "Operation cancelled by user" if @cancel_requested

          display_name = short_tool_name(tool_call.name)
          risk = @policy.register_call!(tool_call.name)
          @policy.warn_if_approaching_limit!

          process_tool_approval(tool_call, display_name, risk)
        end

        def process_tool_approval(tool_call, display_name, risk)
          args_summary = tool_call.arguments.map { |k, v| "#{k}: #{v}" }.join(", ")

          if @policy.requires_confirmation?(risk, @mode)
            @state.request_tool_confirmation!(display_name, tool_call.arguments,
                                              risk_label: @policy.risk_label_for(risk))
            wait_for_confirmation(tool_call)
          else
            @state.add_message(:tool_call, "[#{display_name}] #{args_summary}")
          end
        end

        def wait_for_confirmation(tool_call)
          display_name = short_tool_name(tool_call.name)
          decision = poll_tool_decision
          apply_tool_decision(decision, display_name)
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
            raise RubyCoded::Tools::ToolRejectedError, "User rejected #{display_name}"
          end
        end

        def poll_tool_decision
          @state.mutex.synchronize do
            loop do
              return :cancelled if @cancel_requested

              case @state.instance_variable_get(:@tool_confirmation_response)
              when :approved then return :approved
              when :rejected then return :rejected
              end

              @state.tool_cv.wait(@state.mutex, 0.1)
            end
          end
        end

        def handle_tool_result(result)
          text = result.to_s
          if text.length > MAX_TOOL_RESULT_CHARS
            text = "#{text[0, MAX_TOOL_RESULT_CHARS]}\n... (truncated, #{text.length} total characters)"
          end
          @state.add_message(:tool_result, text)
        end

        def short_tool_name(name)
          name.split("--").last
        end
      end
    end
  end
end
