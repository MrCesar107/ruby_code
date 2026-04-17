# frozen_string_literal: true

require "test_helper"
require "ruby_coded/version"
require "ruby_coded/initializer"

class TestInitializer < Minitest::Test
  def setup
    @original_dir = Dir.pwd
    @tmpdir = File.realpath(Dir.mktmpdir)
    @config_path = File.join(@tmpdir, "config.yaml")
    Dir.chdir(@tmpdir)
  end

  def teardown
    Dir.chdir(@original_dir)
    FileUtils.remove_entry(@tmpdir)
  end

  def test_does_not_ask_permission_when_already_granted
    write_config(trusted_directories: [File.expand_path(@tmpdir)], with_provider: true)

    mock_prompt = build_prompt_stub
    output = capture_io do
      TTY::Prompt.stub(:new, mock_prompt) do
        stub_user_config do
          stub_auth_manager do
            RubyCoded::Initializer.new
          end
        end
      end
    end.first

    refute_includes output, "Do you trust this directory?"
  end

  def test_asks_for_permission_when_not_granted
    write_config(trusted_directories: [], with_provider: true)

    mock_prompt = build_prompt_stub(yes_response: true)

    TTY::Prompt.stub(:new, mock_prompt) do
      stub_user_config do
        stub_auth_manager do
          RubyCoded::Initializer.new
        end
      end
    end

    raw = YAML.load_file(@config_path, permitted_classes: [Symbol])
    assert_includes raw["user_config"]["trusted_directories"], File.expand_path(@tmpdir)
  end

  def test_exits_when_user_declines_permission
    write_config(trusted_directories: [], with_provider: true)

    mock_prompt = build_prompt_stub(yes_response: false)

    assert_raises(SystemExit) do
      TTY::Prompt.stub(:new, mock_prompt) do
        stub_user_config do
          stub_auth_manager do
            capture_io { RubyCoded::Initializer.new }
          end
        end
      end
    end
  end

  def test_creates_config_file_on_first_run
    mock_prompt = build_prompt_stub(yes_response: true)

    TTY::Prompt.stub(:new, mock_prompt) do
      stub_user_config do
        stub_auth_manager do
          capture_io { RubyCoded::Initializer.new }
        end
      end
    end

    assert File.exist?(@config_path)
  end

  def test_calls_check_authentication
    write_config(trusted_directories: [File.expand_path(@tmpdir)], with_provider: true)

    check_called = false
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { check_called = true }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { nil }
    auth_mock.define_singleton_method(:authenticated_provider_names) { [:openai] }

    mock_prompt = build_prompt_stub
    TTY::Prompt.stub(:new, mock_prompt) do
      RubyCoded::Auth::AuthManager.stub(:new, auth_mock) do
        stub_user_config do
          stub_chat_app do
            capture_io { RubyCoded::Initializer.new }
          end
        end
      end
    end

    assert check_called
  end

  def test_calls_configure_ruby_llm
    write_config(trusted_directories: [File.expand_path(@tmpdir)], with_provider: true)

    configure_called = false
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { nil }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { configure_called = true }
    auth_mock.define_singleton_method(:authenticated_provider_names) { [:openai] }

    mock_prompt = build_prompt_stub
    TTY::Prompt.stub(:new, mock_prompt) do
      RubyCoded::Auth::AuthManager.stub(:new, auth_mock) do
        stub_user_config do
          stub_chat_app do
            capture_io { RubyCoded::Initializer.new }
          end
        end
      end
    end

    assert configure_called
  end

  def test_uses_stored_model_when_provider_authenticated
    write_config(trusted_directories: [File.expand_path(@tmpdir)], model: "gpt-5.4", with_provider: true)

    captured_args = capture_app_args(authenticated: [:openai], model_authenticated: true)

    assert_equal "gpt-5.4", captured_args[:model]
    assert_nil captured_args[:fallback_from_model]
  end

  def test_falls_back_when_stored_model_provider_not_authenticated
    write_config(trusted_directories: [File.expand_path(@tmpdir)], model: "gpt-5.4", with_provider: true)

    captured_args = capture_app_args(authenticated: [:anthropic], model_authenticated: false)

    assert_equal "claude-sonnet-4-6", captured_args[:model]
    assert_equal "gpt-5.4", captured_args[:fallback_from_model]
  end

  def test_uses_provider_default_when_no_stored_model
    write_config(trusted_directories: [File.expand_path(@tmpdir)], model: nil, with_provider: true)

    captured_args = capture_app_args(authenticated: [:openai], model_authenticated: false)

    assert_equal "gpt-5.4", captured_args[:model]
    assert_nil captured_args[:fallback_from_model]
  end

  def test_uses_provider_default_when_stored_model_is_blank
    write_config(trusted_directories: [File.expand_path(@tmpdir)], model: "   ", with_provider: true)

    captured_args = capture_app_args(authenticated: [:anthropic], model_authenticated: false)

    assert_equal "claude-sonnet-4-6", captured_args[:model]
    assert_nil captured_args[:fallback_from_model]
  end

  private

  def capture_app_args(authenticated:, model_authenticated:)
    captured = {}
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { nil }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { nil }
    auth_mock.define_singleton_method(:authenticated_provider_names) { authenticated }
    auth_mock.define_singleton_method(:model_provider_authenticated?) { |_model| model_authenticated }

    app_stub = lambda do |**kwargs|
      captured.merge!(kwargs)
      app = Object.new
      app.define_singleton_method(:run) { nil }
      app
    end

    mock_prompt = build_prompt_stub
    TTY::Prompt.stub(:new, mock_prompt) do
      RubyCoded::Auth::AuthManager.stub(:new, auth_mock) do
        stub_user_config do
          RubyCoded::Chat::App.stub(:new, app_stub) do
            capture_io { RubyCoded::Initializer.new }
          end
        end
      end
    end

    captured
  end

  def write_config(trusted_directories: [], model: nil, with_provider: false)
    config = {
      "user_config" => {
        "trusted_directories" => trusted_directories,
        "model" => model
      }
    }
    config["providers"] = { "openai" => { "auth_method" => "api_key", "key" => "sk-test" } } if with_provider
    File.write(@config_path, config.to_yaml)
  end

  def build_prompt_stub(yes_response: true)
    stub = Object.new
    stub.define_singleton_method(:yes?) { |*_args| yes_response }
    stub.define_singleton_method(:select) { |*_args, **_kwargs| :openai }
    stub
  end

  def stub_user_config(&block)
    config_path = @config_path
    RubyCoded::UserConfig.stub(:new, ->(*_args, **_kwargs) { RubyCoded::UserConfig.allocate.tap { |c| c.send(:initialize, config_path: config_path) } }, &block)
  end

  def stub_chat_app(&)
    app_mock = Object.new
    app_mock.define_singleton_method(:run) { nil }

    RubyCoded::Chat::App.stub(:new, app_mock, &)
  end

  def stub_auth_manager(&block)
    auth_mock = Object.new
    auth_mock.define_singleton_method(:check_authentication) { nil }
    auth_mock.define_singleton_method(:configure_ruby_llm!) { nil }
    auth_mock.define_singleton_method(:authenticated_provider_names) { [:openai] }

    RubyCoded::Auth::AuthManager.stub(:new, auth_mock) do
      stub_chat_app(&block)
    end
  end
end
