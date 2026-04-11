# frozen_string_literal: true

module RubyCode
  module Chat
    class CommandHandler
      # This module contains the logic for the commands' history management
      module HistoryCommands
        private

        def cmd_history(_rest)
          conv = conversation_messages
          if conv.empty?
            @state.add_message(:system, "No conversation history yet.")
            return
          end

          @state.add_message(:system, format_history(conv))
        end

        def conversation_messages
          @state.messages_snapshot.reject { |m| m[:role] == :system }
        end

        def format_history(conv)
          lines = conv.map.with_index(1) { |msg, i| format_history_line(msg, i) }
          "Conversation history (#{conv.size} messages):\n#{lines.join("\n")}"
        end

        def format_history_line(msg, index)
          role = msg[:role].to_s.capitalize
          preview = msg[:content].to_s.lines.first&.strip || ""
          preview = "#{preview[0..60]}..." if preview.length > 60
          "  #{index}. [#{role}] #{preview}"
        end

        def cmd_tokens(_rest)
          breakdown = @state.session_cost_breakdown

          if breakdown.empty?
            @state.add_message(:system, "No token usage recorded yet.")
            return
          end

          lines = []
          lines << "Session Token Usage & Cost Report"
          lines << "═" * 50

          breakdown.each do |entry|
            lines << format_token_entry(entry)
          end

          lines << "─" * 50
          lines << format_token_totals(breakdown)

          @state.add_message(:system, lines.join("\n"))
        end

        def format_token_entry(entry)
          lines = []
          lines << "Model: #{entry[:model]}"

          if entry[:input_price_per_million]
            lines << "  Input:   #{format_num(entry[:input_tokens])} tokens  " \
                      "(#{format_usd(entry[:input_cost])} @ $#{entry[:input_price_per_million]}/1M)"
            lines << "  Output:  #{format_num(entry[:output_tokens])} tokens  " \
                      "(#{format_usd(entry[:output_cost])} @ $#{entry[:output_price_per_million]}/1M)"
            total_tokens = entry[:input_tokens] + entry[:output_tokens]
            lines << "  Subtotal: #{format_num(total_tokens)} tokens  #{format_usd(entry[:total_cost])}"
          else
            total_tokens = entry[:input_tokens] + entry[:output_tokens]
            lines << "  Input:   #{format_num(entry[:input_tokens])} tokens"
            lines << "  Output:  #{format_num(entry[:output_tokens])} tokens"
            lines << "  Subtotal: #{format_num(total_tokens)} tokens  (pricing unavailable)"
          end

          lines.join("\n")
        end

        def format_token_totals(breakdown)
          total_input = breakdown.sum { |e| e[:input_tokens] }
          total_output = breakdown.sum { |e| e[:output_tokens] }
          total_tokens = total_input + total_output
          costs = breakdown.map { |e| e[:total_cost] }.compact
          total_cost = costs.empty? ? nil : costs.sum

          cost_str = total_cost ? format_usd(total_cost) : "N/A"
          "Total: #{format_num(total_tokens)} tokens (↑#{format_num(total_input)} ↓#{format_num(total_output)}) | Cost: #{cost_str}"
        end

        def format_num(num)
          num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1,').reverse
        end

        def format_usd(amount)
          return "N/A" if amount.nil?

          if amount < 0.01
            "$#{format("%.6f", amount)}"
          elsif amount < 1.0
            "$#{format("%.4f", amount)}"
          else
            "$#{format("%.2f", amount)}"
          end
        end
      end
    end
  end
end
