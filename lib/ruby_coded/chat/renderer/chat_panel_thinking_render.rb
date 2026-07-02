# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Layout and widget rendering for the split chat/thinking panel view.
      module ChatPanelThinkingRender
        private

        def render_chat_with_thinking(frame, area, messages)
          full_cycle = current_cycle_messages(messages)
          cycle = tail_of_cycle(full_cycle)
          prior = messages[0...(messages.length - full_cycle.length)]
          chat_area, thinking_area = split_chat_thinking(area)

          render_messages_in_area(frame, chat_area, prior)
          render_thinking_panel(frame, thinking_area, format_thinking_lines(cycle))
        end

        def split_chat_thinking(area)
          @tui.layout_split(
            area,
            direction: :vertical,
            constraints: [@tui.constraint_fill(3), @tui.constraint_fill(2)]
          )
        end

        def render_thinking_panel(frame, area, thinking_lines)
          scroll_y = thinking_scroll_y(area, thinking_lines)

          widget = @tui.paragraph(
            text: thinking_lines,
            wrap: true,
            scroll: [scroll_y, 0],
            block: @tui.block(title: "thinking...", borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def thinking_scroll_y(area, text_or_lines)
          inner_height = [area.height - 2, 0].max
          inner_width = [area.width - 2, 0].max
          total_lines = count_wrapped_lines(text_or_lines, inner_width)
          [total_lines - inner_height, 0].max
        end
      end
    end
  end
end
