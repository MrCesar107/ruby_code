# frozen_string_literal: true

require "ruby_llm"

require_relative "command_handler/model_commands"
require_relative "command_handler/history_commands"

module RubyCode
  module Chat
    # Handles slash commands entered in the chat input.
    class CommandHandler
      include ModelCommands
      include HistoryCommands

      COMMANDS = {
        "/help" => :cmd_help,
        "/exit" => :cmd_exit,
        "/quit" => :cmd_exit,
        "/clear" => :cmd_clear,
        "/model" => :cmd_model,
        "/history" => :cmd_history,
        "/tokens" => :cmd_tokens
      }.freeze

      HELP_TEXT = File.read(File.join(__dir__, "help.txt")).freeze

      def initialize(state, llm_bridge:, user_config: nil, credentials_store: nil)
        @state = state
        @llm_bridge = llm_bridge
        @user_config = user_config
        @credentials_store = credentials_store
      end

      def handle(raw_input)
        stripped = raw_input.strip
        return if stripped.empty?

        command, rest = stripped.split(" ", 2)
        method_name = COMMANDS[command.downcase]

        if method_name
          send(method_name, rest)
        else
          @state.add_message(:system, "Unknown command: #{command}. Type /help for available commands.")
        end
      end

      private

      def cmd_help(_rest)
        @state.add_message(:system, HELP_TEXT)
      end

      def cmd_exit(_rest)
        @state.should_quit = true
      end

      def cmd_clear(_rest)
        @state.clear_messages!
        @state.add_message(:system, "Conversation cleared.")
      end
    end
  end
end
