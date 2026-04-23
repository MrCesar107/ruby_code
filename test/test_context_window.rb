# frozen_string_literal: true

require "test_helper"
require "ruby_llm"
require "ruby_coded/chat/state"

class TestContextWindow < Minitest::Test
  def setup
    @state = RubyCoded::Chat::State.new(model: "custom-model")
  end

  def test_current_model_context_window_uses_ruby_llm_context_window
    info = Struct.new(:context_window).new(128_000)
    models = Object.new
    models.define_singleton_method(:find) { |_name| info }

    RubyLLM.stub(:models, models) do
      assert_equal 128_000, @state.current_model_context_window
    end
  end

  def test_current_model_context_window_uses_ruby_llm_max_context_window
    info = Struct.new(:max_context_window).new(200_000)
    models = Object.new
    models.define_singleton_method(:find) { |_name| info }

    RubyLLM.stub(:models, models) do
      assert_equal 200_000, @state.current_model_context_window
    end
  end

  def test_current_model_context_window_uses_metadata_hash
    info = Struct.new(:metadata).new({ context_window: 64_000 })
    models = Object.new
    models.define_singleton_method(:find) { |_name| info }

    RubyLLM.stub(:models, models) do
      assert_equal 64_000, @state.current_model_context_window
    end
  end

  def test_current_model_context_window_returns_nil_when_lookup_fails
    models = Object.new
    models.define_singleton_method(:find) { |_name| raise StandardError, "boom" }

    RubyLLM.stub(:models, models) do
      assert_nil @state.current_model_context_window
    end
  end
end
