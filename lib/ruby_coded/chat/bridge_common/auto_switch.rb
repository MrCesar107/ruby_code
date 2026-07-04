# frozen_string_literal: true

module RubyCoded
  module Chat
    module BridgeCommon
      # Recognizes "please implement the plan" style messages and
      # switches the runtime from plan mode to agent mode so that
      # write tools become available for execution.
      module AutoSwitch
        IMPLEMENTATION_PATTERNS = [
          /\bimplement/i,
          /\bgo ahead/i,
          /\bproceed/i,
          /\bexecut/i,
          /\bejecutar?/i,
          /\bcomenz/i,
          /\bcomienz/i,
          /\bhazlo/i,
          /\bconstru[iy]/i,
          /\badelante/i,
          /\bdale\b/i,
          /\bdo it/i,
          /\bbuild it/i
        ].freeze

        private

        def should_auto_switch_to_agent?(input)
          @mode.plan? && @state.respond_to?(:current_plan) && @state.current_plan &&
            implementation_request?(input)
        end

        def implementation_request?(input)
          IMPLEMENTATION_PATTERNS.any? { |pattern| input.match?(pattern) }
        end

        def auto_switch_to_agent!
          toggle_agentic_mode!(true)
          @state.add_message(:system,
                             "Plan mode disabled — switching to agent mode to implement the plan.")
        end
      end
    end
  end
end
