# frozen_string_literal: true

require "test_helper"
require "ruby_llm"
require "ruby_code/chat/llm_bridge"
require "ruby_code/chat/state"

class TestLLMBridge < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "test-model")
  end

  def test_attempt_with_retries_succeeds_on_first_try
    response = mock_response(content: "Hello!", input_tokens: 5, output_tokens: 2)
    chat = build_chat(responses: [response])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    result = bridge.send(:attempt_with_retries, chat, "Hi")

    assert_equal response, result
  end

  def test_attempt_with_retries_retries_on_rate_limit_then_succeeds
    response = mock_response(content: "Hello!", input_tokens: 5, output_tokens: 2)
    chat = build_chat(responses: [rate_limit_error, response])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    bridge.stub(:sleep, nil) do
      result = bridge.send(:attempt_with_retries, chat, "Hi")
      assert_equal response, result
    end
  end

  def test_attempt_with_retries_fails_after_max_retries
    chat = build_chat(responses: [rate_limit_error, rate_limit_error, rate_limit_error])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    bridge.stub(:sleep, nil) do
      result = bridge.send(:attempt_with_retries, chat, "Hi")
      assert_nil result
    end

    last_msg = @state.messages.last
    assert_includes last_msg[:content], "Límite de peticiones del proveedor"
  end

  def test_attempt_with_retries_does_not_retry_other_errors
    chat = build_chat(responses: [StandardError.new("Connection failed")])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    result = bridge.send(:attempt_with_retries, chat, "Hi")

    assert_nil result
    last_msg = @state.messages.last
    assert_includes last_msg[:content], "Connection failed"
  end

  def test_attempt_with_retries_respects_cancel
    chat = build_chat(responses: [rate_limit_error])
    bridge = build_bridge_with_chat(chat)
    bridge.cancel!

    @state.add_message(:assistant, "")
    bridge.stub(:sleep, nil) do
      result = bridge.send(:attempt_with_retries, chat, "Hi")
      assert_nil result
    end
  end

  def test_retry_uses_exponential_backoff
    response = mock_response(content: "OK", input_tokens: 1, output_tokens: 1)
    chat = build_chat(responses: [rate_limit_error, rate_limit_error, response])
    bridge = build_bridge_with_chat(chat)

    delays = []
    @state.add_message(:assistant, "")
    bridge.stub(:sleep, ->(d) { delays << d }) do
      bridge.send(:attempt_with_retries, chat, "Hi")
    end

    assert_equal [2, 4], delays
  end

  def test_retry_clears_assistant_content_before_retrying
    response = mock_response(content: "Success", input_tokens: 1, output_tokens: 1)
    chat = build_chat(responses: [rate_limit_error, response])
    bridge = build_bridge_with_chat(chat)

    @state.add_message(:assistant, "")
    bridge.stub(:sleep, nil) do
      bridge.send(:attempt_with_retries, chat, "Hi")
    end

    last_msg = @state.messages.last
    assert_equal "Success", last_msg[:content]
  end

  private

  def rate_limit_error
    RubyLLM::RateLimitError.new(nil, "Rate limit exceeded")
  end

  def build_bridge_with_chat(chat)
    RubyLLM.stub(:chat, chat) do
      return RubyCode::Chat::LLMBridge.new(@state)
    end
  end

  def build_chat(responses:)
    call_index = 0

    make_chunk = lambda { |content|
      chunk = Object.new
      chunk.define_singleton_method(:content) { content }
      chunk
    }

    chat = Object.new

    chat.define_singleton_method(:ask) do |_input, &block|
      resp = responses[call_index]
      call_index += 1
      raise resp if resp.is_a?(Exception)

      block&.call(make_chunk.call(resp.content)) if resp.respond_to?(:content)
      resp
    end

    chat.define_singleton_method(:complete) do |&block|
      resp = responses[call_index]
      call_index += 1
      raise resp if resp.is_a?(Exception)

      block&.call(make_chunk.call(resp.content)) if resp.respond_to?(:content)
      resp
    end

    chat
  end

  def mock_response(content:, input_tokens:, output_tokens:)
    resp = Object.new
    resp.define_singleton_method(:content) { content }
    resp.define_singleton_method(:input_tokens) { input_tokens }
    resp.define_singleton_method(:output_tokens) { output_tokens }
    resp
  end
end
