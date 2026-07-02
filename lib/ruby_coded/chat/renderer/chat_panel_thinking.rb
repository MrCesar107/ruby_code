# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Thinking-panel detection, parsing, and rendering for agent
      # response cycles that include tool activity or open <think> blocks.
      module ChatPanelThinking
        THINK_OPEN = "<think>"
        THINK_CLOSE = "</think>"
        TOOL_ROLES = %i[tool_call tool_pending tool_result].freeze
        MAX_THINKING_MESSAGES = 20

        private

        def thinking_in_progress?(messages)
          cycle = current_cycle_messages(messages)
          return false if cycle.empty?

          cycle.any? { |m| TOOL_ROLES.include?(m[:role]) } ||
            cycle.any? { |m| m[:role] == :assistant && open_think_block?(m[:content]) }
        end

        def current_cycle_messages(messages)
          last_user_idx = messages.rindex { |m| m[:role] == :user }
          return messages unless last_user_idx

          messages[(last_user_idx + 1)..]
        end

        def tail_of_cycle(cycle)
          return cycle if cycle.length <= MAX_THINKING_MESSAGES

          truncated = cycle.last(MAX_THINKING_MESSAGES)
          omitted = cycle.length - MAX_THINKING_MESSAGES
          header = { role: :system, content: "... #{omitted} earlier messages omitted ...", timestamp: Time.now,
                     **RubyCoded::Chat::State::Messages::ZERO_TOKEN_USAGE }
          [header] + truncated
        end

        def open_think_block?(content)
          content.include?(THINK_OPEN) && !content.include?(THINK_CLOSE)
        end

        def parse_thinking_content(content)
          think_start = content.index(THINK_OPEN)
          return [nil, content, true] unless think_start

          think_end = content.index(THINK_CLOSE)
          if think_end
            parse_closed_think_block(content, think_start, think_end)
          else
            thinking = content[(think_start + THINK_OPEN.length)..]
            [thinking, content[0...think_start].strip, false]
          end
        end

        def parse_closed_think_block(content, think_start, think_end)
          thinking = content[(think_start + THINK_OPEN.length)...think_end]
          before = content[0...think_start]
          after = content[(think_end + THINK_CLOSE.length)..]
          [thinking, (before + after).strip, true]
        end

        def strip_think_tags(content)
          _, result, = parse_thinking_content(content)
          result
        end

        def format_thinking_text(cycle_messages)
          rich_text_plain(format_thinking_lines(cycle_messages))
        end

        def format_thinking_lines(cycle_messages)
          cycle_messages.flat_map.with_index do |msg, index|
            lines = format_thinking_message_rich(msg)
            index == cycle_messages.length - 1 ? lines : lines + [@tui.line(spans: [@tui.span(content: "")])]
          end
        end

        def format_thinking_message(msg)
          case msg[:role]
          when :assistant    then msg[:content].gsub(%r{</?think>}, "")
          when :tool_call    then ">> #{msg[:content]}"
          when :tool_pending then "?? #{msg[:content]}"
          when :tool_result  then "   #{msg[:content]}"
          when :system       then "--- #{msg[:content]}"
          else                    msg[:content]
          end
        end

        def format_thinking_message_rich(msg)
          text, role = thinking_rich_text_and_role(msg)
          rich_text_lines(text, role: role)
        end

        def thinking_rich_text_and_role(msg)
          case msg[:role]
          when :assistant    then [msg[:content].gsub(%r{</?think>}, ""), :assistant]
          when :tool_call    then [">> #{msg[:content]}", :tool_call]
          when :tool_pending then ["?? #{msg[:content]}", :tool_pending]
          when :tool_result  then ["   #{msg[:content]}", :tool_result]
          when :system       then ["--- #{msg[:content]}", :system]
          else                    [msg[:content].to_s, :assistant]
          end
        end
      end
    end
  end
end
