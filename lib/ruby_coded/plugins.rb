# frozen_string_literal: true

# Plugins are **code-level behavioral extensions** to the chat runtime.
#
# A plugin can extend State, InputHandler, Renderer, or CommandHandler
# through `apply_extensions!`. Plugins may register their own slash
# commands, but they may also add invisible behavior (e.g. command
# completion). Contrast with:
#
# - RubyCoded::Commands — explicit user-invoked slash actions.
# - RubyCoded::Skills   — automatic prompt overlays for the model.

require_relative "plugins/base"
require_relative "plugins/registry"

module RubyCoded # :nodoc:
  # Returns the global plugin registry.
  def self.plugin_registry
    @plugin_registry ||= Plugins::Registry.new
  end

  # Register a plugin class that extends the chat functionality.
  def self.register_plugin(plugin_class)
    plugin_registry.register(plugin_class)
  end
end

require_relative "plugins/command_completion/plugin"

RubyCoded.register_plugin(RubyCoded::Plugins::CommandCompletion::Plugin)
