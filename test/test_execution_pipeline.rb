# frozen_string_literal: true

require "test_helper"
require "ruby_coded/tools/execution_pipeline"

class TestExecutionPipeline < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @pipeline = RubyCoded::Tools::ExecutionPipeline.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_yields_resolved_full_path_when_path_is_given
    File.write(File.join(@tmpdir, "foo.txt"), "hello")

    result = @pipeline.call(path: "foo.txt") do |full_path|
      "read: #{File.read(full_path)}"
    end

    assert_equal "read: hello", result
  end

  def test_yields_nil_when_no_path_is_given
    result = @pipeline.call { |full_path| full_path.nil? ? "ok" : "not nil" }

    assert_equal "ok", result
  end

  def test_returns_error_when_path_escapes_project_root
    result = @pipeline.call(path: "../outside.txt") { |_| flunk("block should not run") }

    assert_kind_of Hash, result
    assert_includes result[:error], "outside the project directory"
  end

  def test_rejects_project_root_when_forbid_root_is_true
    result = @pipeline.call(path: ".", forbid_root: true) { |_| flunk("block should not run") }

    assert_equal({ error: "Cannot operate on the project root" }, result)
  end

  def test_allows_project_root_when_forbid_root_is_false
    result = @pipeline.call(path: ".") { |full_path| "root: #{full_path}" }

    assert_match(/\Aroot: /, result)
  end

  def test_normalizes_syscall_errors_from_the_block
    result = @pipeline.call(path: "missing.txt") do |full_path|
      File.read(full_path)
    end

    assert_kind_of Hash, result
    assert_includes result[:error], "Filesystem error"
  end

  def test_passes_through_error_hash_returned_by_block
    result = @pipeline.call(path: "foo.txt") { |_| { error: "custom error" } }

    assert_equal({ error: "custom error" }, result)
  end

  def test_passes_through_success_string_returned_by_block
    result = @pipeline.call(path: "foo.txt") { |_| "ok" }

    assert_equal "ok", result
  end
end
