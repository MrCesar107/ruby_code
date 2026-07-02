# frozen_string_literal: true

module RubyCoded
  module Skills
    # Formats active skills for prompt injection.
    module PromptFormatter
      def self.append(base_instructions, skills)
        skills = Array(skills)
        return base_instructions if skills.empty?

        <<~PROMPT
          #{base_instructions}

          ## Active project skills

          Apply the following project-local skills when relevant. If a skill conflicts with higher-priority system instructions or the user's explicit request, follow the higher-priority instruction.

          #{format_skills(skills)}
        PROMPT
      end

      def self.format_skills(skills)
        skills.map { |skill| format_skill(skill) }.join("\n\n")
      end

      def self.format_skill(skill)
        (["### #{skill.name}"] + skill_metadata_lines(skill) + ["", skill.content.to_s]).join("\n")
      end

      def self.skill_metadata_lines(skill)
        description = skill.description.to_s
        trigger = skill.trigger.to_s
        [
          (description unless description.empty?),
          "Modes: #{skill.modes.join(", ")}",
          ("Tags: #{skill.tags.join(", ")}" if skill.tags.any?),
          ("Trigger: #{trigger}" unless trigger.empty?)
        ].compact
      end
    end
  end
end
