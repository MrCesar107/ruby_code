# frozen_string_literal: true

module RubyCoded
  module Chat
    class CommandHandler
      # Slash commands for managing custom markdown commands.
      module CustomCommands
        private

        def cmd_commands(rest)
          case rest&.strip&.downcase
          when "reload"
            reload_commands
          when "list"
            list_commands
          else
            @state.add_message(:system, "Usage: /commands [reload|list]")
          end
        end

        def reload_commands
          return missing_command_catalog unless @command_catalog

          report = @command_catalog.reload!
          @commands = build_command_map
          @state.add_message(:system, format_reload_message(report))
        end

        def list_commands
          return missing_command_catalog unless @command_catalog

          commands = @command_catalog.definitions_for_source(:markdown)
          return show_empty_custom_commands if commands.empty?

          @state.add_message(:system, formatted_custom_commands(commands))
        end

        def missing_command_catalog
          @state.add_message(:system, "Command catalog is not available.")
        end

        def show_empty_custom_commands
          @state.add_message(
            :system,
            "No custom commands loaded. Add markdown files under .ruby_coded/commands " \
            "and run /commands reload."
          )
        end

        def formatted_custom_commands(commands)
          lines = ["Custom commands:"]
          commands.sort_by { |definition| definition.name.downcase }.each do |definition|
            lines << formatted_command_line(definition)
          end
          lines.join("\n")
        end

        def format_reload_message(report)
          message = reload_summary(report)
          details = reload_details(report)
          return message if details.empty?

          "#{message}\n#{details.join("\n")}"
        end

        def reload_summary(report)
          "Commands reloaded. " \
            "Added: #{report[:added]}, removed: #{report[:removed]}, " \
            "total custom commands: #{report[:total]}, " \
            "invalid files ignored: #{report[:invalid]}, " \
            "conflicts ignored: #{report[:conflicts]}."
        end

        def reload_details(report)
          details = []
          invalid_files = Array(report[:invalid_files])
          conflict_commands = Array(report[:conflict_commands])

          details << "Invalid files: #{invalid_files.join(", ")}" if invalid_files.any?
          details << "Conflicting commands: #{conflict_commands.join(", ")}" if conflict_commands.any?
          details
        end

        def formatted_command_line(definition)
          usage = definition.usage || definition.name
          "  #{usage.ljust(28)} #{definition.description}"
        end
      end
    end
  end
end
