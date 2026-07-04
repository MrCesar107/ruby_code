# frozen_string_literal: true

require "test_helper"
require "ruby_coded/chat/bridge_factory"
require "ruby_coded/chat/state"
require "ruby_coded/skills/catalog"

class TestBridgeFactory < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @state = RubyCoded::Chat::State.new(model: "gpt-4o")
    @skill_catalog = RubyCoded::Skills::Catalog.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_builds_llm_bridge_when_no_openai_credentials
    factory = build_factory(credentials_store: FakeCredentialsStore.new(nil))

    RubyLLM.stub(:chat, fake_chat) do
      bridge = factory.build
      assert_kind_of RubyCoded::Chat::LLMBridge, bridge
    end
    refute @state.codex_mode
  end

  def test_builds_llm_bridge_when_credentials_are_api_key
    creds = { "auth_method" => "api_key", "key" => "sk-test" }
    factory = build_factory(credentials_store: FakeCredentialsStore.new(creds))

    RubyLLM.stub(:chat, fake_chat) do
      bridge = factory.build
      assert_kind_of RubyCoded::Chat::LLMBridge, bridge
    end
    refute @state.codex_mode
  end

  def test_builds_codex_bridge_when_oauth_credentials_present
    creds = { "auth_method" => "oauth", "access_token" => "abc" }
    factory = build_factory(credentials_store: FakeCredentialsStore.new(creds))

    bridge = factory.build

    assert_kind_of RubyCoded::Chat::CodexBridge, bridge
    assert @state.codex_mode
  end

  def test_falls_back_to_codex_default_model_when_current_model_invalid
    creds = { "auth_method" => "oauth", "access_token" => "abc" }
    user_config = FakeUserConfig.new
    factory = build_factory(credentials_store: FakeCredentialsStore.new(creds), user_config: user_config)

    factory.build

    assert_equal RubyCoded::Chat::CodexBridge::DEFAULT_MODEL, @state.model
    assert_equal RubyCoded::Chat::CodexBridge::DEFAULT_MODEL, user_config.saved["model"]
  end

  private

  def build_factory(credentials_store:, user_config: nil)
    RubyCoded::Chat::BridgeFactory.new(
      state: @state,
      credentials_store: credentials_store,
      auth_manager: nil,
      skill_catalog: @skill_catalog,
      user_config: user_config
    )
  end

  def fake_chat
    chat = Object.new
    chat.define_singleton_method(:with_tools) { |*_a, **_k| chat }
    chat.define_singleton_method(:with_instructions) { |*_a| chat }
    chat.define_singleton_method(:on_tool_call) { |&_blk| chat }
    chat.define_singleton_method(:on_tool_result) { |&_blk| chat }
    chat
  end

  class FakeCredentialsStore
    def initialize(credentials)
      @credentials = credentials
    end

    def retrieve(_provider)
      @credentials
    end
  end

  class FakeUserConfig
    attr_reader :saved

    def initialize
      @saved = {}
    end

    def set_config(key, value)
      @saved[key] = value
    end
  end
end
