# frozen_string_literal: true

require_relative "../tools/system_prompt"
require_relative "../tools/plan_system_prompt"
require_relative "../tools/execution_policy"
require_relative "../skills/prompt_formatter"

module RubyCoded
  module Chat
    # Assembles the final system instruction set for a given RuntimeMode.
    #
    # Composes the base prompt (agent/plan/chat) with project skills
    # for the same mode. Both LLMBridge and CodexBridge use this to
    # keep prompt logic in a single place.
    class PromptBuilder
      DEFAULT_CHAT_INSTRUCTIONS = "You are a helpful coding assistant. " \
                                  "Answer concisely and provide code examples when relevant."

      MAX_WRITE_ROUNDS = Tools::ExecutionPolicy::MAX_WRITE_TOOL_ROUNDS
      MAX_TOTAL_ROUNDS = Tools::ExecutionPolicy::MAX_TOTAL_TOOL_ROUNDS

      # `chat_base`:
      #   - `:agentic` — chat mode still uses the full agentic prompt
      #     (matches LLMBridge, where tools may still be relevant),
      #   - `:simple`  — chat mode uses a light default instruction
      #     (matches the Codex Responses API).
      def initialize(project_root:, skill_catalog:, chat_base: :agentic)
        @project_root = project_root
        @skill_catalog = skill_catalog
        @chat_base = chat_base
      end

      def build(mode)
        base = base_instructions(mode)
        skills = @skill_catalog.relevant_skills_for(mode: mode.skill_mode)
        Skills::PromptFormatter.append(base, skills)
      end

      private

      def base_instructions(mode)
        case mode.name
        when :agent then agentic_prompt
        when :plan then plan_prompt
        else chat_prompt
        end
      end

      def chat_prompt
        @chat_base == :simple ? DEFAULT_CHAT_INSTRUCTIONS : agentic_prompt
      end

      def agentic_prompt
        Tools::SystemPrompt.build(
          project_root: @project_root,
          max_write_rounds: MAX_WRITE_ROUNDS,
          max_total_rounds: MAX_TOTAL_ROUNDS
        )
      end

      def plan_prompt
        Tools::PlanSystemPrompt.build(project_root: @project_root)
      end
    end
  end
end
