# frozen_string_literal: true

module RubyCoded
  module Chat
    class CommandHandler
      # Slash commands for managing project-local skills.
      module SkillCommands
        private

        def cmd_skills(rest)
          case rest&.strip&.downcase
          when "reload"
            reload_skills
          when "list"
            list_skills
          else
            @state.add_message(:system, "Usage: /skills [reload|list]")
          end
        end

        def reload_skills
          return missing_skill_catalog unless @skill_catalog

          report = @skill_catalog.reload!
          @state.add_message(:system, format_skill_reload_message(report))
        end

        def list_skills
          return missing_skill_catalog unless @skill_catalog

          skills = @skill_catalog.all_skills
          return show_empty_skills if skills.empty?

          @state.add_message(:system, formatted_skills(skills))
        end

        def missing_skill_catalog
          @state.add_message(:system, "Skill catalog is not available.")
        end

        def show_empty_skills
          @state.add_message(
            :system,
            "No project skills loaded. Add markdown files under .rubycoded/skills and run /skills reload."
          )
        end

        def formatted_skills(skills)
          lines = ["Project skills:"]
          skills.each do |skill|
            lines << format_skill_line(skill)
          end
          lines.join("\n")
        end

        def format_skill_line(skill)
          modes = skill.modes.join(", ")
          "  #{skill.name.ljust(24)} #{skill.description} [modes: #{modes}]"
        end

        def format_skill_reload_message(report)
          message = skill_reload_summary(report)
          details = skill_reload_details(report)

          details.empty? ? message : "#{message}\n#{details.join("\n")}"
        end

        def skill_reload_summary(report)
          "Skills reloaded. " \
            "Added: #{report[:added]}, removed: #{report[:removed]}, " \
            "total skills: #{report[:total]}, invalid files ignored: #{report[:invalid]}, " \
            "duplicates ignored: #{report[:duplicates]}."
        end

        def skill_reload_details(report)
          invalid_files = Array(report[:invalid_files])
          duplicate_skills = Array(report[:duplicate_skills])

          details = []
          details << "Invalid files: #{invalid_files.join(", ")}" if invalid_files.any?
          details << "Duplicate skills: #{duplicate_skills.join(", ")}" if duplicate_skills.any?
          details
        end
      end
    end
  end
end
