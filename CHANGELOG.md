## [Unreleased]

## [0.2.0] - 2026-04-16

### Added

- **ChatGPT Plus/Pro OAuth authentication**: Use your ChatGPT subscription to access GPT-5.x models via the Codex backend — no API credits required
- **`/login` command**: Authenticate with providers (OpenAI, Anthropic) directly from the TUI without restarting
- **In-TUI login wizard**: Native multi-step login flow with OAuth and API key support, replacing the old TUI-suspend approach
- **CodexBridge**: Dedicated HTTP client for the ChatGPT Codex Responses API with SSE streaming, stateless conversation history, tool calls, and automatic token refresh
- **Codex model catalog**: Local catalog of ChatGPT-available models (gpt-5.4, gpt-5.2, gpt-5.2-codex, etc.) integrated with the `/model` selector
- **Status bar indicator**: Shows `(ChatGPT)` or `(API)` next to the model name to distinguish authentication mode
- **JWT decoder**: Extracts `chatgpt_account_id` from OAuth tokens for Codex API authentication

### Changed

- OpenAI OAuth now authenticates via ChatGPT Codex backend instead of the OpenAI Platform API
- OAuth scopes expanded to `openid profile email offline_access` with Codex-specific auth params
- AuthManager skips OpenAI OAuth credentials for RubyLLM configuration (handled by CodexBridge)
- Default OpenAI model updated to `gpt-5.4`

## [0.1.0] - 2026-04-15

- Initial release

## [0.1.1] - 2026-04-15

- Fix CI workflow
