# frozen_string_literal: true

module RailsOsiLevel8
  # Grounding = closed-shape validation + profile evidence.
  # Deviation (M1): mm-shacl-reader is not wired in-process here (Rust/Ruby facade lives in
  # magentic-market-ai). We apply a minimal closed-shape check keyed by profile catalog entry,
  # returning the same Result contract so SHACL can replace MmShaclValidator later.
  module Grounding
    Result = Data.define(:conforms?, :profile_id, :shape_id, :shape_digest, :violations) do
      def safe_report
        {
          "profile_id" => profile_id,
          "shape_id" => shape_id,
          "shape_digest" => shape_digest,
          "violations" => violations.first(20).map { |v|
            {
              "focus_node" => v[:focus_node] || v["focus_node"],
              "path" => v[:path] || v["path"],
              "constraint" => v[:constraint] || v["constraint"],
              "message" => v[:message] || v["message"]
            }
          }
        }
      end
    end

    module_function

    def validate(graph, profile:)
      entry = RailsOsiLevel8.config.profile_catalog&.[](profile) ||
              RailsOsiLevel8.config.profile_catalog&.fetch(profile)
      graph = stringify_keys(graph || {})
      violations = closed_shape_violations(graph, profile)
      Result.new(
        violations.empty?,
        entry&.id || profile.to_s,
        entry&.shape_iri || profile.to_s,
        entry&.sha256 || "unsigned",
        violations
      )
    rescue KeyError
      Result.new(
        false,
        profile.to_s,
        profile.to_s,
        "unknown",
        [{ focus_node: nil, path: nil, constraint: "catalog", message: "unknown profile shape #{profile}" }]
      )
    end

    def closed_shape_violations(graph, profile)
      case profile.to_s
      when "P1::NoteCreateEffectShape", "P4::NoteCreateEffectShape"
        req = []
        req << violation(graph, "cpcp:idempotencyKey", "must have at least one idempotency key") if blank?(graph["idempotencyKey"] || graph["operationId"])
        req << violation(graph, "title", "must have a title") if blank?(graph["title"])
        # Closed-ish: refuse explicit private_local placement from client
        if graph.key?("ledgerPlacement") || graph.key?("ledger_placement")
          req << violation(graph, "ledgerPlacement", "client must not supply ledger placement")
        end
        req
      when "P1::NoteListPullShape"
        [] # PULL request params are optional filters
      when "P1::NoteCreateContextShape", "P1::NoteListContextShape", "P4::DurableReceiptShape"
        []

      # --- session cycle (see osi-level-8-profiles/profile-1-cyborg-channel/
      #     shapes/session-operations.shacl.ttl, mirrored at
      #     data/osi-level-8/session-operations.shacl.ttl).
      #
      # These reproduce the SHACL constraints in Ruby because the TTL is NOT
      # executed in-process -- see the module comment: mm-shacl-reader is not
      # wired here. The shapes are the specification and CI runs pyshacl over
      # them with fixtures; THIS is what actually refuses a live request, so the
      # two must say the same thing. A shape whose runtime twin is missing is
      # gating that validates nothing.
      when "P1::SessionOpenEffectShape"
        v = []
        v << violation(graph, "cpcp:idempotencyKey", "a PUSH must name its intent before performing it") if blank?(graph["idempotencyKey"] || graph["operationId"])
        kind = graph["actor_kind"]
        v << violation(graph, "actor_kind", "actor_kind is human or agent") if !blank?(kind) && !%w[human agent].include?(kind.to_s)
        v << violation(graph, "session_iri", "the session graph name is derived from the key, never supplied") if graph.key?("session_iri")
        v << violation(graph, "actor_proven", "actor_proven is answered by BACK, not claimed by the caller") if graph.key?("actor_proven")
        v

      when "P1::SessionContextPullShape"
        v = []
        v << violation(graph, "session_id", "a context read must name the session it is scoped to") if blank?(graph["session_id"])
        limit = graph["limit"]
        unless blank?(limit)
          n = Integer(limit, exception: false)
          v << violation(graph, "limit", "limit is 1..200") if n.nil? || n < 1 || n > 200
        end
        v << violation(graph, "sparql", "the caller does not supply the query; BACK scopes it") if graph.key?("sparql")
        v

      when "P1::SessionObserveEffectShape"
        v = []
        v << violation(graph, "cpcp:idempotencyKey", "a PUSH must name its intent before performing it") if blank?(graph["idempotencyKey"] || graph["operationId"])
        v << violation(graph, "session_id", "an observation must say which session it is about") if blank?(graph["session_id"])
        v << violation(graph, "title", "an observation needs a title") if blank?(graph["title"].to_s.strip)
        v << violation(graph, "status", "status is stamped by BACK; a proposal does not accept itself") if graph.key?("status")
        v << violation(graph, "groundedIn", "groundedIn is stamped by BACK from the session it read") if graph.key?("groundedIn") || graph.key?("grounded_in")
        v

      when "P1::SessionCloseEffectShape"
        v = []
        v << violation(graph, "cpcp:idempotencyKey", "a PUSH must name its intent before performing it") if blank?(graph["idempotencyKey"] || graph["operationId"])
        v << violation(graph, "session_id", "close must name the session it seals") if blank?(graph["session_id"])
        v

      when "P1::SessionLatestPullShape"
        graph.key?("session_id") ? [violation(graph, "session_id", "latest takes no session; asking for a specific one is session.context")] : []

      when "P1::SessionOpenContextShape", "P1::SessionContextContextShape",
           "P1::SessionObserveContextShape", "P1::SessionCloseContextShape",
           "P1::SessionLatestContextShape"
        []

      else
        # FAIL CLOSED ON AN UNIMPLEMENTED SHAPE.
        #
        # This returned [] -- so an operation wrapped with a shape name that had
        # no case here validated CLEAN, every time, and looked gated. Registering
        # a name in the catalog was enough to appear governed while nothing was
        # checked. A refusal that has never fired is indistinguishable from one
        # that cannot.
        #
        # Every shape the adapter currently uses is named above; anything else is
        # a wiring mistake and says so instead of passing.
        [violation(graph, "shape",
                   "no runtime closed-shape check is implemented for #{profile}; refusing rather " \
                   "than validating nothing. Add a case in Grounding or stop wrapping the operation")]
      end
    end
    private_class_method :closed_shape_violations

    def violation(graph, path, message)
      {
        focus_node: graph["@id"] || graph["cid"],
        path: path,
        constraint: "MinCountConstraintComponent",
        message: message
      }
    end
    private_class_method :violation

    def blank?(v)
      v.nil? || (v.respond_to?(:empty?) && v.empty?)
    end
    private_class_method :blank?

    def stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
      when Array
        obj.map { |v| stringify_keys(v) }
      else
        obj
      end
    end
    private_class_method :stringify_keys
  end
end
