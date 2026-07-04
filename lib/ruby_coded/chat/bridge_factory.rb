# frozen_string_literal: true

require_relative "llm_bridge"
require_relative "codex_bridge"
require_relative "codex_models"

module RubyCoded
  module Chat
    # Decides which bridge (LLMBridge vs CodexBridge) to instantiate
    # based on the stored OpenAI credentials.
    #
    # Extracted from Chat::App so that backend selection remains a
    # single, testable responsibility and App stays focused on
    # orchestration.
    class BridgeFactory
      def initialize(state:, credentials_store:, auth_manager:, skill_catalog:, user_config: nil)
        @state = state
        @credentials_store = credentials_store
        @auth_manager = auth_manager
        @skill_catalog = skill_catalog
        @user_config = user_config
      end

      def build
        return build_llm_bridge unless codex_backend?

        build_codex_bridge
      end

      private

      def codex_backend?
        credentials = @credentials_store.retrieve(:openai)
        credentials && credentials["auth_method"] == "oauth"
      end

      def build_codex_bridge
        @state.codex_mode = true
        ensure_valid_codex_model!
        CodexBridge.new(
          @state,
          credentials_store: @credentials_store,
          auth_manager: @auth_manager,
          skill_catalog: @skill_catalog
        )
      end

      def build_llm_bridge
        @state.codex_mode = false
        LLMBridge.new(@state, skill_catalog: @skill_catalog)
      end

      def ensure_valid_codex_model!
        return if CodexModels.codex_model?(@state.model)

        @state.model = CodexBridge::DEFAULT_MODEL
        @user_config&.set_config("model", CodexBridge::DEFAULT_MODEL)
      end
    end
  end
end
