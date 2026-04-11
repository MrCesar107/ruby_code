# frozen_string_literal: true

module RubyCode
  module Chat
    class Renderer
      # Renders a single-line status bar showing session token usage,
      # current model, and estimated cost.
      module StatusBar
        private

        def render_status_bar(frame, area)
          input_tok = @state.total_input_tokens
          output_tok = @state.total_output_tokens
          total_tok = input_tok + output_tok
          cost = @state.total_session_cost
          model_name = @state.model.to_s

          left = " ↑#{format_number(input_tok)} ↓#{format_number(output_tok)} (#{format_number(total_tok)} tokens)"
          right = "#{model_name} | #{format_cost(cost)} "
          center_pad = [area.width - left.length - right.length, 1].max
          text = "#{left}#{" " * center_pad}#{right}"

          widget = @tui.paragraph(text: text)
          frame.render_widget(widget, area)
        end

        def format_number(num)
          num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
        end

        def format_cost(cost)
          return "Cost: N/A" if cost.nil?

          if cost < 0.01
            "Cost: $#{format("%.6f", cost)}"
          elsif cost < 1.0
            "Cost: $#{format("%.4f", cost)}"
          else
            "Cost: $#{format("%.2f", cost)}"
          end
        end
      end
    end
  end
end
