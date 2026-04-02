# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # This module contains the logic for the chats messages management
      module Messages
        def add_message(role, content)
          @mutex.synchronize do
            @messages << {
              role: role,
              content: String.new(content.to_s),
              timestamp: Time.now,
              input_tokens: 0,
              output_tokens: 0
            }
          end

          scroll_to_bottom
        end

        def append_to_last_message(text)
          @mutex.synchronize do
            return if @messages.empty?

            @messages.last[:content] << text.to_s
          end
        end

        def last_assistant_empty?
          @mutex.synchronize do
            return true if @messages.empty?

            last = @messages.last
            last[:role] == :assistant && last[:content].strip.empty?
          end
        end

        def reset_last_assistant_content
          @mutex.synchronize do
            return if @messages.empty?

            last = @messages.last
            return unless last[:role] == :assistant

            last[:content] = String.new
          end
        end

        def fail_last_assistant(error, friendly_message: nil)
          @mutex.synchronize do
            return if @messages.empty?

            last = @messages.last
            return unless last[:role] == :assistant

            apply_error_to_message(last, friendly_message || "[Error] #{error.class}: #{error.message}")
          end
        end

        def apply_error_to_message(message, err_line)
          if message[:content].strip.empty?
            message[:content] = String.new(err_line)
          else
            message[:content] << "\n\n#{err_line}"
          end
        end

        def update_last_message_tokens(input_tokens:, output_tokens:)
          @mutex.synchronize do
            return if @messages.empty?

            @messages.last[:input_tokens] = input_tokens
            @messages.last[:output_tokens] = output_tokens
          end
        end

        def clear_messages!
          @mutex.synchronize { @messages.clear }
          @scroll_offset = 0
        end

        def total_input_tokens
          @mutex.synchronize do
            @messages.sum { |message| message[:input_tokens] }
          end
        end

        def total_output_tokens
          @mutex.synchronize do
            @messages.sum { |message| message[:output_tokens] }
          end
        end

        def messages_snapshot
          @mutex.synchronize { @messages.map(&:dup) }
        end
      end
    end
  end
end
