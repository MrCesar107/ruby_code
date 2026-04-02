# frozen_string_literal: true

require "test_helper"
require "ruby_code/version"
require "ruby_code/chat/state"
require "ruby_code/chat/renderer/chat_panel"

class TestRendererChatPanel < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
    @tui = MockTui.new
    @host = ChatPanelHost.new(@tui, @state)
  end

  def test_chat_panel_text_returns_banner_when_no_messages
    text = @host.chat_panel_text
    assert_includes text, "v#{RubyCode::VERSION}"
  end

  def test_chat_panel_text_formats_messages
    @state.add_message(:user, "Hello")
    @state.add_message(:assistant, "Hi there")

    text = @host.chat_panel_text
    assert_includes text, "user: Hello"
    assert_includes text, "assistant: Hi there"
  end

  def test_chat_panel_text_joins_messages_with_newlines
    @state.add_message(:user, "one")
    @state.add_message(:user, "two")

    text = @host.chat_panel_text
    lines = text.split("\n").reject(&:empty?)
    assert_equal 2, lines.size
  end

  def test_render_chat_panel_creates_paragraph_with_model_title
    frame = MockFrame.new
    area = :chat_area

    @host.render_chat_panel(frame, area)

    assert_equal 1, frame.rendered.size
    widget, rendered_area = frame.rendered.first
    assert_equal :chat_area, rendered_area
    assert_equal "gpt-4o", widget[:block][:title]
    assert_equal [:all], widget[:block][:borders]
  end

  def test_render_input_panel_shows_prompt_with_buffer
    @state.append_to_input("hello world")
    frame = MockFrame.new
    area = :input_area

    @host.render_input_panel(frame, area)

    widget, = frame.rendered.first
    assert_equal "ruby_code> hello world", widget[:text]
  end

  def test_render_input_panel_shows_empty_prompt
    frame = MockFrame.new

    @host.render_input_panel(frame, :input_area)

    widget, = frame.rendered.first
    assert_equal "ruby_code> ", widget[:text]
  end

  def test_cover_banner_includes_version
    banner = @host.cover_banner
    assert_includes banner, RubyCode::VERSION
    refute_includes banner, "%<version>s"
  end

  private

  class ChatPanelHost
    include RubyCode::Chat::Renderer::ChatPanel

    def initialize(tui, state)
      @tui = tui
      @state = state
    end

    public :chat_panel_text, :render_chat_panel, :render_input_panel, :cover_banner
  end

  class MockTui
    def paragraph(text:, block:)
      { type: :paragraph, text: text, block: block }
    end

    def block(title: nil, borders: [])
      { title: title, borders: borders }
    end
  end

  class MockFrame
    attr_reader :rendered

    def initialize
      @rendered = []
    end

    def render_widget(widget, area)
      @rendered << [widget, area]
    end
  end
end
