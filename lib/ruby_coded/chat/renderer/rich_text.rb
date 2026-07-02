# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Helpers for building and serializing rich text using ratatui text lines/spans.
      module RichText
        public

        def rich_text_lines(text, role: :assistant)
          return [] if text.nil? || text.empty?

          parse_rich_text(text, role: role)
        end

        def rich_text_plain(lines)
          Array(lines).map { |line| rich_line_plain(line) }.join("\n")
        end

        def rich_line_plain(line)
          return line.to_s unless line.respond_to?(:spans)

          Array(line.spans).map { |span| span.respond_to?(:content) ? span.content.to_s : span.to_s }.join
        end

        def parse_rich_text(text, role: :assistant)
          lines = []
          in_code_block = false
          code_block_language = nil

          text.split("\n", -1).each do |raw_line|
            if raw_line.start_with?("```")
              if in_code_block
                in_code_block = false
                code_block_language = nil
              else
                in_code_block = true
                code_block_language = raw_line.delete_prefix("```").strip
                next if code_block_language.empty?

                lines << @tui.line(
                  spans: [
                    @tui.span(content: "[#{code_block_language}]", style: @tui.style(fg: :yellow, modifiers: [:bold]))
                  ]
                )
              end
              next
            end

            if in_code_block
              lines << @tui.line(spans: [@tui.span(content: raw_line, style: code_block_style)])
            else
              lines << @tui.line(spans: inline_spans(raw_line, role: role))
            end
          end

          lines
        end

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

        def merge_style(style, fg: nil, bg: nil, modifiers: [])
          @tui.style(
            fg: fg || style&.fg,
            bg: bg || style&.bg,
            modifiers: ((style&.modifiers || []) + modifiers).uniq
          )
        end

        def base_text_style(role)
          case role
          when :system
            @tui.style(fg: :dark_gray, modifiers: [:italic])
          when :user_label
            @tui.style(fg: :cyan, modifiers: [:bold])
          when :tool_call
            @tui.style(fg: :yellow, modifiers: [:bold])
          when :tool_pending
            @tui.style(fg: :magenta, modifiers: [:bold])
          when :tool_result
            @tui.style(fg: :green)
          when :thinking_title
            @tui.style(fg: :blue, modifiers: [:bold])
          else
            @tui.style(modifiers: [])
          end
        end

        def inline_code_style
          @tui.style(fg: :yellow, bg: :dark_gray)
        end

        def code_block_style
          @tui.style(fg: :green, bg: :black)
        end
      end
    end
  end
end
