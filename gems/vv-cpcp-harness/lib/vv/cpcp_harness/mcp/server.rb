# frozen_string_literal: true

require "json"
require "securerandom"

module Vv
  module CpcpHarness
    module Mcp
      # Protocol dispatch for one MCP connection, transport-agnostic.
      #
      # `handle` takes a parsed JSON-RPC message and returns the response
      # to send, or nil for a notification. It never raises: a malformed
      # frame is a JSON-RPC error, and everything that happened *inside*
      # a tool is a result with `isError: true`.
      #
      # That split is the same one CPCP draws. A refused operation is
      # data the model can act on; only a frame the server could not read
      # is an error about the call itself. So `grounding_refused`,
      # `user_declined` and `harness_input_rejected` all arrive as tool
      # results, and only an unknown tool or an unparseable request
      # becomes a JSON-RPC error.
      class Server
        DEFAULT_INSTRUCTIONS =
          "Tools generated from CPCP seam contracts. A PULL reads grounded context and " \
          "promises nothing. A PUSH writes an effect and carries an operationId: to retry " \
          "the same write after an error, pass the operationId from the earlier result; " \
          "omit it for a new write. Refusals arrive as results with isError, carrying a " \
          "stable reason."

        attr_reader :bridge, :name, :version, :session_id

        def initialize(bridge:, name: nil, version: VERSION, instructions: nil,
                       session_id: nil, auth: nil)
          @bridge = bridge
          @name = name || bridge.config[:name] || "vv-cpcp-harness"
          @version = version
          @instructions = instructions || DEFAULT_INSTRUCTIONS
          # MCP has no protocol-level session, so this is the server's own
          # name for the connection — one stdio process, one id — and it
          # is what the journal records as the session.
          @session_id = session_id || SecureRandom.hex(8)
          # The client brings its own model credential and this process
          # never sees it, which is the whole point of the road.
          @auth = auth || Auth.new(mode: :client, source: "the calling MCP client",
                                   backend: "mcp")
          @client_info = nil
        end

        def handle(message)
          return error(nil, INVALID_REQUEST, "expected a JSON-RPC object") unless message.is_a?(Hash)

          id = message["id"]
          method = message["method"]
          params = message["params"].is_a?(Hash) ? message["params"] : {}
          return nil if id.nil? && method.to_s.start_with?("notifications/")
          return error(id, INVALID_REQUEST, "missing method") if method.to_s.empty?

          remember_client(params)
          version = version_problem(id, params)
          return version if version

          dispatch(id, method.to_s, params)
        rescue StandardError => e
          error(id, INTERNAL_ERROR, "#{e.class}: #{e.message}")
        end

        # The tool list, in a deterministic order, as MCP tool objects.
        def tools
          @bridge.tools.sort_by(&:name).map { |tool| describe(tool) }
        end

        private

        def dispatch(id, method, params)
          case method
          when "server/discover" then result(id, discover)
          when "initialize" then result(id, initialize_result(params))
          when "ping" then result(id, {})
          when "tools/list" then result(id, { "resultType" => "complete", "tools" => tools })
          when "tools/call" then call_tool(id, params)
          when %r{\Anotifications/} then nil
          else error(id, METHOD_NOT_FOUND, "unknown method #{method}")
          end
        end

        # Modern clients need no handshake; this answers the ones that
        # probe, and names every version so a client can pick one.
        def discover
          {
            "resultType" => "complete",
            "supportedVersions" => SUPPORTED,
            "capabilities" => capabilities,
            "instructions" => @instructions,
            "_meta" => { META_SERVER_INFO => server_info }
          }
        end

        # Legacy era. A client that opens with `initialize` is served
        # under the revision it asked for, when this server speaks it.
        def initialize_result(params)
          asked = params["protocolVersion"].to_s
          spoken = LEGACY.include?(asked) ? asked : LEGACY.first
          @client_info = params["clientInfo"] if params["clientInfo"].is_a?(Hash)

          {
            "protocolVersion" => spoken,
            "capabilities" => capabilities,
            "serverInfo" => server_info,
            "instructions" => @instructions
          }
        end

        def capabilities
          # No `listChanged`: the registry is built from committed CID
          # snapshots and does not change under a running connection.
          { "tools" => { "listChanged" => false } }
        end

        def server_info
          { "name" => @name, "version" => @version }
        end

        def call_tool(id, params)
          name = params["name"].to_s
          tool = @bridge.tool(name)
          # MCP puts an unknown tool on the protocol side, not in the
          # result: it is not something the model can fix by adjusting
          # arguments.
          return error(id, INVALID_PARAMS, "Unknown tool: #{name}") if tool.nil?

          arguments = params["arguments"]
          unless arguments.nil? || arguments.is_a?(Hash)
            return error(id, INVALID_PARAMS, "arguments must be an object")
          end

          rendered = @bridge.execute(name, arguments || {}, context: context_for(id))
          result(id, Render.mcp(rendered))
        end

        # What the journal will record about this call. The model and the
        # account behind it belong to the client, and this server does not
        # learn either, so it records what it does know and claims no
        # more.
        def context_for(rpc_id)
          Context.new(
            session_id: @session_id,
            backend: "mcp:#{client_name}",
            agent: client_name,
            rpc_id: rpc_id.to_s,
            auth_mode: @auth
          )
        end

        def client_name
          name = @client_info.is_a?(Hash) ? @client_info["name"] : nil
          name.to_s.empty? ? "unknown-client" : name.to_s
        end

        def remember_client(params)
          info = params.dig("_meta", META_CLIENT_INFO)
          @client_info = info if info.is_a?(Hash)
        end

        # Modern requests declare their version on every call. An unknown
        # one is refused with the list this server does speak, which is
        # how a modern client finds common ground.
        def version_problem(id, params)
          asked = params.dig("_meta", META_PROTOCOL_VERSION)
          return nil if asked.nil? || SUPPORTED.include?(asked.to_s)

          {
            "jsonrpc" => "2.0",
            "id" => id,
            "error" => {
              "code" => UNSUPPORTED_PROTOCOL_VERSION,
              "message" => "Unsupported protocol version",
              "data" => { "supported" => SUPPORTED, "requested" => asked.to_s }
            }
          }
        end

        # One tool, as MCP describes tools. The face becomes hints the
        # client's own prompt can read; the IRI travels in `_meta`, where
        # linked data survives, rather than in text aimed at the model.
        def describe(tool)
          {
            "name" => tool.name,
            "title" => tool.method_name || tool.name,
            "description" => tool.description,
            "inputSchema" => input_schema(tool),
            "annotations" => {
              "readOnlyHint" => tool.pull?,
              # A PUSH may be additive rather than destructive, but
              # over-declaring is the direction that prompts a human.
              "destructiveHint" => tool.push?,
              # Repeats are idempotent only under the same operationId,
              # which the model may not pass. Claiming otherwise would be
              # a safety promise this road cannot keep.
              "idempotentHint" => false,
              "openWorldHint" => !tool.native?
            },
            "_meta" => tool_meta(tool)
          }.reject { |_, v| v.nil? }
        end

        def input_schema(tool)
          schema = tool.schema.json_schema
          return schema unless schema["properties"].nil? || schema["properties"].empty?

          # A tool with no parameters says so explicitly.
          { "type" => "object", "additionalProperties" => false }
        end

        def tool_meta(tool)
          meta = {
            "#{META_PREFIX}iri" => tool.iri,
            "#{META_PREFIX}face" => tool.face&.to_s,
            "#{META_PREFIX}seam" => tool.seam
          }
          cid = tool.cpcp&.cid
          meta["#{META_PREFIX}cidDigest"] = cid["digest"] if cid.is_a?(Hash) && cid["digest"]
          meta = meta.reject { |_, v| v.nil? }
          meta.empty? ? nil : meta
        end

        def result(id, payload)
          { "jsonrpc" => "2.0", "id" => id, "result" => payload }
        end

        def error(id, code, message, data = nil)
          body = { "code" => code, "message" => message }
          body["data"] = data unless data.nil?
          { "jsonrpc" => "2.0", "id" => id, "error" => body }
        end
      end
    end
  end
end
