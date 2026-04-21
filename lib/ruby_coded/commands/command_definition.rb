# frozen_string_literal: true

module RubyCoded
  module Commands
    # Normalized command metadata shared by core, plugin, and markdown commands.
    class CommandDefinition
      ATTRIBUTES = %i[name description handler source usage content path].freeze

      attr_reader(*ATTRIBUTES)

      def initialize(**attrs)
        ATTRIBUTES.each { |name| instance_variable_set(ivar(name), attrs[name]) }
      end

      def markdown?
        @source == :markdown
      end

      def executable?
        !@handler.nil? || markdown?
      end

      private

      def ivar(name)
        :"@#{name}"
      end
    end
  end
end
