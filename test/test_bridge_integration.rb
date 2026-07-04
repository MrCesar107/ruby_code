# frozen_string_literal: true

require "test_helper"
require "ruby_llm"
require "ruby_coded/chat/llm_bridge"
require "ruby_coded/chat/state"
require "ruby_coded/skills/catalog"
require "ruby_coded/chat/bridge_factory"

# Integration tests exercising full lifecycles across the newly
# decomposed components (RuntimeMode, ExecutionPolicy, BridgeCommon,
# PromptBuilder, BridgeFactory).
class TestBridgeIntegration < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @state = RubyCoded::Chat::State.new(model: "test-model")
    @state.add_message(:assistant, "")
    @skills = RubyCoded::Skills::Catalog.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  FakeToolCall = Struct.new(:name, :arguments)

  class FakeCredentialsStore
    def initialize(credentials)
      @credentials = credentials
    end

    def retrieve(_provider)
      @credentials
    end
  end

  # 1. Send → tool request → approval → completion.
  def test_send_tool_call_approval_completion_cycle
    tool_call = FakeToolCall.new("write_file_tool", { path: "a.txt", content: "hi" })
    chat = build_chat(tool_calls: [tool_call],
                      response: mock_response(content: "done", input_tokens: 1, output_tokens: 1))
    bridge = build_bridge(chat: chat)
    bridge.toggle_agentic_mode!(true)

    approver = Thread.new do
      wait_until(2) { @state.awaiting_tool_confirmation? }
      bridge.approve_tool!
    end

    thread = bridge.send_async("please write file")
    thread.join(5)
    approver.join(2)

    refute @state.streaming?
    tool_msgs = @state.messages_snapshot.select { |m| m[:role] == :tool_call }
    assert(tool_msgs.any? { |m| m[:content].include?("write_file_tool") })
    refute @state.awaiting_tool_confirmation?
  end

  # 2. Cancel during streaming leaves State cleanly not-streaming.
  def test_cancel_during_streaming_cleans_state
    chat = build_chat(tool_calls: [], response: mock_response(content: "partial",
                                                              input_tokens: 1, output_tokens: 1),
                      slow: true)
    bridge = build_bridge(chat: chat)
    bridge.toggle_agentic_mode!(true)

    thread = bridge.send_async("hello")
    wait_until(2) { @state.streaming? }
    bridge.cancel!
    thread.join(5)

    refute @state.streaming?
    refute @state.awaiting_tool_confirmation?
  end

  # 3. BridgeFactory rebuilds the bridge and App-level code can
  #    restore the previous mode through the public API.
  def test_factory_rebuild_preserves_mode_via_public_api
    factory = RubyCoded::Chat::BridgeFactory.new(
      state: @state, credentials_store: FakeCredentialsStore.new(nil),
      auth_manager: nil, skill_catalog: @skills, user_config: nil
    )

    chat = build_configurable_chat
    bridge_b = nil
    RubyLLM.stub(:chat, chat) do
      bridge_a = factory.build
      bridge_a.toggle_agentic_mode!(true)
      previous_mode = bridge_a.mode

      bridge_b = factory.build
      case previous_mode.name
      when :agent then bridge_b.toggle_agentic_mode!(true)
      when :plan then bridge_b.toggle_plan_mode!(true)
      end
    end

    assert bridge_b.agentic_mode?
    assert bridge_b.mode.agent?
  end

  # 4. Plan mode only exposes readonly tools to the chat.
  def test_plan_mode_registers_only_readonly_tools
    chat = build_configurable_chat_with_tool_capture
    bridge = build_bridge(chat: chat, project_root: @tmpdir)
    bridge.toggle_plan_mode!(true)

    tool_class_names = chat.registered_tools.map { |t| t.class.name }
    tool_class_names.each do |name|
      readonly = RubyCoded::Tools::Registry::READONLY_TOOL_CLASSES.map(&:name)
      assert_includes readonly, name, "Unexpected non-readonly tool: #{name}"
    end
  end

  private

  def build_bridge(chat:, project_root: @tmpdir)
    RubyLLM.stub(:chat, chat) do
      return RubyCoded::Chat::LLMBridge.new(@state, project_root: project_root, skill_catalog: @skills)
    end
  end

  def build_chat(tool_calls:, response:, slow: false)
    chat = Object.new
    tool_callback = nil
    result_callback = nil

    chat.define_singleton_method(:with_tools) { |*_a, **_k| chat }
    chat.define_singleton_method(:with_instructions) { |*_a| chat }
    chat.define_singleton_method(:on_tool_call) do |&blk|
      tool_callback = blk
      chat
    end
    chat.define_singleton_method(:on_tool_result) do |&blk|
      result_callback = blk
      chat
    end

    chat.define_singleton_method(:ask) do |_input, &block|
      tool_calls.each do |tc|
        tool_callback&.call(tc)
        result_callback&.call("tool-ok")
      end
      chunk = fake_chunk("streaming...")
      block&.call(chunk)
      sleep(0.05) if slow
      response
    end
    chat.define_singleton_method(:complete) { |&_block| response }
    chat
  end

  def build_configurable_chat
    chat = Object.new
    chat.define_singleton_method(:messages) { [] }
    chat.define_singleton_method(:with_tools) { |*_a, **_k| chat }
    chat.define_singleton_method(:with_instructions) { |*_a| chat }
    chat.define_singleton_method(:on_tool_call) { |&_blk| chat }
    chat.define_singleton_method(:on_tool_result) { |&_blk| chat }
    chat
  end

  def build_configurable_chat_with_tool_capture
    chat = Object.new
    registered = []
    chat.define_singleton_method(:with_tools) do |*tools, **_k|
      registered.replace(tools)
      chat
    end
    chat.define_singleton_method(:with_instructions) { |*_a| chat }
    chat.define_singleton_method(:on_tool_call) { |&_blk| chat }
    chat.define_singleton_method(:on_tool_result) { |&_blk| chat }
    chat.define_singleton_method(:registered_tools) { registered }
    chat
  end

  def mock_response(content:, input_tokens:, output_tokens:)
    resp = Object.new
    resp.define_singleton_method(:content) { content }
    resp.define_singleton_method(:input_tokens) { input_tokens }
    resp.define_singleton_method(:output_tokens) { output_tokens }
    resp.define_singleton_method(:thinking_tokens) { nil }
    resp.define_singleton_method(:cached_tokens) { nil }
    resp.define_singleton_method(:cache_creation_tokens) { nil }
    resp
  end

  def fake_chunk(text)
    chunk = Object.new
    chunk.define_singleton_method(:content) { text }
    chunk
  end

  def wait_until(timeout)
    deadline = Time.now + timeout
    sleep(0.01) until yield || Time.now >= deadline
  end
end
