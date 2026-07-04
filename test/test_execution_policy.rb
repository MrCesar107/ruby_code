# frozen_string_literal: true

require "test_helper"
require "ruby_coded/tools/execution_policy"
require "ruby_coded/tools/registry"
require "ruby_coded/chat/state"
require "ruby_coded/chat/runtime_mode"

class TestExecutionPolicy < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @state = RubyCoded::Chat::State.new(model: "test-model")
    @registry = RubyCoded::Tools::Registry.new(project_root: @tmpdir)
    @policy = RubyCoded::Tools::ExecutionPolicy.new(state: @state, registry: @registry)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_register_call_returns_safe_risk_for_read_file
    assert_equal :safe, @policy.register_call!("read_file_tool")
  end

  def test_register_call_returns_confirm_risk_for_write_file
    assert_equal :confirm, @policy.register_call!("write_file_tool")
  end

  def test_register_call_returns_dangerous_risk_for_run_command
    assert_equal :dangerous, @policy.register_call!("run_command_tool")
  end

  def test_safe_calls_do_not_consume_write_budget
    write_budget = RubyCoded::Tools::ExecutionPolicy::MAX_WRITE_TOOL_ROUNDS
    write_budget.times { @policy.register_call!("read_file_tool") }
    # After many safe calls, we should still be able to register writes.
    assert_nothing_raised { @policy.register_call!("write_file_tool") }
  end

  def test_write_budget_auto_resets_with_system_message
    budget = RubyCoded::Tools::ExecutionPolicy::MAX_WRITE_TOOL_ROUNDS
    budget.times { @policy.register_call!("write_file_tool") }

    last_msg = @state.messages_snapshot.last
    assert_equal :system, last_msg[:role]
    assert_includes last_msg[:content], "Write tool call budget"
  end

  def test_total_budget_raises_iteration_limit_error
    total = RubyCoded::Tools::ExecutionPolicy::MAX_TOTAL_TOOL_ROUNDS

    (total + 1).times do |i|
      if i == total
        assert_raises(RubyCoded::Tools::AgentIterationLimitError) do
          @policy.register_call!("read_file_tool")
        end
      else
        @policy.register_call!("read_file_tool")
      end
    end
  end

  def test_reset_counters_allows_further_calls
    total = RubyCoded::Tools::ExecutionPolicy::MAX_TOTAL_TOOL_ROUNDS
    total.times { @policy.register_call!("read_file_tool") }

    @policy.reset_counters!

    assert_nothing_raised { @policy.register_call!("read_file_tool") }
  end

  def test_warn_if_approaching_limit_emits_at_threshold
    threshold = (RubyCoded::Tools::ExecutionPolicy::MAX_TOTAL_TOOL_ROUNDS *
                 RubyCoded::Tools::ExecutionPolicy::WARNING_THRESHOLD_RATIO).to_i

    threshold.times { @policy.register_call!("read_file_tool") }
    @policy.warn_if_approaching_limit!

    last_msg = @state.messages_snapshot.last
    assert_equal :system, last_msg[:role]
    assert_includes last_msg[:content], "Approaching total tool call limit"
  end

  def test_requires_confirmation_false_for_safe
    assert_equal false, @policy.requires_confirmation?(:safe, RubyCoded::Chat::RuntimeMode.agent)
  end

  def test_requires_confirmation_true_for_confirm_in_agent_mode
    assert @policy.requires_confirmation?(:confirm, RubyCoded::Chat::RuntimeMode.agent)
  end

  def test_requires_confirmation_true_for_dangerous_in_agent_mode
    assert @policy.requires_confirmation?(:dangerous, RubyCoded::Chat::RuntimeMode.agent)
  end

  def test_requires_confirmation_false_when_auto_approve_enabled
    @state.enable_auto_approve!
    refute @policy.requires_confirmation?(:confirm, RubyCoded::Chat::RuntimeMode.agent)
    refute @policy.requires_confirmation?(:dangerous, RubyCoded::Chat::RuntimeMode.agent)
  end

  def test_requires_confirmation_false_in_chat_mode
    refute @policy.requires_confirmation?(:confirm, RubyCoded::Chat::RuntimeMode.chat)
  end

  def test_risk_label_maps_to_dangerous_or_write
    assert_equal "DANGEROUS", @policy.risk_label_for(:dangerous)
    assert_equal "WRITE", @policy.risk_label_for(:confirm)
  end

  private

  def assert_nothing_raised
    yield
  rescue StandardError => e
    flunk("Expected no exception, got #{e.class}: #{e.message}")
  end
end
