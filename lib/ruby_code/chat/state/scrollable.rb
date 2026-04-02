# frozen_string_literal: true

module RubyCode
  module Chat
    class State
      # This module contains the logic for the scrollable management
      module Scrollable
        def scroll_up(amount = 1)
          @scroll_offset = [@scroll_offset + amount, max_scroll].min
        end

        def scroll_down(amount = 1)
          @scroll_offset = [@scroll_offset - amount, 0].max
        end

        def scroll_to_top
          @scroll_offset = max_scroll
        end

        def scroll_to_bottom
          @scroll_offset = 0
        end

        private

        def max_scroll
          [@messages.length - 1, 0].max
        end
      end
    end
  end
end
