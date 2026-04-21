# frozen_string_literal: true

require_relative "command_definition"
require_relative "markdown_loader"

module RubyCoded
  module Commands
    # Converts markdown command files into command definitions.
    class MarkdownProvider
      def initialize(project_root:)
        @loader = MarkdownLoader.new(project_root: project_root)
      end

      def definitions
        load_report[:definitions]
      end

      def load_report
        report = @loader.load_report
        {
          definitions: build_definitions(report[:entries]),
          invalid_count: report[:invalid_count],
          invalid_files: report[:invalid_files]
        }
      end

      private

      def build_definitions(entries)
        entries.map { |entry| build_definition(entry) }
      end

      def build_definition(entry)
        CommandDefinition.new(
          name: entry[:command],
          description: entry[:description],
          source: :markdown,
          usage: entry[:usage] || entry[:command],
          content: entry[:content],
          path: entry[:path]
        )
      end
    end
  end
end
