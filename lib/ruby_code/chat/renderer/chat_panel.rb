# frozen_string_literal: true

require_relative "../../initializer/cover"

module RubyCode
  module Chat
    class Renderer
      # This module contains the logic for rendering the UI chat panel component
      module ChatPanel
        private

        def render_chat_panel(frame, area)
          widget = @tui.paragraph(
            text: chat_panel_text,
            block: @tui.block(
              title: @state.model.to_s,
              borders: [:all]
            )
          )
          frame.render_widget(widget, area)
        end

        def chat_panel_text
          messages = @state.messages_snapshot
          if messages.empty?
            cover_banner
          else
            messages.map { |m| "#{m[:role]}: #{m[:content]}" }.join("\n")
          end
        end

        def render_input_panel(frame, area)
          text = "ruby_code> #{@state.input_buffer}"
          widget = @tui.paragraph(
            text: text,
            block: @tui.block(borders: [:all])
          )
          frame.render_widget(widget, area)
        end

        def cover_banner
          Initializer::Cover::BANNER.sub("%<version>s", RubyCode::VERSION)
        end
      end
    end
  end
end
