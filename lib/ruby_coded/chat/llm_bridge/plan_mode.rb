# frozen_string_literal: true

module RubyCoded
  module Chat
    class LLMBridge
      # Plan mode configuration and plan/clarification post-processing.
      # Auto-switch heuristic lives in BridgeCommon.
      module PlanMode
        private

        def configure_plan!(chat)
          readonly_tools = @tool_registry.build_readonly_tools
          chat.with_tools(*readonly_tools, replace: true)
          apply_instructions_if_supported(chat, @prompt_builder.build(RuntimeMode.plan))

          chat.on_tool_call { |tool_call| handle_tool_call(tool_call) }
          chat.on_tool_result { |result| handle_tool_result(result) }
        end

        def post_process_plan_response
          last_msg = @state.messages_snapshot.last
          return unless last_msg && last_msg[:role] == :assistant

          content = last_msg[:content]
          if PlanClarificationParser.clarification?(content)
            handle_plan_clarification(content)
          else
            @state.update_current_plan!(content)
          end
        end

        def handle_plan_clarification(content)
          parsed = PlanClarificationParser.parse(content)
          return unless parsed

          stripped = PlanClarificationParser.strip_clarification(content)
          @state.reset_last_assistant_content
          @state.append_to_last_message(stripped) unless stripped.empty?
          @state.enter_plan_clarification!(parsed[:question], parsed[:options])
        end
      end
    end
  end
end
