# frozen_string_literal: true

module RubyCoded
  module Errors
    # Authentication error
    class AuthError < StandardError
      def initialize(message = "Authentication failed")
        super(message)
      end
    end
  end
end
