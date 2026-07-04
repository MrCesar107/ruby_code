# frozen_string_literal: true

# Commands are **explicit user-invoked actions**.
#
# Every command is triggered by the user typing a leading slash
# (e.g. `/agent`, `/plan`, `/model`, `/help`, or a project-local
# markdown command like `/review-auth`). Commands are dispatched by
# CommandHandler and never fire automatically.
#
# See also:
# - RubyCoded::Skills   — automatic prompt overlays (no user typing).
# - RubyCoded::Plugins  — code-level behavioral extensions.

require_relative "commands/command_definition"
require_relative "commands/core_provider"
require_relative "commands/plugin_provider"
require_relative "commands/markdown_loader"
require_relative "commands/markdown_provider"
require_relative "commands/catalog"
