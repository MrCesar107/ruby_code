# frozen_string_literal: true

require_relative "base_tool"

module RubyCoded
  module Tools
    # Create a new file or overwrite an existing file with the given content
    class WriteFileTool < BaseTool
      description "Create a new file or overwrite an existing file with the given content"
      risk :confirm

      params do
        string :path, description: "Relative file path from the project root"
        string :content, description: "The full content to write into the file"
      end

      def execute(path:, content:)
        run_pipeline(path: path) do |full_path|
          dir = File.dirname(full_path)
          FileUtils.mkdir_p(dir) unless File.directory?(dir)

          File.write(full_path, content)
          "File written: #{path} (#{content.bytesize} bytes)"
        end
      end
    end
  end
end
