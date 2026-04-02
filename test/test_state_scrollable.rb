# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"

class TestStateScrollable < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
  end

  def test_scroll_offset_starts_at_zero
    assert_equal 0, @state.scroll_offset
  end

  def test_scroll_up_increases_offset
    add_messages(5)
    @state.scroll_up

    assert_equal 1, @state.scroll_offset
  end

  def test_scroll_up_with_custom_amount
    add_messages(5)
    @state.scroll_up(3)

    assert_equal 3, @state.scroll_offset
  end

  def test_scroll_up_clamps_to_max
    add_messages(3)
    @state.scroll_up(100)

    assert_equal 2, @state.scroll_offset
  end

  def test_scroll_down_decreases_offset
    add_messages(5)
    @state.scroll_up(3)
    @state.scroll_down

    assert_equal 2, @state.scroll_offset
  end

  def test_scroll_down_clamps_to_zero
    add_messages(3)
    @state.scroll_up(2)
    @state.scroll_down(100)

    assert_equal 0, @state.scroll_offset
  end

  def test_scroll_to_top
    add_messages(5)
    @state.scroll_to_top

    assert_equal 4, @state.scroll_offset
  end

  def test_scroll_to_bottom
    add_messages(5)
    @state.scroll_up(3)
    @state.scroll_to_bottom

    assert_equal 0, @state.scroll_offset
  end

  def test_scroll_up_noop_when_no_messages
    @state.scroll_up
    assert_equal 0, @state.scroll_offset
  end

  def test_scroll_to_top_zero_when_no_messages
    @state.scroll_to_top
    assert_equal 0, @state.scroll_offset
  end

  def test_max_scroll_with_one_message
    add_messages(1)
    @state.scroll_to_top

    assert_equal 0, @state.scroll_offset
  end

  private

  def add_messages(count)
    count.times { |i| @state.add_message(:user, "Message #{i + 1}") }
  end
end
