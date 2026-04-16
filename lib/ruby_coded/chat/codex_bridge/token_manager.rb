# frozen_string_literal: true

module RubyCoded
  module Chat
    class CodexBridge
      # Manages OAuth token refresh for the Codex bridge.
      # Checks token expiration before each request and refreshes
      # via the existing OAuthStrategy/AuthManager infrastructure.
      module TokenManager
        TOKEN_REFRESH_BUFFER = 60

        private

        def current_credentials
          @credentials_store.retrieve(:openai)
        end

        def ensure_token_fresh!
          credentials = current_credentials
          return unless credentials && credentials["auth_method"] == "oauth"
          return unless token_expired?(credentials)

          refresh_token!(credentials)
        end

        def token_expired?(credentials)
          expires_at = credentials["expires_at"]
          return false unless expires_at

          Time.parse(expires_at) <= Time.now + TOKEN_REFRESH_BUFFER
        end

        def refresh_token!(credentials)
          provider = Auth::AuthManager::PROVIDERS[:openai]
          strategy = Strategies::OAuthStrategy.new(provider)
          refreshed = strategy.refresh(credentials)
          @credentials_store.store(:openai, refreshed)
          @auth_manager&.configure_ruby_llm!
        rescue StandardError
          nil
        end
      end
    end
  end
end
