# frozen_string_literal: true

require "test_helper"
require "ruby_coded/plugins"
require "ruby_coded/chat/command_handler"
require "ruby_coded/chat/state"
require "ruby_coded/commands/catalog"

class TestAgentCommands < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = Dir.mktmpdir
    Dir.chdir(@tmpdir)

    @command_catalog = RubyCoded::Commands::Catalog.new(project_root: @tmpdir, plugin_registry: RubyCoded.plugin_registry)
    @state = RubyCoded::Chat::State.new(model: "test-model", command_catalog: @command_catalog)
    @llm_bridge = MockAgentBridge.new
    @handler = RubyCoded::Chat::CommandHandler.new(
      @state,
      llm_bridge: @llm_bridge,
      command_catalog: @command_catalog
    )
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_agent_on_enables_agentic_mode
    @handler.handle("/agent on")
    assert @llm_bridge.agentic_mode
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Agent mode enabled"
  end

  def test_agent_off_disables_agentic_mode
    @llm_bridge.toggle_agentic_mode!(true)
    @handler.handle("/agent off")
    refute @llm_bridge.agentic_mode
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Agent mode disabled"
  end

  def test_agent_on_when_already_enabled
    @llm_bridge.toggle_agentic_mode!(true)
    @handler.handle("/agent on")
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Agent session reset"
  end

  def test_agent_off_when_already_disabled
    @handler.handle("/agent off")
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "already disabled"
  end

  def test_agent_without_args_shows_status
    @handler.handle("/agent")
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "disabled"

    @llm_bridge.toggle_agentic_mode!(true)
    @handler.handle("/agent")
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "enabled"
  end

  def test_agent_with_invalid_arg_shows_usage
    @handler.handle("/agent maybe")
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "Usage"
  end

  def test_help_includes_agent_command
    @handler.handle("/help")
    last_msg = @state.messages_snapshot.last
    assert_includes last_msg[:content], "/agent"
  end


  class MockAgentBridge
    attr_reader :agentic_mode

    def initialize
      @agentic_mode = false
    end

    def toggle_agentic_mode!(enabled)
      @agentic_mode = enabled
    end

    def reset_agent_session!; end

    def reset_chat!(_model); end
  end
end
