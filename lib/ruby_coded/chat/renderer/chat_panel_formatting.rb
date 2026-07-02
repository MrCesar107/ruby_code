# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Message-to-text formatting helpers used by the chat panel.
      module ChatPanelFormatting
        USER_LABEL = "YOU"

        private

        def format_messages_text(messages)
          messages.filter_map { |m| format_message_plain(m) }.join("\n")
        end

        def format_message_plain(msg)
          plain = format_message_rich(msg)
          return nil unless plain

          rich_text_plain(plain)
        end

        def format_message(msg)
          format_message_plain(msg)
        end

        def format_message_rich(msg)
          case msg[:role]
          when :tool_call, :tool_pending, :tool_result then nil
          when :system    then format_system_message_rich(msg[:content])
          when :user      then format_user_message_rich(msg[:content])
          when :assistant then format_assistant_message_rich(msg[:content])
          else                 rich_text_lines("#{msg[:role]}: #{msg[:content]}", role: :assistant)
          end
        end

        def format_system_message_rich(content)
          rich_text_lines("--- #{content}", role: :system)
        end

        def format_user_message(content)
          rich_text_plain(format_user_message_rich(content))
        end

        def format_user_message_rich(content)
          body_lines = rich_text_lines(content, role: :user)
          return [user_label_line] if body_lines.empty?

          [user_label_line(body_lines.first), *(body_lines[1..] || [])]
        end

        def user_label_line(first_line = nil)
          label_span = @tui.span(content: "[#{USER_LABEL}]#{" " if first_line}", style: base_text_style(:user_label))
          spans = first_line ? [label_span, *Array(first_line.spans)] : [label_span]
          @tui.line(spans: spans)
        end

        def format_assistant_message(content)
          result = strip_think_tags(content)
          result.empty? ? nil : result
        end

        def format_assistant_message_rich(content)
          result = strip_think_tags(content)
          return nil if result.empty?

          rich_text_lines(result, role: :assistant)
        end
      end
    end
  end
end
