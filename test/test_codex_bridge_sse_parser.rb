# frozen_string_literal: true

require "test_helper"
require "ruby_coded/chat/state"
require "ruby_coded/chat/codex_bridge/sse_parser"

class TestCodexBridgeSSEParser < Minitest::Test
  def setup
    @state = RubyCoded::Chat::State.new(model: "gpt-5.4")
    @state.add_message(:assistant, "")
    @host = SSEParserHost.new(@state, "gpt-5.4")
  end

  def test_response_completed_records_input_and_output_tokens
    event = {
      "type" => "response.completed",
      "response" => {
        "usage" => { "input_tokens" => 1234, "output_tokens" => 567 }
      }
    }

    @host.dispatch_sse_event(event, +"", [])

    assert_equal 1234, @state.total_input_tokens
    assert_equal 567, @state.total_output_tokens
  end

  def test_response_completed_records_reasoning_tokens_as_thinking
    event = {
      "type" => "response.completed",
      "response" => {
        "usage" => {
          "input_tokens" => 100,
          "output_tokens" => 200,
          "output_tokens_details" => { "reasoning_tokens" => 350 }
        }
      }
    }

    @host.dispatch_sse_event(event, +"", [])

    assert_equal 350, @state.total_thinking_tokens
  end

  def test_response_completed_records_cached_tokens
    event = {
      "type" => "response.completed",
      "response" => {
        "usage" => {
          "input_tokens" => 100,
          "output_tokens" => 200,
          "input_tokens_details" => { "cached_tokens" => 75 }
        }
      }
    }

    @host.dispatch_sse_event(event, +"", [])

    assert_equal 75, @state.messages.last[:cached_tokens]
  end

  def test_response_completed_attributes_usage_to_current_model
    event = {
      "type" => "response.completed",
      "response" => {
        "usage" => { "input_tokens" => 100, "output_tokens" => 50 }
      }
    }

    @host.dispatch_sse_event(event, +"", [])

    usage = @state.token_usage_by_model["gpt-5.4"]
    assert_equal 100, usage[:input_tokens]
    assert_equal 50, usage[:output_tokens]
  end

  def test_response_completed_without_usage_is_noop
    event = { "type" => "response.completed", "response" => {} }

    @host.dispatch_sse_event(event, +"", [])

    assert_equal 0, @state.total_input_tokens
    assert_equal 0, @state.total_output_tokens
  end

  def test_response_completed_accepts_top_level_usage
    event = {
      "type" => "response.completed",
      "usage" => { "input_tokens" => 42, "output_tokens" => 7 }
    }

    @host.dispatch_sse_event(event, +"", [])

    assert_equal 42, @state.total_input_tokens
    assert_equal 7, @state.total_output_tokens
  end

  def test_response_completed_session_context_usage_percentage_is_non_zero
    event = {
      "type" => "response.completed",
      "response" => {
        "usage" => { "input_tokens" => 27_200, "output_tokens" => 0 }
      }
    }

    @host.dispatch_sse_event(event, +"", [])

    assert_equal 10, @state.session_context_usage_percentage
  end

  def test_text_delta_event_still_appends_to_assistant_text
    assistant_text = +""
    event = { "type" => "response.output_text.delta", "delta" => "Hello" }

    @host.dispatch_sse_event(event, assistant_text, [])

    assert_equal "Hello", assistant_text
  end

  # --- Host ---

  class SSEParserHost
    include RubyCoded::Chat::CodexBridge::SSEParser

    def initialize(state, model)
      @state = state
      @model = model
      @cancel_requested = false
    end

    public :dispatch_sse_event
  end
end
