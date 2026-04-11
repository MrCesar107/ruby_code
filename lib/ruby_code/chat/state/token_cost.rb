# frozen_string_literal: true

require "ruby_llm"

module RubyCode
  module Chat
    class State
      # Provides session cost calculation based on token usage and model pricing.
      # Looks up per-model pricing via RubyLLM's model registry.
      module TokenCost
        def init_token_cost
          @model_price_cache = {}
        end

        # Returns an array of cost breakdown hashes, one per model used:
        # [{ model:, input_tokens:, output_tokens:,
        #    input_price_per_million:, output_price_per_million:,
        #    input_cost:, output_cost:, total_cost: }]
        # Cost fields are nil when pricing is unavailable.
        def session_cost_breakdown
          token_usage_by_model.map do |model_name, usage|
            pricing = fetch_model_pricing(model_name)
            build_cost_entry(model_name, usage, pricing)
          end
        end

        def total_session_cost
          breakdown = session_cost_breakdown
          costs = breakdown.map { |entry| entry[:total_cost] }.compact
          return nil if costs.empty?

          costs.sum
        end

        private

        def fetch_model_pricing(model_name)
          return @model_price_cache[model_name] if @model_price_cache.key?(model_name)

          info = RubyLLM.models.find(model_name)
          pricing = if info && info.respond_to?(:input_price_per_million) && info.input_price_per_million
                      {
                        input_price_per_million: info.input_price_per_million.to_f,
                        output_price_per_million: info.output_price_per_million.to_f
                      }
                    end
          @model_price_cache[model_name] = pricing
          pricing
        rescue StandardError
          @model_price_cache[model_name] = nil
          nil
        end

        def build_cost_entry(model_name, usage, pricing)
          input_tokens = usage[:input_tokens]
          output_tokens = usage[:output_tokens]

          if pricing
            input_cost = (input_tokens.to_f / 1_000_000) * pricing[:input_price_per_million]
            output_cost = (output_tokens.to_f / 1_000_000) * pricing[:output_price_per_million]
            {
              model: model_name,
              input_tokens: input_tokens,
              output_tokens: output_tokens,
              input_price_per_million: pricing[:input_price_per_million],
              output_price_per_million: pricing[:output_price_per_million],
              input_cost: input_cost,
              output_cost: output_cost,
              total_cost: input_cost + output_cost
            }
          else
            {
              model: model_name,
              input_tokens: input_tokens,
              output_tokens: output_tokens,
              input_price_per_million: nil,
              output_price_per_million: nil,
              input_cost: nil,
              output_cost: nil,
              total_cost: nil
            }
          end
        end
      end
    end
  end
end
