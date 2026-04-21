# frozen_string_literal: true

require_relative "command_definition"

module RubyCoded
  module Commands
    # Adapts plugin-registered commands to the unified command catalog.
    class PluginProvider
      def initialize(registry:)
        @registry = registry
      end

      def definitions
        commands.map { |name, handler| build_definition(name, handler) }
      end

      private

      def commands
        @registry.all_commands
      end

      def descriptions
        @registry.all_command_descriptions
      end

      def build_definition(name, handler)
        CommandDefinition.new(
          name: name,
          description: descriptions[name] || "Plugin command",
          handler: handler,
          source: :plugin,
          usage: name
        )
      end
    end
  end
end
