# frozen_string_literal: true

require_relative "runtime_mode"
require_relative "bridge_common/mode_transitions"
require_relative "bridge_common/tool_flow"
require_relative "bridge_common/auto_switch"

module RubyCoded
  module Chat
    # Shared behavior between LLMBridge and CodexBridge.
    #
    # Composes three concerns:
    #
    # - {ModeTransitions} — chat/agent/plan transitions + State sync,
    # - {ToolFlow}        — approve/reject/cancel + poll/apply decision,
    # - {AutoSwitch}      — "implement the plan" → agent mode heuristic.
    #
    # Consumers must:
    # - initialize `@mode = RuntimeMode.chat` (or another mode),
    # - initialize `@cancel_requested = false`,
    # - override `after_mode_change!` if the backend needs to
    #   reconfigure state (e.g. the RubyLLM chat instance).
    module BridgeCommon
      def self.included(base)
        base.include(ModeTransitions)
        base.include(ToolFlow)
        base.include(AutoSwitch)
      end
    end
  end
end
