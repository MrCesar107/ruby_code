# frozen_string_literal: true

require "ruby_llm"

module RubyCode
  module Chat
    # Sends prompts to RubyLLM and streams assistant output into State.
    class LLMBridge
      MAX_RATE_LIMIT_RETRIES = 2
      RATE_LIMIT_BASE_DELAY = 2

      def initialize(state)
        @state = state
        @chat_mutex = Mutex.new
        @cancel_requested = false
        reset_chat!(@state.model)
      end

      def reset_chat!(model_name)
        @chat_mutex.synchronize do
          @chat = RubyLLM.chat(model: model_name)
        end
      end

      def send_async(input)
        chat = prepare_streaming
        Thread.new do
          response = attempt_with_retries(chat, input)
          update_response_tokens(response)
        ensure
          @state.streaming = false
        end
      end

      def cancel!
        @cancel_requested = true
      end

      private

      def prepare_streaming
        @cancel_requested = false
        @state.streaming = true
        @state.add_message(:assistant, "")
        @chat_mutex.synchronize { @chat }
      end

      def update_response_tokens(response)
        return unless response && !@cancel_requested && response.respond_to?(:input_tokens)

        @state.update_last_message_tokens(
          input_tokens: response.input_tokens,
          output_tokens: response.output_tokens
        )
      end

      def attempt_with_retries(chat, input, retries = 0)
        stream_response(chat, input, retries)
      rescue RubyLLM::RateLimitError => e
        retries = handle_rate_limit_retry(e, retries)
        retry if retries
        @state.fail_last_assistant(e, friendly_message: rate_limit_user_message(e))
        nil
      rescue StandardError => e
        @state.fail_last_assistant(e, friendly_message: generic_api_error_message(e))
        nil
      end

      def stream_response(chat, input, retries)
        block = streaming_block
        retries.zero? ? chat.ask(input, &block) : chat.complete(&block)
      end

      def streaming_block
        proc do |chunk|
          break if @cancel_requested

          @state.append_to_last_message(chunk.content) if chunk.content
        end
      end

      def handle_rate_limit_retry(error, retries)
        return unless retries < MAX_RATE_LIMIT_RETRIES && !@cancel_requested

        retries += 1
        delay = RATE_LIMIT_BASE_DELAY * (2**(retries - 1))
        @state.fail_last_assistant(
          error,
          friendly_message: "Rate limit alcanzado. Reintentando en #{delay}s... (#{retries}/#{MAX_RATE_LIMIT_RETRIES})"
        )
        sleep(delay)
        @state.reset_last_assistant_content
        retries
      end

      def rate_limit_user_message(error)
        <<~MSG.strip
          Límite de peticiones del proveedor (rate limit). Espera un minuto y vuelve a intentar; si se repite, revisa cuotas y plan en la consola de tu API (OpenAI, Anthropic, etc.).
          Detalle: #{error.message}
        MSG
      end

      def generic_api_error_message(error)
        "No se pudo obtener respuesta del modelo: #{error.message}"
      end
    end
  end
end
