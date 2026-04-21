# frozen_string_literal: true

require_relative "core_provider"
require_relative "plugin_provider"
require_relative "markdown_provider"

module RubyCoded
  module Commands
    # Merges core, plugin, and markdown commands into a single catalog.
    # rubocop:disable Metrics/ClassLength
    class Catalog
      SOURCE_PRIORITY = {
        markdown: 1,
        plugin: 2,
        core: 3
      }.freeze

      def initialize(project_root:, plugin_registry:)
        @project_root = project_root
        @plugin_registry = plugin_registry
        @last_reload_report = nil
      end

      def all_definitions
        merged.values.sort_by { |definition| definition.name.downcase }
      end

      def command_map
        all_definitions.filter_map { |definition| command_pair(definition) }.to_h
      end

      def command_descriptions
        all_definitions.to_h { |definition| [definition.name, definition.description] }
      end

      def find(name)
        merged[name.downcase]
      end

      def definitions_for_source(source)
        all_definitions.select { |definition| definition.source == source }
      end

      def reload!
        previous_markdown_names = cached_markdown_names
        clear_cached_reports!
        current_markdown_names = markdown_names
        @last_reload_report = build_reload_report(previous_markdown_names, current_markdown_names)
      end

      def last_reload_report
        @last_reload_report || default_reload_report
      end

      private

      def command_pair(definition)
        return unless definition.handler

        [definition.name.downcase, definition.handler]
      end

      def cached_markdown_names
        return [] unless @merged

        definitions_for_source(:markdown).map { |definition| definition.name.downcase }
      end

      def markdown_names
        definitions_for_source(:markdown).map { |definition| definition.name.downcase }
      end

      def clear_cached_reports!
        @markdown_report = nil
        @merged = nil
      end

      def build_reload_report(previous_names, current_names)
        conflicts = markdown_conflicts

        base_reload_report(previous_names, current_names).merge(
          conflicts: conflicts.size,
          conflict_commands: conflicts.map { |conflict| conflict[:command] },
          conflict_files: conflicts.map { |conflict| conflict[:file] }
        )
      end

      def base_reload_report(previous_names, current_names)
        {
          total: current_names.size,
          added: (current_names - previous_names).size,
          removed: (previous_names - current_names).size,
          invalid: markdown_report[:invalid_count],
          invalid_files: markdown_report[:invalid_files]
        }
      end

      def default_reload_report
        build_reload_report([], markdown_names).merge(added: 0)
      end

      def merged
        @merged ||= begin
          result = {}
          providers.each { |provider| merge_provider!(result, provider) }
          result
        end
      end

      def merge_provider!(result, provider)
        provider.definitions.each { |definition| merge_definition!(result, definition) }
      end

      def merge_definition!(result, definition)
        key = definition.name.downcase
        existing = result[key]
        return if existing && priority(definition.source) <= priority(existing.source)

        result[key] = definition
      end

      def providers
        [
          markdown_provider,
          PluginProvider.new(registry: @plugin_registry),
          CoreProvider.new
        ]
      end

      def markdown_provider
        @markdown_provider ||= MarkdownProvider.new(project_root: @project_root)
      end

      def markdown_report
        @markdown_report ||= markdown_provider.load_report
      end

      def markdown_conflicts
        markdown_report[:definitions].filter_map { |definition| build_conflict(definition) }
      end

      def build_conflict(definition)
        return unless reserved_command_names.include?(definition.name.downcase)

        {
          command: definition.name,
          file: definition.path ? File.basename(definition.path) : definition.name
        }
      end

      def reserved_command_names
        @reserved_command_names ||= (core_command_names + plugin_command_names).uniq
      end

      def core_command_names
        CoreProvider.new.definitions.map { |definition| definition.name.downcase }
      end

      def plugin_command_names
        provider = PluginProvider.new(registry: @plugin_registry)
        provider.definitions.map { |definition| definition.name.downcase }
      end

      def priority(source)
        SOURCE_PRIORITY.fetch(source, 0)
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
