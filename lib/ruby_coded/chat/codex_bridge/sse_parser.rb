# frozen_string_literal: true

module RubyCoded
  module Chat
    class CodexBridge
      # Parses Server-Sent Events from the Codex streaming response and
      # dispatches content deltas, tool calls, and completion signals.
      module SSEParser
        private

        def perform_codex_request(input)
          ensure_token_fresh!
          body = build_request_body

          assistant_text = +""
          pending_tool_calls = []
          buffer = +""
          raw_body = +""
          response_status = nil

          response = @conn.post(CODEX_RESPONSES_PATH) do |req|
            req.headers = codex_headers
            req.body = body.to_json
            req.options.on_data = proc do |chunk, _size, env|
              response_status ||= env&.status
              raw_body << chunk
              unless @cancel_requested || (response_status && !(200..299).cover?(response_status))
                buffer << chunk
                process_sse_buffer(buffer, assistant_text, pending_tool_calls)
              end
            end
          end

          response_status ||= response.status
          unless (200..299).cover?(response_status)
            handle_http_error(response_status, raw_body)
          end

          finalize_response(assistant_text, pending_tool_calls)
          process_pending_tool_calls(pending_tool_calls, input) if pending_tool_calls.any?
        end

        def process_sse_buffer(buffer, assistant_text, pending_tool_calls)
          while (line_end = buffer.index("\n"))
            line = buffer.slice!(0, line_end + 1).strip
            next if line.empty?

            process_sse_line(line, assistant_text, pending_tool_calls)
          end
        end

        def process_sse_line(line, assistant_text, pending_tool_calls)
          return unless line.start_with?("data: ")

          data = line[6..]
          return if data == "[DONE]"

          event = parse_json(data)
          return unless event

          dispatch_sse_event(event, assistant_text, pending_tool_calls)
        end

        def dispatch_sse_event(event, assistant_text, pending_tool_calls)
          type = event["type"]

          case type
          when "response.output_text.delta"
            handle_text_delta(event, assistant_text)
          when "response.function_call_arguments.delta"
            handle_function_args_delta(event, pending_tool_calls)
          when "response.function_call_arguments.done"
            handle_function_call_done(event, pending_tool_calls)
          when "response.output_item.added"
            handle_output_item_added(event, pending_tool_calls)
          end
        end

        def handle_text_delta(event, assistant_text)
          delta = event["delta"]
          return unless delta.is_a?(String) && !delta.empty?

          assistant_text << delta
          @state.streaming_append(delta)
        end

        def handle_output_item_added(event, pending_tool_calls)
          item = event["item"]
          return unless item && item["type"] == "function_call"

          pending_tool_calls << {
            call_id: item["call_id"] || item["id"],
            name: item["name"],
            arguments: +""
          }
        end

        def handle_function_args_delta(event, pending_tool_calls)
          delta = event["delta"]
          return unless delta.is_a?(String)

          current = pending_tool_calls.last
          current[:arguments] << delta if current
        end

        def handle_function_call_done(event, pending_tool_calls)
          call_id = event["call_id"] || event.dig("item", "call_id")
          return unless call_id

          tc = pending_tool_calls.find { |c| c[:call_id] == call_id }
          return unless tc

          args_str = event["arguments"] || tc[:arguments]
          tc[:arguments] = args_str
        end

        def finalize_response(assistant_text, _pending_tool_calls)
          return if assistant_text.empty?

          @conversation_history << { role: "assistant", content: assistant_text }
        end

        def handle_http_error(status, body_text)
          parsed = begin
                     JSON.parse(body_text)
                   rescue StandardError
                     nil
                   end

          detail = if parsed.is_a?(Hash)
                     parsed.dig("error", "message") || parsed["detail"] || parsed["message"] || body_text[0, 300]
                   else
                     body_text[0, 300]
                   end

          raise CodexAPIError.new(status, detail)
        end

        def parse_json(str)
          JSON.parse(str)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
