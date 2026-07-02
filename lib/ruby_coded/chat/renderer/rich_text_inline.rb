# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Inline markdown parsing (code, bold, italic) into ratatui spans.
      module RichTextInline
        def inline_spans(text, role: :assistant)
          spans = []
          remaining = text.dup

          while !remaining.empty?
            marker, index = next_inline_marker(remaining)
            unless marker
              spans << @tui.span(content: remaining, style: base_text_style(role))
              break
            end

            prefix = remaining[0...index]
            spans << @tui.span(content: prefix, style: base_text_style(role)) unless prefix.empty?

            consumed = append_styled_span!(spans, remaining[index..], role: role)
            if consumed
              remaining = remaining[(index + consumed)..]
            else
              spans << @tui.span(content: remaining[index], style: base_text_style(role))
              remaining = remaining[(index + 1)..]
            end
          end

          spans = [@tui.span(content: "", style: base_text_style(role))] if spans.empty?
          spans
        end

        def next_inline_marker(text)
          markers = ["`", "**", "*"]
          positions = markers.filter_map do |marker|
            index = text.index(marker)
            [marker, index] if index
          end
          positions.min_by { |(_, index)| index }
        end

        def append_styled_span!(spans, text, role: :assistant)
          return append_code_span!(spans, text) if text.start_with?("`")
          return append_bold_span!(spans, text, role: role) if text.start_with?("**")
          return append_italic_span!(spans, text, role: role) if text.start_with?("*")

          nil
        end

        def append_code_span!(spans, text)
          close = text.index("`", 1)
          return nil unless close

          content = text[1...close]
          spans << @tui.span(content: content, style: inline_code_style)
          close + 1
        end

        def append_bold_span!(spans, text, role: :assistant)
          close = text.index("**", 2)
          return nil unless close

          content = text[2...close]
          spans << @tui.span(content: content, style: merge_style(base_text_style(role), modifiers: [:bold]))
          close + 2
        end

        def append_italic_span!(spans, text, role: :assistant)
          close = text.index("*", 1)
          return nil unless close

          content = text[1...close]
          spans << @tui.span(content: content, style: merge_style(base_text_style(role), modifiers: [:italic]))
          close + 1
        end
      end
    end
  end
end
