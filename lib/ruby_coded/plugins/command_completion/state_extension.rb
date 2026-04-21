# frozen_string_literal: true

module RubyCoded
  module Plugins
    module CommandCompletion
      # Mixed into Chat::State to add command-completion tracking.
      module StateExtension
        def self.included(base)
          base.attr_reader :command_completion_index
        end

        def init_command_completion
          @command_completion_index = 0
        end

        def command_completion_active?
          buf = @input_buffer
          buf.start_with?("/") && !buf.include?(" ") && !command_suggestions.empty?
        end

        # Returns an array of [command, description] pairs matching the
        # current input buffer prefix.
        def command_suggestions
          prefix = @input_buffer.downcase
          all_descriptions = merged_command_descriptions
          all_descriptions.select { |cmd, _| cmd.downcase.start_with?(prefix) }
                          .sort_by { |cmd, _| cmd.downcase }
        end

        def current_command_suggestion
          suggestions = command_suggestions
          return nil if suggestions.empty?

          idx = @command_completion_index % suggestions.size
          suggestions[idx]
        end

        def command_completion_up
          suggestions = command_suggestions
          return if suggestions.empty?

          @command_completion_index = (@command_completion_index - 1) % suggestions.size
        end

        def command_completion_down
          suggestions = command_suggestions
          return if suggestions.empty?

          @command_completion_index = (@command_completion_index + 1) % suggestions.size
        end

        def accept_command_completion!
          suggestion = current_command_suggestion
          return unless suggestion

          cmd, = suggestion
          @input_buffer.clear
          @input_buffer << cmd
          @cursor_position = @input_buffer.length
          @command_completion_index = 0
        end

        # Reset index when the buffer changes so selection stays coherent.
        def reset_command_completion_index
          @command_completion_index = 0
        end

        private

        def merged_command_descriptions
          return {} unless respond_to?(:command_catalog) && command_catalog

          command_catalog.command_descriptions
        end
      end
    end
  end
end
