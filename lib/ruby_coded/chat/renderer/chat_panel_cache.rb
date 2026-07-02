# frozen_string_literal: true

module RubyCoded
  module Chat
    class Renderer
      # Generation-aware caching of built chat sections and their derived
      # plain-text and rich-line representations.
      module ChatPanelCache
        private

        def init_render_cache
          @cached_chat_sections = nil
          @cached_format_gen = -1
        end

        def cached_chat_sections(messages)
          gen = @state.message_generation
          if gen != @cached_format_gen
            @cached_chat_sections = build_chat_sections(messages)
            @cached_format_gen = gen
          end
          @cached_chat_sections
        end

        def cached_formatted_text(messages)
          sections_to_text(cached_chat_sections(messages))
        end

        def cached_formatted_lines(messages)
          sections_to_rich_lines(cached_chat_sections(messages))
        end
      end
    end
  end
end
