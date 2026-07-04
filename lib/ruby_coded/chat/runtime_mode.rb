# frozen_string_literal: true

module RubyCoded
  module Chat
    # Value object representing the runtime mode of the assistant.
    #
    # Modes are the single source of truth for tool availability,
    # prompt selection, mutation permission, and confirmation policy.
    # Bridges hold a RuntimeMode instance instead of independent
    # boolean flags to avoid inconsistent combinations.
    class RuntimeMode
      NAMES = %i[chat agent plan].freeze

      attr_reader :name

      def initialize(name)
        raise ArgumentError, "unknown mode: #{name.inspect}" unless NAMES.include?(name)

        @name = name
      end

      def chat?
        @name == :chat
      end

      def agent?
        @name == :agent
      end

      def plan?
        @name == :plan
      end

      # Tools may be invoked in this mode (readonly for plan, full for agent).
      def allows_tools?
        agent? || plan?
      end

      # Destructive/write tools are permitted only in agent mode.
      def allows_mutation?
        agent?
      end

      # User confirmation is required for non-safe tools outside chat mode.
      def requires_confirmation?
        agent? || plan?
      end

      # Symbol used when querying skills for this mode.
      def skill_mode
        @name
      end

      def to_s
        @name.to_s
      end

      def ==(other)
        other.is_a?(RuntimeMode) && other.name == @name
      end
      alias eql? ==

      def hash
        [self.class, @name].hash
      end

      CHAT = new(:chat)
      AGENT = new(:agent)
      PLAN = new(:plan)

      class << self
        def chat
          CHAT
        end

        def agent
          AGENT
        end

        def plan
          PLAN
        end

        def for(value)
          return value if value.is_a?(RuntimeMode)

          case value.to_sym
          when :chat then CHAT
          when :agent then AGENT
          when :plan then PLAN
          else raise ArgumentError, "unknown mode: #{value.inspect}"
          end
        end
      end
    end
  end
end
