# frozen_string_literal: true

require "yaml"

module RubyCoded
  module Commands
    # Loads project-local markdown command files.
    class MarkdownLoader
      def initialize(project_root:)
        @project_root = project_root
      end

      def load_files
        load_report[:entries]
      end

      def load_report
        return empty_report unless Dir.exist?(commands_dir)

        build_report(command_paths)
      end

      private

      def empty_report
        { entries: [], invalid_count: 0, invalid_files: [] }
      end

      def build_report(paths)
        entries, invalid_files = paths.each_with_object([[], []]) do |path, memo|
          collect_report_entry(path, *memo)
        end

        {
          entries: entries,
          invalid_count: invalid_files.size,
          invalid_files: invalid_files
        }
      end

      def collect_report_entry(path, entries, invalid_files)
        parsed = parse_file(path)
        parsed ? entries << parsed : invalid_files << File.basename(path)
      end

      def command_paths
        Dir.glob(File.join(commands_dir, "*.md"))
      end

      def commands_dir
        File.join(@project_root, ".ruby_coded", "commands")
      end

      def parse_file(path)
        frontmatter, body = extract_frontmatter(File.read(path))
        return nil unless frontmatter

        build_entry(path, extract_attributes(frontmatter, body))
      rescue StandardError
        nil
      end

      def extract_attributes(frontmatter, body)
        data = YAML.safe_load(frontmatter) || {}
        {
          command: data["command"]&.strip,
          description: data["description"]&.strip,
          usage: data["usage"]&.strip,
          content: body.to_s.strip
        }
      end

      def build_entry(path, attrs)
        return nil unless valid_entry?(attrs)

        attrs.merge(path: path)
      end

      def valid_entry?(attrs)
        valid_command_name?(attrs[:command]) &&
          !attrs[:description].to_s.empty? &&
          !attrs[:content].to_s.empty?
      end

      def extract_frontmatter(raw)
        match = raw.match(/\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m)
        return [nil, nil] unless match

        [match[1], match[2]]
      end

      def valid_command_name?(name)
        return false if name.to_s.empty?
        return false unless name.start_with?("/")
        return false if name.include?(" ")

        true
      end
    end
  end
end
