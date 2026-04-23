# frozen_string_literal: true

require "ruby_llm"
require_relative "../codex_models"

module RubyCoded
  module Chat
    class State
      # Resolves current model context window and computes live context usage
      # based on the last turn's server-reported `usage` block. This reflects
      # the size of the prompt actually sent to the model on the most recent
      # request, not the total tokens spent in the session.
      module ContextWindow
        def current_model_context_window
          model_name = @model
          return unless model_name

          codex_model = CodexModels.find(model_name)
          return codex_model.context_window if codex_model.respond_to?(:context_window)

          resolve_ruby_llm_context_window(model_name)
        end

        def session_context_tokens_used
          last_turn_context_tokens
        end

        def session_context_usage_percentage
          context_window = current_model_context_window
          return nil unless context_window.to_i.positive?

          percentage = ((session_context_tokens_used.to_f / context_window) * 100).round
          percentage.clamp(0, 100)
        end

        private

        def resolve_ruby_llm_context_window(model_name)
          info = RubyLLM.models.find(model_name)
          return info.context_window if info.respond_to?(:context_window) && info.context_window
          return info.max_context_window if info.respond_to?(:max_context_window) && info.max_context_window

          metadata_context_window(info)
        rescue StandardError
          nil
        end

        def metadata_context_window(info)
          return unless info.respond_to?(:metadata)

          metadata = info.metadata
          return unless metadata.is_a?(Hash)

          metadata[:context_window] || metadata["context_window"]
        end
      end
    end
  end
end
