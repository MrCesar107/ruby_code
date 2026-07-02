# frozen_string_literal: true

require_relative "rich_text_inline"

module RubyCoded
  module Chat
    class Renderer
      # Helpers for building and serializing rich text using ratatui text lines/spans.
      module RichText
        include RichTextInline

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
          state = { lines: [], in_code_block: false }
          text.split("\n", -1).each { |raw_line| parse_rich_line(raw_line, state, role) }
          state[:lines]
        end

        def parse_rich_line(raw_line, state, role)
          return toggle_code_fence(raw_line, state) if raw_line.start_with?("```")

          state[:lines] << rich_line_for(raw_line, state[:in_code_block], role)
        end

        def toggle_code_fence(raw_line, state)
          if state[:in_code_block]
            state[:in_code_block] = false
            return
          end

          state[:in_code_block] = true
          language = raw_line.delete_prefix("```").strip
          state[:lines] << code_language_line(language) unless language.empty?
        end

        def rich_line_for(raw_line, in_code_block, role)
          return @tui.line(spans: inline_spans(raw_line, role: role)) unless in_code_block

          @tui.line(spans: [@tui.span(content: raw_line, style: code_block_style)])
        end

        def code_language_line(language)
          @tui.line(spans: [@tui.span(content: "[#{language}]", style: @tui.style(fg: :yellow, modifiers: [:bold]))])
        end

        def merge_style(style, foreground: nil, background: nil, modifiers: [])
          @tui.style(
            fg: foreground || style&.fg,
            bg: background || style&.bg,
            modifiers: ((style&.modifiers || []) + modifiers).uniq
          )
        end

        BASE_TEXT_STYLES = {
          system: { fg: :dark_gray, modifiers: [:italic] },
          user_label: { fg: :cyan, modifiers: [:bold] },
          tool_call: { fg: :yellow, modifiers: [:bold] },
          tool_pending: { fg: :magenta, modifiers: [:bold] },
          tool_result: { fg: :green },
          thinking_title: { fg: :blue, modifiers: [:bold] }
        }.freeze

        def base_text_style(role)
          @tui.style(**BASE_TEXT_STYLES.fetch(role, { modifiers: [] }))
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
