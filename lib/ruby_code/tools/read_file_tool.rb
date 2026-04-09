# frozen_string_literal: true

require_relative "base_tool"

module RubyCode
  module Tools
    # Read the contents of a file at the given path relative to the project root
    class ReadFileTool < BaseTool
      description "Read the contents of a file at the given path relative to the project root. " \
                  "Use offset and max_lines to read specific sections of large files."
      risk :safe

      DEFAULT_MAX_LINES = 200

      params do
        string :path, description: "Relative file path from the project root"
        integer :offset, description: "Line number to start reading from (1-based, default: 1)", required: false
        integer :max_lines, description: "Maximum number of lines to return (default: #{DEFAULT_MAX_LINES})",
                            required: false
      end

      def execute(path:, offset: nil, max_lines: nil)
        full_path = validate_path!(path)
        return full_path if full_path.is_a?(Hash)
        return { error: "File not found: #{path}" } unless File.exist?(full_path)
        return { error: "Not a file: #{path}" } unless File.file?(full_path)

        lines = File.readlines(full_path)
        return { error: "File is empty" } if lines.empty?

        total = lines.length
        start_line = [(offset || 1), 1].max
        limit = max_lines || DEFAULT_MAX_LINES
        start_idx = start_line - 1
        selected = lines[start_idx, limit] || []

        result = selected.join
        remaining = total - (start_idx + selected.length)
        if remaining > 0
          result << "\n... (showing lines #{start_line}-#{start_idx + selected.length} of #{total}. " \
                    "#{remaining} lines remaining, use offset to read more)"
        end
        result
      end
    end
  end
end
