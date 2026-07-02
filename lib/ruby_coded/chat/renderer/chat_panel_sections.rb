# frozen_string_literal: true

require "unicode/display_width"

module RubyCoded
  module Chat
    class Renderer
      # Section building, sticky-header computation, and line-measurement
      # helpers backing the chat panel's scroll-aware rendering.
      module ChatPanelSections
        private

        def build_chat_sections(messages)
          sections = []
          visible_index = 0

          messages.each do |msg|
            rich_lines = format_message_rich(msg)
            next if rich_lines.nil?

            append_section_entry(sections, msg, rich_lines, visible_index)
            visible_index += 1
          end

          sections
        end

        def append_section_entry(sections, msg, rich_lines, visible_index)
          plain_text = rich_text_plain(rich_lines)
          section = next_section_for(sections, msg, plain_text, rich_lines)
          section[:entries] << {
            role: msg[:role],
            text: plain_text,
            rich_lines: rich_lines,
            visible_index: visible_index
          }
        end

        def next_section_for(sections, msg, text, rich_lines)
          return sections.last if sections.any? && msg[:role] != :user

          sections << {
            user_text: msg[:role] == :user ? text : nil,
            user_rich_lines: msg[:role] == :user ? rich_lines : nil,
            entries: []
          }
          sections.last
        end

        def sections_to_text(sections)
          sections.flat_map { |section| section[:entries].map { |entry| entry[:text] } }.join("\n")
        end

        def sections_to_rich_lines(sections)
          sections.flat_map.with_index do |section, section_index|
            lines = section[:entries].flat_map { |entry| Array(entry[:rich_lines]) }
            section_index == sections.length - 1 ? lines : lines + [@tui.line(spans: [@tui.span(content: "")])]
          end
        end

        def count_wrapped_lines(text_or_lines, width)
          return 1 if width <= 0

          if text_or_lines.is_a?(Array)
            count_wrapped_rich_lines(text_or_lines, width)
          else
            count_wrapped_text_lines(text_or_lines.to_s, width)
          end
        end

        def count_wrapped_rich_lines(lines, width)
          return 1 if lines.empty?

          lines.sum { |line| wrapped_line_count(rich_line_plain(line), width) }
        end

        def count_wrapped_text_lines(text, width)
          return 1 if text.empty?

          text.split("\n", -1).sum { |line| wrapped_line_count(line, width) }
        end

        def wrapped_line_count(line, width)
          line.empty? ? 1 : (display_width(line).to_f / width).ceil
        end

        def display_width(line)
          Unicode::DisplayWidth.of(line)
        end
      end
    end
  end
end
