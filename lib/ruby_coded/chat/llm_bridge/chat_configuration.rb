# frozen_string_literal: true

module RubyCoded
  module Chat
    class LLMBridge
      # Applies tool/instruction configuration to the RubyLLM chat based on
      # the active mode (agentic, plan, or plain chat).
      module ChatConfiguration
        private

        def skills_for_mode(mode, input: nil)
          @skill_catalog.relevant_skills_for(mode: mode, input: input)
        end

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
          if @agentic_mode
            configure_agentic!(chat)
          elsif @plan_mode
            configure_plan!(chat)
          else
            configure_chat!(chat)
          end
        end

        def configure_chat!(chat)
          chat.with_tools(replace: true)
          instructions = Tools::SystemPrompt.build(
            project_root: @project_root,
            max_write_rounds: MAX_WRITE_TOOL_ROUNDS,
            max_total_rounds: MAX_TOTAL_TOOL_ROUNDS
          )
          apply_instructions_if_supported(
            chat,
            RubyCoded::Skills::PromptFormatter.append(instructions, skills_for_mode(:chat))
          )
        end
      end
    end
  end
end
