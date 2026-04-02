# frozen_string_literal: true

require_relative "renderer/chat_panel"
require_relative "renderer/model_selector"

module RubyCode
  module Chat
    # This class manages the rendering of the UI elements
    class Renderer
      include ChatPanel
      include ModelSelector

      def initialize(tui, state)
        @tui = tui
        @state = state
      end

      def draw
        @tui.clear

        @tui.draw do |frame|
          chat_area, input_area = main_layout(frame)
          render_chat_panel(frame, chat_area)
          render_input_panel(frame, input_area)
          render_model_selector(frame, chat_area) if @state.model_select?
        end
      end

      private

      def main_layout(frame)
        @tui.layout_split(
          frame.area,
          direction: :vertical,
          constraints: [
            @tui.constraint_fill(1),
            @tui.constraint_length(3)
          ]
        )
      end
    end
  end
end
