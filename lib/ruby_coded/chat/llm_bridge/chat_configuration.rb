# frozen_string_literal: true

module RubyCoded
  module Chat
    class LLMBridge
      # Applies tool/instruction configuration to the RubyLLM chat based on
      # the active mode (agentic, plan, or plain chat).
      module ChatConfiguration
        private

        def apply_instructions_if_supported(chat, instructions)
          return unless chat.respond_to?(:with_instructions)

          chat.with_instructions(instructions)
        end

        def reconfigure_chat!
          @chat_mutex.synchronize do
            apply_mode_config!(@chat)
          end
        end

        def apply_mode_config!(chat)
          case @mode.name
          when :agent then configure_agentic!(chat)
          when :plan then configure_plan!(chat)
          else configure_chat!(chat)
          end
        end

        def configure_chat!(chat)
          chat.with_tools(replace: true)
          apply_instructions_if_supported(chat, @prompt_builder.build(RuntimeMode.chat))
        end
      end
    end
  end
end
