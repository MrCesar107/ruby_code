# frozen_string_literal: true

require "ratatui_ruby"

require_relative "state"
require_relative "input_handler"
require_relative "renderer"
require_relative "command_handler"
require_relative "llm_bridge"
require_relative "../auth/credentials_store"

module RubyCode
  module Chat
    # Main class for the AI chat
    class App
      def initialize(model:, user_config: nil)
        @model = model
        @user_config = user_config
        @state = State.new(model: model)
        @llm_bridge = LLMBridge.new(@state)
        @input_handler = InputHandler.new(@state)
        @credentials_store = Auth::CredentialsStore.new
        @command_handler = CommandHandler.new(
          @state,
          llm_bridge: @llm_bridge,
          user_config: @user_config,
          credentials_store: @credentials_store
        )
      end

      def run
        RatatuiRuby.run do |tui|
          @tui = tui
          @renderer = Renderer.new(tui, @state)

          loop do
            @renderer.draw
            break if handle_event == :quit
          end
        end
      end

      private

      def apply_selected_model
        selected = @state.selected_model
        return @state.exit_model_select! unless selected

        model_name = selected.respond_to?(:id) ? selected.id : selected.to_s
        @state.model = model_name
        @llm_bridge.reset_chat!(model_name)
        @user_config&.set_config("model", model_name)
        @state.exit_model_select!
        @state.add_message(:system, "Model switched to #{model_name}.")
      rescue StandardError => e
        @state.exit_model_select!
        @state.add_message(:system, "Failed to switch model: #{e.message}")
      end

      def handle_event
        event = @tui.poll_event
        action = @input_handler.process(event)
        case action
        when :quit
          :quit
        when :submit
          input = @state.consume_input!
          if input.start_with?("/")
            @command_handler.handle(input)
            :quit if @state.should_quit?
          else
            @state.add_message(:user, input)
            @llm_bridge.send_async(input)
          end
        when :model_selected
          apply_selected_model
        when :model_select_cancel
          @state.exit_model_select!
        when :cancel_streaming
          @llm_bridge.cancel!
        when :scroll_up
          @state.scroll_up
        when :scroll_down
          @state.scroll_down
        when :scroll_top
          @state.scroll_to_top
        when :scroll_bottom
          @state.scroll_to_bottom
        end
      end
    end
  end
end
