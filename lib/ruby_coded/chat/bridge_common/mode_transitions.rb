# frozen_string_literal: true

require_relative "../runtime_mode"

module RubyCoded
  module Chat
    module BridgeCommon
      # Encapsulates transitions between chat/agent/plan modes and
      # keeps the associated State flags (agentic_mode, plan tracking,
      # auto-approve) consistent.
      module ModeTransitions
        def agentic_mode?
          @mode.agent?
        end

        def plan_mode?
          @mode.plan?
        end

        def toggle_agentic_mode!(enabled)
          if enabled
            transition_to_agent!
          else
            transition_out_of_agent!
          end
          after_mode_change!
        end

        def toggle_plan_mode!(enabled)
          if enabled
            transition_to_plan!
          elsif @mode.plan?
            @mode = RuntimeMode.chat
          end
          after_mode_change!
        end

        private

        # Override in the concrete bridge when reconfiguration is
        # needed after a mode change (e.g. re-registering tools).
        def after_mode_change!
          nil
        end

        def transition_to_agent!
          was_plan = @mode.plan?
          @mode = RuntimeMode.agent
          @state.agentic_mode = true
          @state.deactivate_plan_mode! if was_plan
        end

        def transition_out_of_agent!
          @mode = RuntimeMode.chat if @mode.agent?
          @state.agentic_mode = false
          @state.disable_auto_approve!
        end

        def transition_to_plan!
          was_agent = @mode.agent?
          @mode = RuntimeMode.plan
          return unless was_agent

          @state.agentic_mode = false
          @state.disable_auto_approve!
        end
      end
    end
  end
end
