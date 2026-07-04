# frozen_string_literal: true

# Skills are **automatic instruction overlays** applied to the
# system prompt for a given mode.
#
# The user does not invoke a skill directly; the PromptBuilder
# consults the Skills::Catalog for the active RuntimeMode and
# appends the relevant skills to the final instructions. Skills
# are defined as markdown files under `.rubycoded/skills`.
#
# See also:
# - RubyCoded::Commands — explicit user-invoked slash actions.
# - RubyCoded::Plugins  — code-level behavioral extensions.

require_relative "skills/skill_definition"
require_relative "skills/markdown_loader"
require_relative "skills/catalog"
require_relative "skills/prompt_formatter"
