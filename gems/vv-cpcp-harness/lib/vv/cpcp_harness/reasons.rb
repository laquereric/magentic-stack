# frozen_string_literal: true

module Vv
  module CpcpHarness
    # The refusal vocabulary, split the way the contract splits it.
    #
    # A *seam* reason is decided by the method: it ran, or it would have.
    # A *binding* reason is decided by the road, on a call that never
    # reached a dispatcher. The harness adds one road — model to tool,
    # in-process — and so defines a binding, listed here and declared in
    # the repo manifest (`Manifest`).
    #
    # Reason strings are stable. Renaming one is a breaking change.
    module Reasons
      LAYERS = %i[domain http_auth http_request infrastructure owner].freeze

      # spec/refusals.md — universal
      UNIVERSAL = %i[empty_body unparseable_json unknown_operation].freeze

      # spec/refusals.md — admission and grounding (BACK)
      ADMISSION = %i[
        grounding_refused authorization_denied operation_id_required missing_params
      ].freeze

      # spec/refusals.md — durability and stores
      DURABILITY = %i[
        idempotency_not_durable idempotency_store_unavailable
        outbox_not_installed outbox_schema_check_failed
        graph_unreachable sqlite_busy domain_write_refused
      ].freeze

      # spec/refusals.md — per-seam vocabularies. Carried so a grounded
      # native tool cannot quietly invent a reason that looks like one of
      # these, and so a refusal relayed from one of these seams keeps its
      # own name.
      VAULT = %i[
        vault_callers_missing vault_callers_unparseable vault_callers_token_missing
        vault_secret_absent unauthenticated forbidden
      ].freeze

      PERSIST = %i[
        unknown_store unknown_path persist_unauthenticated persist_forbidden persist_callers_missing
      ].freeze

      MIND = %i[
        mind_unauthenticated mind_forbidden mind_callers_missing mind_callers_unparseable
        mind_callers_token_missing mind_callers_token_collision mind_callers_unknown_operation
        invalid_request mind_queue_full
      ].freeze

      SWITCH = %i[
        missing_credential unknown_model local_not_configured pin_unavailable
        browser_origin_rejected invalid_json not_found server_error no_pin
        target_required vendor_required provider_http
      ].freeze

      CATALOG = %i[shape_catalog_empty shape_id_unresolved].freeze

      SEAM = (UNIVERSAL + ADMISSION + DURABILITY + VAULT + PERSIST + MIND + SWITCH + CATALOG).freeze

      # Reasons other bindings decide. The harness does not raise these,
      # but it must not treat one as unregistered either.
      OTHER_BINDINGS = %i[
        a2a_unknown_method a2a_unsupported_part a2a_json_not_jsonld
        nats_unreachable origin_not_exposed page_state_changed
      ].freeze

      # The harness binding (design §8). No HTTP status: for Direction B
      # there is no exchange, and for Direction A these are raised by the
      # caller, not carried by the seam.
      BINDING = {
        harness_input_rejected: {
          layer: :http_request,
          meaning: "tool arguments failed the local schema; nothing was sent"
        },
        seam_unreachable: {
          layer: :infrastructure,
          meaning: "no response from the seam: connection failure, DNS, TLS, or timeout after retries"
        },
        seam_body_unparseable: {
          layer: :infrastructure,
          meaning: "the seam answered, but the body was not a JSON envelope"
        },
        contract_superseded: {
          layer: :infrastructure,
          meaning: "the live CID's digest or contract version differs from the pinned snapshot"
        },
        user_declined: {
          layer: :domain,
          meaning: "the human refused the approval the harness asked for"
        },
        harness_timeout: {
          layer: :infrastructure,
          meaning: "a native tool exceeded its timeout"
        },
        # Not in design §8's table. §7 says a grounded native tool's
        # unrecognized reason is "replaced with a generic reason and
        # logged", and §8 names no generic, so the binding defines one.
        # It also carries a handler that raised, with the layer set to
        # infrastructure at the call site.
        harness_tool_refused: {
          layer: :domain,
          meaning: "a native tool refused, with a reason outside the contract's taxonomy or the tool raised"
        },
        # Also not in §8's table; it comes from §10.1's rule that a shared
        # or scheduled run fails closed without an API key or a cloud
        # credential. The deciding authority is the deployment's policy,
        # which makes it a domain decision like `user_declined`.
        auth_mode_not_permitted: {
          layer: :domain,
          meaning: "the backend's credential kind is not permitted for this run"
        }
      }.freeze

      # Build-time reasons. These never reach a model: they are answers to
      # `sync`, `describe` and `manifest`, not to a tool call.
      BUILD = {
        cid_unreadable: "the CID snapshot could not be read as JSON",
        cid_face_conflict: "the CID's kind and an operation's operationId disagree on the face",
        operation_not_published: "an included operation is not in the CID's manifest",
        seam_unknown: "no seam by that name is configured",
        tool_definition_invalid: "a tool definition broke one of the rules a grounded tool must keep",
        tool_name_taken: "two tools claim the same name",
        iri_taken: "two tools claim the same operation IRI",
        unknown_tool: "no tool by that name is registered",
        snapshot_digest_mismatch: "the snapshot's bytes do not match the pinned digest"
      }.freeze

      module_function

      def binding?(reason)
        BINDING.key?(reason.to_s.to_sym)
      end

      def seam?(reason)
        SEAM.include?(reason.to_s.to_sym)
      end

      # A reason a grounded native tool is allowed to use (design §7):
      # the contract's taxonomy or this binding's list. Anything else is
      # replaced by the caller with a generic reason and logged.
      def allowed?(reason)
        return false if reason.nil?

        seam?(reason) || binding?(reason) || OTHER_BINDINGS.include?(reason.to_s.to_sym)
      end

      # `failure_layer` rides beside `reason` everywhere. For binding
      # reasons the layer is fixed by the table above; for seam reasons
      # the seam states it, and the harness does not guess.
      def layer_for(reason)
        BINDING.dig(reason.to_s.to_sym, :layer)
      end
    end
  end
end
