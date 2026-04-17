# frozen_string_literal: true

require "ruby_llm"
require "tty-prompt"

require_relative "initializer/cover"
require_relative "config/user_config"
require_relative "auth/auth_manager"
require_relative "chat/app"

module RubyCoded
  # Initializer class for the RubyCoded gem (think of it as a main class)
  class Initializer
    PROVIDER_DEFAULT_MODELS = {
      openai: "gpt-5.4",
      anthropic: "claude-sonnet-4-6"
    }.freeze

    def initialize
      @user_cfg = UserConfig.new
      @prompt = TTY::Prompt.new
      @auth_manager = Auth::AuthManager.new
      @fallback_from_model = nil

      ask_for_directory_permission unless @user_cfg.directory_trusted?
      @auth_manager.check_authentication
      @auth_manager.configure_ruby_llm!
      start_chat
    end

    private

    def ask_for_directory_permission
      if @prompt.yes?("Do you trust this directory? (#{Dir.pwd})")
        @user_cfg.trust_directory!
      else
        exit 0
      end
    end

    def start_chat
      model = resolved_chat_model
      Chat::App.new(
        model: model,
        user_config: @user_cfg,
        auth_manager: @auth_manager,
        fallback_from_model: @fallback_from_model
      ).run
    end

    def resolved_chat_model
      stored = @user_cfg.get_config("model")
      if stored && !stored.to_s.strip.empty?
        return stored.to_s if @auth_manager.model_provider_authenticated?(stored.to_s)

        @fallback_from_model = stored.to_s
      end

      provider = @auth_manager.authenticated_provider_names.first
      PROVIDER_DEFAULT_MODELS.fetch(provider, RubyLLM.config.default_model).to_s
    end
  end
end
