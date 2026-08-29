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
      # note.create -- PUSH, exactly one note back.
      # Live since push! learned to validate its response; before that this
      # branch returned [] and the TTL said so out loud.
      when "P1::NoteCreateContextShape"
        item = response_item(graph)
        v = []
        v << violation(graph, "items", "a create response carries exactly one note") if item.nil?
        if item
          v << violation(graph, "id", "the created note must report its id") if blank?(item["id"])
          # Note validates title presence, so a response without one means BACK
          # returned something it did not store.
          v << violation(graph, "title", "the created note must report the title it was stored with") if blank?(item["title"])
        end
        v

      # note.list -- PULL with result: :collection, so items holds N notes.
      # ZERO IS A VALID ANSWER: an empty list is what "no notes yet" looks like,
      # and requiring at least one would refuse a correct response.
      when "P1::NoteListContextShape"
        items = response_items(graph)
        v = []
        v << violation(graph, "id", "a list response must carry a list; nothing else can report per-note ids") if items.nil?
        Array(items).each_with_index do |n, i|
          v << violation(graph, "id", "every listed note must report its id (item #{i})") if !n.is_a?(Hash) || blank?(n["id"])
        end
        v

      # UNBOUND. P4::DurableReceiptShape is in the profile catalog and named by no
      # operation -- the binding manifest classifies it `unowned`. It stays a
      # no-op because there is no response to constrain, not because the contract
      # is empty. If something ever wraps it, this branch is the thing to fill in.
      when "P4::DurableReceiptShape"
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

      # RESPONSE shapes. pull! validates { "@id", "items" => [result] }, so the
      # payload is nested one level down. A check written against the top level
      # would read nothing and pass.
      when "P1::SessionContextContextShape"
        item = response_item(graph)
        next_violations = []
        next_violations << violation(graph, "items", "a context response must carry one item") if item.nil?
        if item
          next_violations << violation(graph, "generation", "a context read must report the generation it read") if blank?(item["generation"])
          next_violations << violation(graph, "session_iri", "a context read must name the session it was scoped to") if blank?(item["session_iri"])
          next_violations << violation(graph, "state", "state is open or closed") unless %w[open closed].include?(item["state"].to_s)
        end
        next_violations

      when "P1::SessionLatestContextShape"
        item = response_item(graph)
        next_violations = []
        next_violations << violation(graph, "items", "a latest response must carry one item") if item.nil?
        if item
          next_violations << violation(graph, "session_iri", "latest must name the session it found") if blank?(item["session_iri"])
          next_violations << violation(graph, "generation", "latest must report the generation, so a reading can quote it") if blank?(item["generation"])
          next_violations << violation(graph, "actor_kind", "actor_kind is human or agent") unless %w[human agent].include?(item["actor_kind"].to_s)
          next_violations << violation(graph, "state", "state is open or closed") unless %w[open closed].include?(item["state"].to_s)
        end
        next_violations

      # RESPONSE shapes for the PUSH operations. These became reachable when
      # push! learned to validate its response; before that they were wired,
      # catalogued and never consulted, because CpcpAdapter used
      # @response_shape only inside pull!.
      when "P1::SessionOpenContextShape"
        item = response_item(graph)
        v = []
        v << violation(graph, "items", "a response document carries exactly one item") if item.nil?
        if item
          v << violation(graph, "session_iri", "open must return the session graph name it minted") if blank?(item["session_iri"])
          v << violation(graph, "generation", "open must report the opening generation") if blank?(item["generation"])
          v << violation(graph, "actor_proven", "actor_proven is false: the pod has no authentication") unless item["actor_proven"] == false
        end
        v

      when "P1::SessionObserveContextShape"
        item = response_item(graph)
        v = []
        v << violation(graph, "items", "a response document carries exactly one item") if item.nil?
        if item
          v << violation(graph, "subject", "observe must return the observation IRI it minted") if blank?(item["subject"])
          v << violation(graph, "generation", "observe must report the generation after the bump") if blank?(item["generation"])
        end
        v

      when "P1::SessionCloseContextShape"
        item = response_item(graph)
        v = []
        v << violation(graph, "items", "a response document carries exactly one item") if item.nil?
        if item
          v << violation(graph, "state", "a close that does not report state closed did not close") unless item["state"].to_s == "closed"
          v << violation(graph, "closed_at", "close must report when it sealed the session") if blank?(item["closed_at"])
        end
        v

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

    # The one item out of a pull! response document, or nil.
    # pull! validates { "@id" => cid, "items" => [result] }; anything that is not
    # exactly one Hash item is not a response this shape can speak about, and the
    # caller turns nil into a violation rather than skipping the check.
    def response_item(graph)
      items = graph["items"]
      return nil unless items.is_a?(Array) && items.length == 1
      items.first.is_a?(Hash) ? items.first : nil
    end
    private_class_method :response_item

    # The item LIST out of a pull!/push! response document, or nil.
    # Distinct from response_item: a `result: :collection` operation returns N
    # items and ZERO is a valid answer, so this does not require exactly one.
    def response_items(graph)
      items = graph["items"]
      items.is_a?(Array) ? items : nil
    end
    private_class_method :response_items

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
