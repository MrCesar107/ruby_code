# frozen_string_literal: true

module RubyCoded
  class Initializer
    # Cover class for printing the cover of the RubyCoded gem
    module Cover
      BANNER = <<~'COVER'

             /\
            /  \
           /    \         ____        _              ____          _          _
          /------\       |  _ \ _   _| |__  _   _   / ___|___   __| | ___  __| |
         /  \  /  \      | |_) | | | | '_ \| | | | | |   / _ \ / _` |/ _ \/ _` |
        /    \/    \     |  _ <| |_| | |_) | |_| | | |__| (_) | (_| |  __/ (_| |
        \    /\    /     |_| \_\\__,_|_.__/ \__, |  \____\___/ \__,_|\___|\__,_|
         \  /  \  /                         |___/
          \/    \/
           \    /                           v%<version>s
            \  /
             \/

      COVER

      def self.print_cover_message
        puts BANNER.sub("%<version>s", RubyCoded::VERSION)
      end
    end
  end
end
