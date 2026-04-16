# frozen_string_literal: true

module RubyCoded
  module Chat
    class CodexBridge
      # Handles tool call execution, confirmation, and the multi-turn loop
      # for agentic mode over the Codex Responses API.
      module ToolHandling
        private

        def process_pending_tool_calls(pending_tool_calls, original_input)
          pending_tool_calls.each do |tc|
            break if @cancel_requested

            execute_tool_call(tc)
          end

          return if @cancel_requested

          @state.add_message(:assistant, "")
          continue_after_tools
        end

        def execute_tool_call(tc)
          name = tc[:name]
          args = parse_tool_arguments(tc[:arguments])
          display_name = short_tool_name(name)
          risk = @tool_registry.risk_level_for(name)

          increment_call_counts(risk)
          check_tool_limits!
          warn_approaching_limit

          request_approval(tc, display_name, args, risk)
          result = run_tool(name, args)
          record_tool_result(tc, result)
        end

        def parse_tool_arguments(args_str)
          return args_str if args_str.is_a?(Hash)

          JSON.parse(args_str)
        rescue JSON::ParserError
          {}
        end

        def request_approval(tc, display_name, args, risk)
          args_summary = args.map { |k, v| "#{k}: #{v}" }.join(", ")

          if risk == Tools::BaseTool::SAFE_RISK || @state.auto_approve_tools?
            @state.add_message(:tool_call, "[#{display_name}] #{args_summary}")
          else
            risk_label = risk == Tools::BaseTool::DANGEROUS_RISK ? "DANGEROUS" : "WRITE"
            @state.request_tool_confirmation!(display_name, args, risk_label: risk_label)
            decision = poll_tool_decision
            apply_tool_decision(decision, display_name)
          end
        end

        def poll_tool_decision
          @state.mutex.synchronize do
            loop do
              return :cancelled if @cancel_requested

              case @state.instance_variable_get(:@tool_confirmation_response)
              when :approved then return :approved
              when :rejected then return :rejected
              end

              @state.tool_cv.wait(@state.mutex, 0.1)
            end
          end
        end

        def apply_tool_decision(decision, display_name)
          case decision
          when :cancelled
            @state.clear_tool_confirmation!
            raise Tools::AgentCancelledError, "Operation cancelled by user"
          when :approved
            @state.resolve_tool_confirmation!(:approved)
          when :rejected
            @state.resolve_tool_confirmation!(:rejected)
            raise Tools::ToolRejectedError, "User rejected #{display_name}"
          end
        end

        def run_tool(name, args)
          tool_instances = @agentic_mode ? @tool_registry.build_tools : @tool_registry.build_readonly_tools
          tool = tool_instances.find { |t| tool_name_match?(t, name) }

          unless tool
            return { error: "Unknown tool: #{name}" }
          end

          symbolized = args.transform_keys(&:to_sym)
          tool.execute(**symbolized)
        rescue StandardError => e
          { error: e.message }
        end

        def tool_name_match?(tool, name)
          tool.name == name || tool.name.split("--").last == name.split("--").last
        end

        def record_tool_result(tc, result)
          text = result.to_s
          if text.length > MAX_TOOL_RESULT_CHARS
            text = "#{text[0, MAX_TOOL_RESULT_CHARS]}\n... (truncated, #{text.length} total characters)"
          end
          @state.add_message(:tool_result, text)

          @conversation_history << {
            type: "function_call",
            call_id: tc[:call_id],
            name: tc[:name],
            arguments: tc[:arguments]
          }
          @conversation_history << {
            type: "function_call_output",
            call_id: tc[:call_id],
            output: result.to_s
          }
        end

        def continue_after_tools
          perform_codex_request(nil)
        end

        def increment_call_counts(risk)
          @tool_call_count += 1
          @write_tool_call_count += 1 unless risk == Tools::BaseTool::SAFE_RISK
        end

        def check_tool_limits!
          if @write_tool_call_count >= MAX_WRITE_TOOL_ROUNDS
            @write_tool_call_count = 0
            @state.add_message(:system,
                               "Write tool call budget (#{MAX_WRITE_TOOL_ROUNDS}) reached — auto-resetting counter.")
          end

          return unless @tool_call_count > MAX_TOTAL_TOOL_ROUNDS

          raise Tools::AgentIterationLimitError,
                "Reached maximum of #{MAX_TOTAL_TOOL_ROUNDS} total tool calls. " \
                "Send a new message to continue, or use /agent on to reset counters."
        end

        def warn_approaching_limit
          warning_at = (MAX_TOTAL_TOOL_ROUNDS * TOOL_ROUNDS_WARNING_THRESHOLD).to_i
          return unless @tool_call_count == warning_at

          remaining = MAX_TOTAL_TOOL_ROUNDS - @tool_call_count
          @state.add_message(:system,
                             "Approaching total tool call limit: #{remaining} calls remaining. " \
                             "Prioritize completing the most important work.")
        end

        def short_tool_name(name)
          name.split("--").last
        end
      end
    end
  end
end
