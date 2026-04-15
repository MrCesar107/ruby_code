# frozen_string_literal: true

require "test_helper"
require "ruby_coded/chat/state"

class TestStateScrollable < Minitest::Test
  def setup
    @state = RubyCoded::Chat::State.new(model: "gpt-4o")
  end

  def test_scroll_offset_starts_at_zero
    assert_equal 0, @state.scroll_offset
  end

  def test_scroll_up_increases_offset
    simulate_content(total_lines: 30, visible_height: 10)
    @state.scroll_up

    assert_equal 1, @state.scroll_offset
  end

  def test_scroll_up_with_custom_amount
    simulate_content(total_lines: 30, visible_height: 10)
    @state.scroll_up(3)

    assert_equal 3, @state.scroll_offset
  end

  def test_scroll_up_clamps_to_max
    simulate_content(total_lines: 12, visible_height: 10)
    @state.scroll_up(100)

    assert_equal 2, @state.scroll_offset
  end

  def test_scroll_down_decreases_offset
    simulate_content(total_lines: 30, visible_height: 10)
    @state.scroll_up(3)
    @state.scroll_down

    assert_equal 2, @state.scroll_offset
  end

  def test_scroll_down_clamps_to_zero
    simulate_content(total_lines: 12, visible_height: 10)
    @state.scroll_up(2)
    @state.scroll_down(100)

    assert_equal 0, @state.scroll_offset
  end

  def test_scroll_to_top
    simulate_content(total_lines: 25, visible_height: 10)
    @state.scroll_to_top

    assert_equal 15, @state.scroll_offset
  end

  def test_scroll_to_bottom
    simulate_content(total_lines: 30, visible_height: 10)
    @state.scroll_up(3)
    @state.scroll_to_bottom

    assert_equal 0, @state.scroll_offset
  end

  def test_scroll_up_noop_when_no_content
    @state.scroll_up
    assert_equal 0, @state.scroll_offset
  end

  def test_scroll_to_top_zero_when_no_content
    @state.scroll_to_top
    assert_equal 0, @state.scroll_offset
  end

  def test_max_scroll_zero_when_content_fits
    simulate_content(total_lines: 5, visible_height: 10)
    @state.scroll_to_top

    assert_equal 0, @state.scroll_offset
  end

  def test_update_scroll_metrics
    @state.update_scroll_metrics(total_lines: 50, visible_height: 20)
    @state.scroll_to_top

    assert_equal 30, @state.scroll_offset
  end

  private

  def simulate_content(total_lines:, visible_height:)
    @state.update_scroll_metrics(total_lines: total_lines, visible_height: visible_height)
  end
end
