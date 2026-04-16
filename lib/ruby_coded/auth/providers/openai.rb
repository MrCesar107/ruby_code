# frozen_string_literal: true

module RubyCoded
  module Auth
    module Providers
      # OpenAI provider's configuration.
      # OAuth authenticates via ChatGPT Plus/Pro subscription (Codex backend).
      # API key authenticates via OpenAI Platform API credits.
      module OpenAI
        def self.display_name
          "OpenAI"
        end

        def self.client_id
          "app_EMoamEEZ73f0CkXaXp7hrann"
        end

        def self.auth_methods
          [
            { key: :oauth,
              label: "With your ChatGPT Plus/Pro subscription (no API credits needed)" },
            { key: :api_key,
              label: "With an OpenAI API key (requires API credits at platform.openai.com)" }
          ]
        end

        def self.auth_url
          "https://auth.openai.com/oauth/authorize"
        end

        def self.token_url
          "https://auth.openai.com/oauth/token"
        end

        def self.console_url
          "https://platform.openai.com/account/api-keys"
        end

        def self.key_pattern
          /\Ask-/
        end

        def self.redirect_uri
          "http://localhost:1455/auth/callback"
        end

        def self.scopes
          "openid profile email offline_access"
        end

        def self.ruby_llm_key
          :openai_api_key
        end

        def self.codex_auth_params
          {
            id_token_add_organizations: "true",
            codex_cli_simplified_flow: "true",
            originator: "codex_cli_rs"
          }
        end

        def self.codex_base_url
          "https://chatgpt.com/backend-api"
        end
      end
    end
  end
end
