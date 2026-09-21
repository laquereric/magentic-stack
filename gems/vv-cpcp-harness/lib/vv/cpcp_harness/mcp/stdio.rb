# frozen_string_literal: true

require "json"

module Vv
  module CpcpHarness
    module Mcp
      # The stdio transport: one JSON-RPC message per line on stdin, one
      # per line on stdout, and nothing else on stdout ever. Diagnostics
      # go to stderr, because a stray `puts` in this process is a parse
      # error in the client's.
      class Stdio
        def initialize(server:, input: $stdin, output: $stdout, log: $stderr)
          @server = server
          @input = input
          @output = output
          @log = log
        end

        # Reads until end of input. Returns the number of messages
        # handled. Never raises: a bad line is answered and the loop
        # continues, because a client that sent one malformed frame is
        # still a client.
        def run
          handled = 0
          while (line = @input.gets)
            next if line.strip.empty?

            handled += 1
            response = respond(line)
            write(response) unless response.nil?
          end
          handled
        end

        # One line in, one response hash out (or nil for a notification).
        def respond(line)
          message = JSON.parse(line)
          if message.is_a?(Array)
            # Batching is not part of MCP; a batch is not a frame this
            # server can answer, and silently taking the first would be
            # worse than saying so.
            return jsonrpc_error(nil, INVALID_REQUEST, "batched requests are not supported")
          end

          @server.handle(message)
        rescue JSON::ParserError => e
          @log&.puts("vv-cpcp-harness-mcp: #{e.class}: #{e.message}")
          jsonrpc_error(nil, PARSE_ERROR, "invalid JSON")
        end

        private

        def write(response)
          @output.puts(JSON.generate(response))
          @output.flush
        end

        def jsonrpc_error(id, code, message)
          { "jsonrpc" => "2.0", "id" => id, "error" => { "code" => code, "message" => message } }
        end
      end
    end
  end
end
