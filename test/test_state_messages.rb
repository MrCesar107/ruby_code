# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"

class TestStateMessages < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "gpt-4o")
  end

  def test_add_message_appends_to_messages
    @state.add_message(:user, "Hello")

    assert_equal 1, @state.messages.size
    assert_equal :user, @state.messages.first[:role]
    assert_equal "Hello", @state.messages.first[:content]
  end

  def test_add_message_initializes_tokens_to_zero
    @state.add_message(:user, "Hello")

    msg = @state.messages.first
    assert_equal 0, msg[:input_tokens]
    assert_equal 0, msg[:output_tokens]
  end

  def test_add_message_includes_timestamp
    @state.add_message(:user, "Hello")
    assert_instance_of Time, @state.messages.first[:timestamp]
  end

  def test_add_message_scrolls_to_bottom
    @state.add_message(:user, "one")
    @state.add_message(:user, "two")
    @state.scroll_up
    refute_equal 0, @state.scroll_offset

    @state.add_message(:user, "three")
    assert_equal 0, @state.scroll_offset
  end

  def test_append_to_last_message
    @state.add_message(:assistant, "Hello")
    @state.append_to_last_message(" world")

    assert_equal "Hello world", @state.messages.last[:content]
  end

  def test_append_to_last_message_noop_when_empty
    @state.append_to_last_message("text")
    assert_empty @state.messages
  end

  def test_last_assistant_empty_true_when_no_messages
    assert @state.last_assistant_empty?
  end

  def test_last_assistant_empty_true_when_empty_content
    @state.add_message(:assistant, "")
    assert @state.last_assistant_empty?
  end

  def test_last_assistant_empty_false_when_has_content
    @state.add_message(:assistant, "Hello")
    refute @state.last_assistant_empty?
  end

  def test_last_assistant_empty_false_when_last_is_user
    @state.add_message(:user, "")
    refute @state.last_assistant_empty?
  end

  def test_reset_last_assistant_content_clears_content
    @state.add_message(:assistant, "some text")
    @state.reset_last_assistant_content

    assert_equal "", @state.messages.last[:content]
  end

  def test_reset_last_assistant_content_noop_for_user_message
    @state.add_message(:user, "text")
    @state.reset_last_assistant_content

    assert_equal "text", @state.messages.last[:content]
  end

  def test_reset_last_assistant_content_noop_when_empty
    @state.reset_last_assistant_content
    assert_empty @state.messages
  end

  def test_fail_last_assistant_with_friendly_message
    @state.add_message(:assistant, "")
    @state.fail_last_assistant(StandardError.new("err"), friendly_message: "Oops!")

    assert_equal "Oops!", @state.messages.last[:content]
  end

  def test_fail_last_assistant_with_default_message
    error = StandardError.new("connection failed")
    @state.add_message(:assistant, "")
    @state.fail_last_assistant(error)

    assert_includes @state.messages.last[:content], "StandardError"
    assert_includes @state.messages.last[:content], "connection failed"
  end

  def test_fail_last_assistant_appends_to_existing_content
    @state.add_message(:assistant, "Partial response")
    @state.fail_last_assistant(StandardError.new("err"), friendly_message: "Oops!")

    content = @state.messages.last[:content]
    assert_includes content, "Partial response"
    assert_includes content, "Oops!"
  end

  def test_fail_last_assistant_noop_for_user_message
    @state.add_message(:user, "text")
    @state.fail_last_assistant(StandardError.new("err"))

    assert_equal "text", @state.messages.last[:content]
  end

  def test_update_last_message_tokens
    @state.add_message(:user, "Hello")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 20)

    msg = @state.messages.last
    assert_equal 10, msg[:input_tokens]
    assert_equal 20, msg[:output_tokens]
  end

  def test_update_last_message_tokens_noop_when_empty
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 20)
    assert_empty @state.messages
  end

  def test_clear_messages_empties_list
    @state.add_message(:user, "Hello")
    @state.add_message(:assistant, "Hi")
    @state.clear_messages!

    assert_empty @state.messages
  end

  def test_clear_messages_resets_scroll
    @state.add_message(:user, "a")
    @state.add_message(:user, "b")
    @state.scroll_up
    @state.clear_messages!

    assert_equal 0, @state.scroll_offset
  end

  def test_total_input_tokens
    @state.add_message(:user, "a")
    @state.update_last_message_tokens(input_tokens: 5, output_tokens: 0)
    @state.add_message(:user, "b")
    @state.update_last_message_tokens(input_tokens: 10, output_tokens: 0)

    assert_equal 15, @state.total_input_tokens
  end

  def test_total_output_tokens
    @state.add_message(:assistant, "a")
    @state.update_last_message_tokens(input_tokens: 0, output_tokens: 8)
    @state.add_message(:assistant, "b")
    @state.update_last_message_tokens(input_tokens: 0, output_tokens: 12)

    assert_equal 20, @state.total_output_tokens
  end

  def test_total_tokens_zero_when_empty
    assert_equal 0, @state.total_input_tokens
    assert_equal 0, @state.total_output_tokens
  end

  def test_messages_snapshot_returns_independent_hashes
    @state.add_message(:user, "Hello")
    snapshot = @state.messages_snapshot

    snapshot.first[:role] = :changed
    assert_equal :user, @state.messages.first[:role]
  end

  def test_messages_snapshot_reflects_current_state
    @state.add_message(:user, "one")
    @state.add_message(:assistant, "two")

    snapshot = @state.messages_snapshot
    assert_equal 2, snapshot.size
    assert_equal :user, snapshot[0][:role]
    assert_equal :assistant, snapshot[1][:role]
  end
end
