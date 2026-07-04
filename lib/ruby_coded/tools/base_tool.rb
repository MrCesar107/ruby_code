# frozen_string_literal: true

require "ruby_llm"
require_relative "tool_rejected_error"
require_relative "execution_pipeline"

module RubyCoded
  module Tools
    # Base class for all tools.
    class BaseTool < RubyLLM::Tool
      SAFE_RISK = :safe
      CONFIRM_RISK = :confirm
      DANGEROUS_RISK = :dangerous

      class << self
        attr_reader :risk_level

        private

        def risk(level)
          @risk_level = level
        end
      end

      def initialize(project_root:)
        super()
        @project_root = File.realpath(project_root)
      end

      private

      # Runs the shared execution pipeline (path validation, project-root
      # guard, filesystem error normalization) around the given block.
      # Prefer this over calling validate_path! directly for tools that
      # need the full pipeline; use validate_path! when only path
      # resolution is required (e.g. read-only tools with custom flows).
      def run_pipeline(path: nil, forbid_root: false, &)
        pipeline.call(path: path, forbid_root: forbid_root, &)
      end

      def pipeline
        @pipeline ||= ExecutionPipeline.new(project_root: @project_root)
      end

      def resolve_path(relative_path)
        expanded = File.expand_path(relative_path, @project_root)
        File.realpath(expanded)
      rescue Errno::ENOENT
        expanded
      end

      def inside_project?(full_path)
        full_path.start_with?(@project_root)
      end

      def validate_path!(relative_path)
        full = resolve_path(relative_path)
        return full if inside_project?(full)

        { error: "Path is outside the project directory. Only paths within #{@project_root} are allowed." }
      end
    end
  end
end
