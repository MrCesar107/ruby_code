# frozen_string_literal: true

require "fileutils"
require_relative "base_tool"

module RubyCoded
  module Tools
    # Delete a file or an empty directory at the given path
    class DeletePathTool < BaseTool
      description "Delete a file or an empty directory at the given path"
      risk :dangerous

      params do
        string :path, description: "Relative path from the project root to delete"
      end

      def execute(path:)
        run_pipeline(path: path, forbid_root: true) do |full_path|
          next { error: "Path not found: #{path}" } unless File.exist?(full_path)

          perform_delete(path, full_path)
        end
      end

      private

      def perform_delete(path, full_path)
        if File.directory?(full_path)
          delete_directory(path, full_path)
        else
          File.delete(full_path)
          "Deleted file: #{path}"
        end
      end

      def delete_directory(path, full_path)
        entries = Dir.children(full_path)
        unless entries.empty?
          return { error: "Directory not empty: #{path} (#{entries.length} entries). Remove contents first." }
        end

        Dir.rmdir(full_path)
        "Deleted empty directory: #{path}"
      end
    end
  end
end
