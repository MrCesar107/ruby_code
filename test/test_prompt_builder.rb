# frozen_string_literal: true

require "test_helper"
require "ruby_coded/chat/prompt_builder"
require "ruby_coded/chat/runtime_mode"
require "ruby_coded/skills/catalog"

class TestPromptBuilder < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @skill_catalog = RubyCoded::Skills::Catalog.new(project_root: @tmpdir)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir)
  end

  def test_agent_prompt_includes_project_root_and_budget_info
    builder = build_builder(chat_base: :agentic)

    result = builder.build(RubyCoded::Chat::RuntimeMode.agent)

    assert_includes result, @tmpdir
    assert_includes result, "budget"
  end

  def test_plan_prompt_uses_plan_template
    builder = build_builder(chat_base: :agentic)

    result = builder.build(RubyCoded::Chat::RuntimeMode.plan)

    assert_includes result, "development planning assistant"
  end

  def test_chat_prompt_with_agentic_base_uses_system_prompt
    builder = build_builder(chat_base: :agentic)

    result = builder.build(RubyCoded::Chat::RuntimeMode.chat)

    assert_includes result, "coding assistant with access to the project directory"
  end

  def test_chat_prompt_with_simple_base_uses_default
    builder = build_builder(chat_base: :simple)

    result = builder.build(RubyCoded::Chat::RuntimeMode.chat)

    assert_equal RubyCoded::Chat::PromptBuilder::DEFAULT_CHAT_INSTRUCTIONS.strip, result.strip
  end

  def test_agent_prompt_appends_agent_skills
    write_skill("agent.md", "Agent Skill", "agent", "Read tests carefully.")
    builder = build_builder(chat_base: :agentic)

    result = builder.build(RubyCoded::Chat::RuntimeMode.agent)

    assert_includes result, "Agent Skill"
    assert_includes result, "Read tests carefully."
  end

  def test_plan_prompt_appends_only_plan_skills
    write_skill("agent.md", "Agent Skill", "agent", "Agent body.")
    write_skill("plan.md", "Plan Skill", "plan", "Plan body.")
    builder = build_builder(chat_base: :agentic)

    result = builder.build(RubyCoded::Chat::RuntimeMode.plan)

    assert_includes result, "Plan Skill"
    refute_includes result, "Agent Skill"
  end

  def test_chat_prompt_appends_only_chat_skills
    write_skill("chat.md", "Chat Skill", "chat", "Chat body.")
    write_skill("agent.md", "Agent Skill", "agent", "Agent body.")
    builder = build_builder(chat_base: :agentic)

    result = builder.build(RubyCoded::Chat::RuntimeMode.chat)

    assert_includes result, "Chat Skill"
    refute_includes result, "Agent Skill"
  end

  private

  def build_builder(chat_base:)
    RubyCoded::Chat::PromptBuilder.new(
      project_root: @tmpdir,
      skill_catalog: @skill_catalog,
      chat_base: chat_base
    )
  end

  def write_skill(filename, name, mode, body)
    skills_dir = File.join(@tmpdir, ".rubycoded", "skills")
    FileUtils.mkdir_p(skills_dir)
    File.write(File.join(skills_dir, filename), <<~MD)
      ---
      name: #{name}
      description: Description
      modes: [#{mode}]
      ---

      #{body}
    MD
    @skill_catalog.reload!
  end
end
