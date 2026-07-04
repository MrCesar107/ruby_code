# frozen_string_literal: true

module RubyCoded
  module Tools
    # Standardizes the internal execution flow shared by side-effecting tools:
    #   1. validate input (project-relative path if given)
    #   2. resolve to an absolute path inside the project root
    #   3. optionally forbid operating on the project root itself
    #   4. execute the tool's business logic (via block)
    #   5. normalize filesystem errors into a structured response
    #
    # Policy, risk assessment and user approval intentionally live outside
    # this pipeline: they are handled by Tools::ExecutionPolicy and by the
    # bridges (BridgeCommon::ToolFlow), which sit above tool execution.
    class ExecutionPipeline
      def initialize(project_root:)
        @project_root = File.realpath(project_root)
      end

      # Runs the pipeline. Yields the resolved full_path (or nil if `path`
      # was not provided) to the caller-supplied block, which returns the
      # tool result — either a success value (string/hash without :error)
      # or an error hash of the form { error: "..." }.
      #
      # Any SystemCallError raised inside the block is normalized to an
      # error hash.
      def call(path: nil, forbid_root: false)
        full_path = nil
        if path
          full_path = resolve_and_validate(path)
          return full_path if full_path.is_a?(Hash)
          return { error: "Cannot operate on the project root" } if forbid_root && full_path == @project_root
        end

        yield(full_path)
      rescue SystemCallError => e
        { error: "Filesystem error: #{e.message}" }
      end

      private

      def resolve_and_validate(relative_path)
        expanded = File.expand_path(relative_path, @project_root)
        full_path = begin
          File.realpath(expanded)
        rescue Errno::ENOENT
          expanded
        end

        return full_path if inside_project?(full_path)

        { error: "Path is outside the project directory. Only paths within #{@project_root} are allowed." }
      end

      def inside_project?(full_path)
        full_path.start_with?(@project_root)
      end
    end
  end
end
