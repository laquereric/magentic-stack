# frozen_string_literal: true

module Vv
  module CpcpHarness
    # The MCP road: a second way from a model to these tools, for when
    # the in-process one is closed.
    #
    # Doc 1's adapters put tools in an agent's own process, which needs a
    # backend the harness can start — and a credential the harness would
    # then be near. When that path is not available (the Agent SDK's
    # credential rules, a backend that cannot speak Claude, a client that
    # is simply someone else's), the same registry can be served over MCP
    # instead. The client brings its own model and its own credential;
    # this process holds neither.
    #
    # In CPCP terms nothing about the role changes. An MCP server is not
    # a seam: it serves no `/_cpcp/rpc`, publishes no CID as an endpoint
    # and claims no authority over domain state. It is a road, like
    # webmcpld's page-to-agent road, and the harness stays a FRONT.
    module Mcp
      # Revision `2026-07-28` and later are "modern": stateless, with the
      # protocol version, client identity and capabilities carried in
      # `_meta` on every request. `2025-11-25` and earlier are "legacy":
      # an `initialize` handshake opens a session. This server is
      # dual-era, because the clients in the field are both.
      MODERN = "2026-07-28"
      LEGACY = %w[2025-11-25 2025-06-18 2025-03-26 2024-11-05].freeze
      SUPPORTED = [MODERN, *LEGACY].freeze

      META_PROTOCOL_VERSION = "io.modelcontextprotocol/protocolVersion"
      META_CLIENT_INFO = "io.modelcontextprotocol/clientInfo"
      META_CLIENT_CAPABILITIES = "io.modelcontextprotocol/clientCapabilities"
      META_SERVER_INFO = "io.modelcontextprotocol/serverInfo"

      # `_meta` keys carry a reverse-DNS prefix, so CPCP identity travels
      # under one this project owns.
      META_PREFIX = "ai.magenticmarket.cpcp/"

      # JSON-RPC codes. The first four are the standard ones; the last is
      # MCP's, for a protocol version this server does not speak.
      PARSE_ERROR = -32_700
      INVALID_REQUEST = -32_600
      METHOD_NOT_FOUND = -32_601
      INVALID_PARAMS = -32_602
      INTERNAL_ERROR = -32_603
      UNSUPPORTED_PROTOCOL_VERSION = -32_022

      module_function

      # Defer the human's decision to the client that is actually showing
      # them the prompt.
      #
      #   Vv::CpcpHarness.bridge(..., approver: Vv::CpcpHarness::Mcp.client_approval)
      #
      # Use it only with a client that prompts — Claude Code and most MCP
      # hosts do, and the specification tells them to. It is opt-in
      # because the alternative would be a server that quietly approves
      # its own writes, and because what gets journaled here is the
      # client's word, not a human's: `approvedBy` reads `client:<name>`
      # so a reader can tell the difference.
      def client_approval
        lambda do |request|
          backend = request[:backend].to_s
          next false unless backend.start_with?("mcp:")

          { approved: true, by: backend.sub("mcp:", "client:") }
        end
      end
    end
  end
end
