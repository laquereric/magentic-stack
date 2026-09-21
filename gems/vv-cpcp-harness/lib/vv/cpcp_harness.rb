# frozen_string_literal: true

require_relative "cpcp_harness/version"
require_relative "cpcp_harness/reasons"
require_relative "cpcp_harness/envelope"
require_relative "cpcp_harness/operation_id"
require_relative "cpcp_harness/transport"
require_relative "cpcp_harness/retry_policy"
require_relative "cpcp_harness/cid"
require_relative "cpcp_harness/shacl"
require_relative "cpcp_harness/schema"
require_relative "cpcp_harness/tool"
require_relative "cpcp_harness/auth"
require_relative "cpcp_harness/client"
require_relative "cpcp_harness/config"
require_relative "cpcp_harness/generator"
require_relative "cpcp_harness/permissions"
require_relative "cpcp_harness/journal"
require_relative "cpcp_harness/receipts"
require_relative "cpcp_harness/render"
require_relative "cpcp_harness/registry"
require_relative "cpcp_harness/manifest"
require_relative "cpcp_harness/bridge"
require_relative "cpcp_harness/mcp"
require_relative "cpcp_harness/mcp/server"
require_relative "cpcp_harness/mcp/stdio"

module Vv
  # The bridge between an agent harness and CPCP — the contract a
  # deterministic system uses to grant a non-deterministic one (an agent)
  # read and write access on stated terms.
  #
  # It works in both directions.
  #
  #   Direction A  a seam's published operations become tools
  #   Direction B  native tools adopt CPCP identity, faces and envelopes
  #
  # The harness is a FRONT: it calls seams and serves none.
  #
  #   bridge = Vv::CpcpHarness.bridge(
  #     seams: [{
  #       name: "back",
  #       endpoint: "https://back.example/_cpcp",
  #       cid_snapshot: "cpcp/cids/back.cid.json",
  #       contract_version: 3,
  #       credential: Vv::CpcpHarness.env("CPCP_BACK_TOKEN"),
  #       status_profile: "dual-v1",
  #       include: %w[note.list note.create]
  #     }]
  #   )[:result]
  #
  #   bridge.execute("back_note_create", { "title" => "hello", "body" => "…" })
  #
  # Never raises across the boundary: a dropped connection, a refused
  # grounding and a declined approval all arrive as the same shape.
  module CpcpHarness
    FACES = %i[pull push].freeze

    module_function

    # Build a bridge from a seam list. Returns an envelope: the bridge on
    # `:result`, or a build-time refusal naming what did not line up.
    def bridge(seams: [], transport_factory: nil, clock: nil, sleeper: nil, **options)
      config = Config.build(seams: seams, **options)
      return config unless config[:ok]

      Bridge.build(config[:result], transport_factory: transport_factory,
                                    clock: clock, sleeper: sleeper)
    end

    # A seam credential read at call time. Never a tool input, never in a
    # description, never in a result, never in the journal. It knows its
    # own source so a preflight can report where a call's authority came
    # from without reporting the credential.
    def env(name, default = nil)
      Credential.new(source: "env:#{name}") { ENV.fetch(name.to_s, default) }
    end

    # Direction B: ground a native tool in CPCP without serving a seam.
    def define_tool(name:, description: "", schema: nil, cpcp: nil, read_only: nil,
                    timeout: nil, &handler)
      Tool.define(name: name, description: description, schema: schema, cpcp: cpcp,
                  read_only: read_only, timeout: timeout, &handler)
    end

    # The canonical IRI for one of this harness's own operations.
    def iri(seam, method)
      "https://w3id.org/cpcp/osi8/#{seam}##{method}"
    end
  end
end
