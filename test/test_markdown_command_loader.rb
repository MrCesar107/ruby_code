# frozen_string_literal: true

require "test_helper"
require "ruby_coded/commands/markdown_loader"

class TestMarkdownCommandLoader < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @commands_dir = File.join(@tmpdir, ".ruby_coded", "commands")
    FileUtils.mkdir_p(@commands_dir)
    @loader = RubyCoded::Commands::MarkdownLoader.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_loads_valid_markdown_command
    File.write(File.join(@commands_dir, "review.md"), <<~MD)
      ---
      command: /review
      description: Review the current code
      usage: /review [context]
      ---

      Review the current code and suggest improvements.
    MD

    result = @loader.load_files

    assert_equal 1, result.size
    assert_equal "/review", result.first[:command]
    assert_equal "Review the current code", result.first[:description]
  end

  def test_ignores_file_without_frontmatter
    File.write(File.join(@commands_dir, "invalid.md"), "# no frontmatter\nbody")

    assert_empty @loader.load_files
  end

  def test_ignores_file_without_command
    File.write(File.join(@commands_dir, "invalid.md"), <<~MD)
      ---
      description: Missing command
      ---

      Some body.
    MD

    assert_empty @loader.load_files
  end

  def test_ignores_file_without_description
    File.write(File.join(@commands_dir, "invalid.md"), <<~MD)
      ---
      command: /review
      ---

      Some body.
    MD

    assert_empty @loader.load_files
  end

  def test_ignores_file_with_empty_body
    File.write(File.join(@commands_dir, "invalid.md"), <<~MD)
      ---
      command: /review
      description: Review command
      ---
    MD

    assert_empty @loader.load_files
  end

  def test_load_report_counts_invalid_files
    File.write(File.join(@commands_dir, "valid.md"), <<~MD)
      ---
      command: /review
      description: Review command
      ---

      Review the code.
    MD

    File.write(File.join(@commands_dir, "invalid.md"), "# invalid")

    report = @loader.load_report

    assert_equal 1, report[:entries].size
    assert_equal 1, report[:invalid_count]
    assert_equal ["invalid.md"], report[:invalid_files]
  end
end
