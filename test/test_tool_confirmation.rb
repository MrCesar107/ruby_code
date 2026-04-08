# frozen_string_literal: true

require "test_helper"
require "ruby_code/chat/state"

class TestToolConfirmation < Minitest::Test
  def setup
    @state = RubyCode::Chat::State.new(model: "test-model")
  end

  def test_initially_not_awaiting_confirmation
    refute @state.awaiting_tool_confirmation?
  end

  def test_request_tool_confirmation_enters_confirmation_mode
    @state.request_tool_confirmation!("write_file_tool", { path: "test.txt", content: "hello" })

    assert @state.awaiting_tool_confirmation?
    assert_equal "write_file_tool", @state.pending_tool_name
    assert_equal({ path: "test.txt", content: "hello" }, @state.pending_tool_args)
    assert_nil @state.tool_confirmation_response
  end

  def test_request_adds_tool_pending_message
    @state.request_tool_confirmation!("write_file_tool", { path: "test.txt" }, risk_label: "WRITE")

    messages = @state.messages_snapshot
    assert_equal 1, messages.size
    assert_equal :tool_pending, messages.last[:role]
    assert_includes messages.last[:content], "write_file_tool"
    assert_includes messages.last[:content], "WRITE"
    assert_includes messages.last[:content], "[y] approve / [n] reject / [a] approve all"
  end

  def test_resolve_approved_updates_pending_message
    @state.request_tool_confirmation!("edit_file_tool", { path: "a.rb" })
    @state.resolve_tool_confirmation!(:approved)

    refute @state.awaiting_tool_confirmation?
    messages = @state.messages_snapshot
    last = messages.last
    assert_equal :tool_call, last[:role]
    assert_includes last[:content], "approved"
    refute_includes last[:content], "[y] approve"
  end

  def test_resolve_rejected_updates_pending_message
    @state.request_tool_confirmation!("delete_path_tool", { path: "tmp" }, risk_label: "DANGEROUS")
    @state.resolve_tool_confirmation!(:rejected)

    refute @state.awaiting_tool_confirmation?
    messages = @state.messages_snapshot
    last = messages.last
    assert_equal :tool_call, last[:role]
    assert_includes last[:content], "rejected"
  end

  def test_clear_tool_confirmation_resets_state
    @state.request_tool_confirmation!("write_file_tool", { path: "test.txt" })
    @state.clear_tool_confirmation!

    refute @state.awaiting_tool_confirmation?
    assert_nil @state.pending_tool_name
    assert_nil @state.pending_tool_args
    assert_equal :chat, @state.mode
  end

  def test_tool_confirmation_response_can_be_set
    @state.request_tool_confirmation!("run_command_tool", { command: "ls" })
    @state.tool_confirmation_response = :approved
    assert_equal :approved, @state.tool_confirmation_response
  end

  def test_mode_is_tool_confirmation_when_awaiting
    @state.request_tool_confirmation!("run_command_tool", { command: "ls" })
    assert_equal :tool_confirmation, @state.mode
  end

  def test_risk_label_defaults_to_write
    @state.request_tool_confirmation!("write_file_tool", { path: "f.txt" })
    messages = @state.messages_snapshot
    assert_includes messages.last[:content], "WRITE"
  end

  def test_dangerous_risk_label
    @state.request_tool_confirmation!("delete_path_tool", { path: "f.txt" }, risk_label: "DANGEROUS")
    messages = @state.messages_snapshot
    assert_includes messages.last[:content], "DANGEROUS"
  end

  # --- auto-approve tests ---

  def test_auto_approve_initially_disabled
    refute @state.auto_approve_tools?
  end

  def test_enable_auto_approve
    @state.enable_auto_approve!
    assert @state.auto_approve_tools?
  end

  def test_disable_auto_approve
    @state.enable_auto_approve!
    @state.disable_auto_approve!
    refute @state.auto_approve_tools?
  end

  def test_auto_approve_persists_across_confirmations
    @state.enable_auto_approve!

    @state.request_tool_confirmation!("write_file_tool", { path: "a.txt" })
    @state.resolve_tool_confirmation!(:approved)

    assert @state.auto_approve_tools?
  end

  def test_clear_tool_confirmation_does_not_reset_auto_approve
    @state.enable_auto_approve!
    @state.request_tool_confirmation!("write_file_tool", { path: "a.txt" })
    @state.clear_tool_confirmation!

    assert @state.auto_approve_tools?
  end
end
