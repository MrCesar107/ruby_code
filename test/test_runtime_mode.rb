# frozen_string_literal: true

require "test_helper"
require "ruby_coded/chat/runtime_mode"

class TestRuntimeMode < Minitest::Test
  def test_chat_mode_predicates
    mode = RubyCoded::Chat::RuntimeMode.chat
    assert mode.chat?
    refute mode.agent?
    refute mode.plan?
    refute mode.allows_tools?
    refute mode.allows_mutation?
    refute mode.requires_confirmation?
  end

  def test_agent_mode_predicates
    mode = RubyCoded::Chat::RuntimeMode.agent
    refute mode.chat?
    assert mode.agent?
    refute mode.plan?
    assert mode.allows_tools?
    assert mode.allows_mutation?
    assert mode.requires_confirmation?
  end

  def test_plan_mode_predicates
    mode = RubyCoded::Chat::RuntimeMode.plan
    refute mode.chat?
    refute mode.agent?
    assert mode.plan?
    assert mode.allows_tools?
    refute mode.allows_mutation?
    assert mode.requires_confirmation?
  end

  def test_skill_mode_returns_name
    assert_equal :chat, RubyCoded::Chat::RuntimeMode.chat.skill_mode
    assert_equal :agent, RubyCoded::Chat::RuntimeMode.agent.skill_mode
    assert_equal :plan, RubyCoded::Chat::RuntimeMode.plan.skill_mode
  end

  def test_for_accepts_symbol_string_and_instance
    chat = RubyCoded::Chat::RuntimeMode.chat
    assert_equal chat, RubyCoded::Chat::RuntimeMode.for(:chat)
    assert_equal chat, RubyCoded::Chat::RuntimeMode.for("chat")
    assert_same chat, RubyCoded::Chat::RuntimeMode.for(chat)
  end

  def test_for_raises_for_unknown_mode
    assert_raises(ArgumentError) { RubyCoded::Chat::RuntimeMode.for(:something_else) }
  end

  def test_equality_and_hash_by_name
    a = RubyCoded::Chat::RuntimeMode.agent
    b = RubyCoded::Chat::RuntimeMode.agent
    assert_equal a, b
    assert_equal a.hash, b.hash
  end

  def test_to_s_returns_name
    assert_equal "agent", RubyCoded::Chat::RuntimeMode.agent.to_s
  end
end
