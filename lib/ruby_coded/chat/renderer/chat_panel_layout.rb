# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Sticky-header computation and section layout helpers backing the
      # chat panel's scroll-aware rendering.
      module ChatPanelLayout
        private

        def sticky_header_for(area, sections)
          return nil if sections.empty?
          return nil if @state.scroll_offset <= 0

          inner_width = [area.width - 2, 0].max
          inner_height = [area.height - 2, 0].max
          return nil if inner_width <= 0 || inner_height <= 0

          layout = build_section_layout(sections, inner_width)
          active = active_sticky_section(layout, inner_height)
          return nil unless active

          { header_text: active[:user_text], header_rich_lines: active[:user_rich_lines] }
        end

        def build_section_layout(sections, inner_width)
          cursor = 0

          sections.map do |section|
            entry_layouts = section[:entries].map do |entry|
              layout = layout_entry(entry, inner_width, cursor)
              cursor = layout[:end_line] + 1
              layout
            end
            section_layout(section, entry_layouts)
          end
        end

        def layout_entry(entry, inner_width, start_line)
          wrapped_lines = count_wrapped_lines(entry[:text], inner_width)
          entry.merge(
            wrapped_lines: wrapped_lines,
            start_line: start_line,
            end_line: start_line + wrapped_lines - 1
          )
        end

        def section_layout(section, entry_layouts)
          user_entry = entry_layouts.find { |entry| entry[:role] == :user }
          {
            user_text: section[:user_text],
            user_rich_lines: section[:user_rich_lines],
            entries: entry_layouts,
            start_line: entry_layouts.first[:start_line],
            end_line: entry_layouts.last[:end_line],
            user_end_line: user_entry ? user_entry[:end_line] : nil
          }
        end

        def active_sticky_section(layout, visible_height)
          return nil if layout.empty?

          total_lines = layout.last[:end_line] + 1
          top_visible_line = compute_scroll_y(total_lines, visible_height)

          layout.find do |section|
            next false unless section[:user_text]
            next false unless line_in_section?(top_visible_line, section)
            next false if section[:user_end_line] && top_visible_line <= section[:user_end_line]

            true
          end
        end

        def line_in_section?(line_index, section)
          line_index.between?(section[:start_line], section[:end_line])
        end
      end
    end
  end
end
