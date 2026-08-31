# frozen_string_literal: true

module RailsOsiLevel8
  # Semantic adapter atop rails-cpcp. Wraps declared CPCP operations so Context/Effect
  # semantics are interpreted in the Level 8 grammar WITHOUT a new endpoint family.
  #
  # Compatible with rails-cpcp's `via:` keyword: wrap returns a proc of |params, ctx|.
  class CpcpAdapter
    def self.wrap(operation:, direction:, profiles:, request_shape:, response_shape:, &handler)
      new(
        operation: operation,
        direction: direction,
        profiles: profiles,
        request_shape: request_shape,
        response_shape: response_shape,
        handler: handler
      ).to_proc
    end

    # Patch Dispatcher so KnownRefusal becomes a structured never-raise wire envelope
    # (because rails-cpcp's rescue => e would otherwise flatten it to handler_error).
    def self.install!(_rails_cpcp = nil)
      return if @installed
      return unless defined?(::RailsCpcp::Dispatcher)

      ::RailsCpcp::Dispatcher.singleton_class.prepend(DispatcherPatch)
      @installed = true
    end

    module DispatcherPatch
      def call(request, ctx: nil, idempotency: RailsCpcp.idempotency_store)
        # rails-cpcp keeps operationId on the envelope; Level 8 grounding expects it
        # (or idempotencyKey) inside params. Merge without inventing a second seam.
        params = (request["params"] || {}).dup
        opid = (request["operationId"] || params["operationId"]).to_s
        unless opid.empty?
          params["operationId"] ||= opid
          params["idempotencyKey"] ||= opid
          request = request.merge("params" => params)
        end
        super
      rescue RailsOsiLevel8::KnownRefusal => e
        {
          "jsonrpc" => "2.0",
          "@context" => RailsCpcp::Envelope.context,
          "id" => request["id"],
          "ok" => false,
          "error" => {
            "reason" => e.reason,
            "because" => e.because.merge("request_cid" => e.because["request_cid"]).compact
          }
        }
      end
    end

    def initialize(operation:, direction:, profiles:, request_shape:, response_shape:, handler:)
      @operation = operation
      @direction = direction.to_sym
      @profiles = Array(profiles)
      @request_shape = request_shape
      @response_shape = response_shape
      @handler = handler
    end

    def to_proc
      adapter = self
      ->(params, ctx) { adapter.call(params, ctx) }
    end

    def call(params, ctx)
      params = stringify(params || {})
      request_cid = derive_request_cid(params)
      graph = params.merge(
        "@id" => request_cid,
        "operationId" => params["operationId"],
        "idempotencyKey" => params["idempotencyKey"] || params["operationId"]
      )

      inbound = Grounding.validate(graph, profile: @request_shape)
      unless inbound.conforms?
        record_refusal!(params, request_cid, inbound) if @direction == :push
        raise KnownRefusal.new("grounding_refused", inbound.safe_report.merge(
          "request_cid" => request_cid,
          "profile_ids" => @profiles
        ))
      end

      if @direction == :push
        push!(params, ctx, request_cid, inbound)
      else
        pull!(params, ctx, request_cid)
      end
    rescue KnownRefusal
      raise
    rescue StandardError => e
      warn_log(e, request_cid)
      raise KnownRefusal.new("processing_failed", { "operation" => @operation, "request_cid" => request_cid })
    end

    private

    def push!(params, ctx, request_cid, inbound)
      scope = params["idempotencyScope"] || "default"
      key = params["idempotencyKey"] || params["operationId"].to_s
      raise KnownRefusal.new("operation_id_required", { "request_cid" => request_cid }) if key.empty?

      if (prior = find_prior_request(@operation, scope, key))
        receipt = prior.receipt
        append_journal!(prior, "completed", { "replay" => true, "receipt_cid" => receipt.cid }) if receipt
        return succeed_item(params, replay_payload(prior, receipt), request_cid, receipt, replay: true)
      end

      # No single outer transaction: P6 deny evidence must survive the refusal.
      record_admission!(params, request_cid, inbound, conforms: true)

      op_req = create_operation_request!(params, request_cid, scope, key)
      append_journal!(op_req, "received")
      append_journal!(op_req, "grounded", {
        "shape_digest" => inbound.shape_digest,
        "shape_digest_v2" => inbound.shape_digest_v2,
        "shape_artifact_id" => inbound.shape_artifact_id
      })
      create_context!(params, request_cid, kind: "request", inbound: inbound)
      ensure_channel!

      # P6 authorization — may raise KnownRefusal after writing public evidence
      begin
        Authorization.admit!(params: params, request_cid: request_cid, op_req: op_req)
        append_journal!(op_req, "authorized", { "decision" => "permit" })
      rescue KnownRefusal => e
        append_journal!(op_req, "refused", { "reason" => e.reason, "decision" => "deny" })
        raise
      end

      # P3 routing evidence (append-only hops; never overwrites the decision)
      Routing.record_if_routed!(params: params, request_cid: request_cid, op_req: op_req)
      append_journal!(op_req, "routed")

      domain = @handler.call(params, ctx)
      append_journal!(op_req, "dispatched")

      receipt = create_receipt!(op_req, request_cid, domain, status: "succeeded")
      append_journal!(op_req, "completed", { "receipt_cid" => receipt.cid })
      create_context!(domain, receipt.cid, kind: "response", inbound: inbound, subject: domain["@id"])

      record_p5_evidence!(params, request_cid, domain, receipt, op_req)
      References.record_from_effect!(params: params, request_cid: request_cid, domain: domain, op_req: op_req)
      ProfileIndex.record!(
        subject_cid: domain.is_a?(Hash) ? domain["@id"] : request_cid,
        evidence_type: "receipt",
        evidence_cid: receipt.cid,
        operation_name: @operation,
        summary: { "status" => receipt.status }
      )

      # P10.M6 — optional IntentTrace gate (required when groundingCid/intentTrace set)
      if params["groundingCid"].to_s != "" || params["intentTrace"].to_s == "true"
        effect_cid = domain.is_a?(Hash) ? (domain["@id"] || domain["cid"]).to_s : request_cid
        Intent::TraceGate.require_and_record!(
          effect_cid: effect_cid,
          grounding_cid: params["groundingCid"]
        )
      end

      # RESPONSE VALIDATION -- symmetric with pull!, which has always done this.
      #
      # PLACED LAST, AFTER EVERY EVIDENCE WRITE, deliberately. By the time the
      # handler has returned, the side effect has already happened: session.observe
      # has written triples and bumped the generation. Refusing earlier would leave
      # a completed write with no receipt, and a retry would perform it a second
      # time. With the receipt written first, a retry finds the prior request and
      # replays instead -- so a malformed response is reported without turning one
      # write into two.
      #
      # THE REPLAY EXIT ABOVE IS NOT VALIDATED, and that is not an oversight.
      # replay_payload returns { replayed, operation_request_cid, receipt_cid,
      # replayed_from_receipt_cid } -- a receipt reference, not a domain response.
      # No response shape describes that document, so validating it there would
      # refuse every idempotent retry.
      outbound = Grounding.validate(
        { "@id" => request_cid, "items" => [domain] },
        profile: @response_shape
      )
      unless outbound.conforms?
        append_journal!(op_req, "response_refused", { "shape_digest" => outbound.shape_digest })
        raise KnownRefusal.new("grounding_refused", outbound.safe_report.merge(
          "request_cid" => request_cid,
          "profile_ids" => @profiles
        ))
      end

      succeed_item(params, domain, request_cid, receipt)
    end

    def pull!(params, ctx, request_cid)
      result = @handler.call(params, ctx)
      outbound = Grounding.validate(
        { "@id" => request_cid, "items" => result.is_a?(Array) ? result : [result] },
        profile: @response_shape
      )
      unless outbound.conforms?
        raise KnownRefusal.new("grounding_refused", outbound.safe_report.merge(
          "request_cid" => request_cid,
          "profile_ids" => @profiles
        ))
      end
      result
    end

    def succeed_item(_params, item, request_cid, receipt, replay: false)
      # rails-cpcp Envelope.ok wraps this as `result`. Attach governance metadata.
      if item.is_a?(Hash)
        item.merge(
          "governance" => {
            "request_cid" => request_cid,
            "profile_ids" => @profiles,
            "receipt_cid" => receipt&.cid,
            "replayed" => replay,
            "replayed_from_receipt_cid" => replay ? receipt&.cid : nil
          }.compact
        )
      else
        item
      end
    end

    def replay_payload(prior, receipt)
      RailsCpcp::Replay.from_first_result(
        "operation_request_cid" => prior.cid,
        "receipt_cid" => receipt&.cid,
        "replayed_from_receipt_cid" => receipt&.cid
      )
    end

    def derive_request_cid(params)
      Cid.for_payload(
        "operation" => @operation,
        "operationId" => params["operationId"],
        "title" => params["title"],
        "body" => params["body"],
        "idempotencyKey" => params["idempotencyKey"] || params["operationId"]
      )
    end

    def find_prior_request(operation, scope, key)
      return nil unless defined?(RailsOsiLevel8::OperationRequest)

      RailsOsiLevel8::OperationRequest.admitted.find_by(
        operation_name: operation,
        idempotency_scope: scope,
        idempotency_key: key
      )
    end

    def create_operation_request!(params, request_cid, scope, key)
      placement = LedgerPolicy.placement_for!(operation: @operation, evidence: :request)
      now = clock_now
      RailsOsiLevel8::OperationRequest.create!(
        cid: request_cid,
        profile_id: @profiles.first || "osi-l8/p4-durable-execution@1",
        ledger_placement: placement,
        provenance_json: { "agent_iri" => params["callerIri"] || "cyborg:front", "received_at" => now.iso8601 },
        payload_digest: Cid.digest_for(params),
        recorded_at: now,
        operation_name: @operation,
        direction: "push",
        idempotency_scope: scope,
        idempotency_key: key,
        request_context_cid: request_cid,
        effect_cid: request_cid,
        request_digest: Cid.digest_for(params),
        caller_iri: params["callerIri"] || "cyborg:front"
      )
    end

    def append_journal!(op_req, event_kind, detail = {})
      seq = (op_req.journal_entries.maximum(:sequence) || 0) + 1
      now = clock_now
      cid = Cid.for_payload("op" => op_req.cid, "seq" => seq, "event" => event_kind)
      RailsOsiLevel8::OperationJournalEntry.create!(
        cid: cid,
        profile_id: "osi-l8/p4-durable-execution@1",
        ledger_placement: "canonical",
        provenance_json: { "operation_request_cid" => op_req.cid },
        payload_digest: Cid.digest_for(detail.merge("event" => event_kind, "seq" => seq)),
        recorded_at: now,
        operation_request_cid: op_req.cid,
        sequence: seq,
        event_kind: event_kind,
        event_at: now,
        detail_json: detail,
        receipt_cid: detail["receipt_cid"]
      )
    end

    def create_receipt!(op_req, request_cid, domain, status:)
      now = clock_now
      exec_key = "#{op_req.operation_name}:#{op_req.idempotency_scope}:#{op_req.idempotency_key}"
      payload = { "status" => status, "domain" => domain, "operation_request_cid" => op_req.cid }
      cid = Cid.for_payload(payload)
      placement = LedgerPolicy.placement_for!(operation: @operation, evidence: :receipt)
      RailsOsiLevel8::ExecutionReceipt.create!(
        cid: cid,
        profile_id: "osi-l8/p4-durable-execution@1",
        ledger_placement: placement,
        provenance_json: { "operation_request_cid" => op_req.cid },
        payload_digest: Cid.digest_for(payload),
        recorded_at: now,
        operation_request_cid: op_req.cid,
        effect_cid: request_cid,
        execution_key: exec_key,
        status: status,
        result_context_cid: domain.is_a?(Hash) ? domain["@id"] : nil,
        result_digest: Cid.digest_for(domain),
        completed_at: now
      )
    end

    def create_context!(payload, cid, kind:, inbound:, subject: nil)
      now = clock_now
      placement = LedgerPolicy.placement_for!(operation: @operation, evidence: :context)
      body = payload.is_a?(Hash) ? payload : { "value" => payload }
      RailsOsiLevel8::Context.create!(
        cid: cid + ":#{kind}",
        profile_id: "osi-l8/p1/cyborg-channel@1",
        ledger_placement: placement,
        provenance_json: { "kind" => kind },
        payload_digest: Cid.digest_for(body),
        recorded_at: now,
        subject_iri: subject || body["@id"] || "mind:pod",
        context_kind: kind,
        jsonld: body,
        graph_iri: RailsOsiLevel8.config.base_iri,
        shape_id: inbound.shape_id,
        shape_digest: inbound.shape_digest,
        admitted_at: now
      )
    end

    def ensure_channel!
      return if RailsOsiLevel8::CyborgChannel.cross_boundary.exists?(cyborg_iri: "cyborg:front", channel_key: "cpcp")

      now = clock_now
      payload = { "cyborg" => "cyborg:front", "channel" => "cpcp" }
      RailsOsiLevel8::CyborgChannel.create!(
        cid: Cid.for_payload(payload),
        profile_id: "osi-l8/p1/cyborg-channel@1",
        ledger_placement: LedgerPolicy.placement_for!(operation: "note.create", evidence: :channel),
        provenance_json: {},
        payload_digest: Cid.digest_for(payload),
        recorded_at: now,
        cyborg_iri: "cyborg:front",
        channel_key: "cpcp",
        counterparty_iri: "mind:pod/back",
        direction: "bidirectional",
        transport: "cpcp",
        channel_status: "open",
        capabilities_json: { "operations" => %w[note.create note.list] }
      )
    end

    # P5: declare-once actor biography + request→note→receipt provenance chain.
    def record_p5_evidence!(params, request_cid, domain, receipt, op_req)
      return unless defined?(RailsOsiLevel8::BiographyEvent)

      caller = params["callerIri"].presence || "cyborg:front"
      note_cid = domain.is_a?(Hash) ? (domain["@id"] || domain["cid"]).to_s : nil
      note_cid = "note:unknown" if note_cid.nil? || note_cid.empty?
      ensure_actor_biography!(caller)
      record_provenance_chain!(request_cid, note_cid, receipt, op_req, caller)
    end

    def ensure_actor_biography!(subject_iri)
      exists = RailsOsiLevel8::BiographyEvent.cross_boundary.exists?(
        subject_iri: subject_iri,
        event_kind: "declared"
      )
      return if exists

      now = clock_now
      statement = { "role" => "cyborg", "channel" => "cpcp" }
      payload = { "subject" => subject_iri, "event" => "declared", "statement" => statement }
      RailsOsiLevel8::BiographyEvent.create!(
        cid: Cid.for_payload(payload),
        profile_id: "osi-l8/p5-biography-provenance@1",
        ledger_placement: LedgerPolicy.placement_for!(operation: "note.create", evidence: :biography),
        provenance_json: { "asserted_by_iri" => subject_iri },
        payload_digest: Cid.digest_for(payload),
        recorded_at: now,
        subject_iri: subject_iri,
        event_kind: "declared",
        asserted_by_iri: subject_iri,
        valid_from: now,
        valid_to: nil,
        statement_json: statement
      )
    end

    def record_provenance_chain!(request_cid, note_cid, receipt, op_req, caller)
      now = clock_now
      placement = LedgerPolicy.placement_for!(operation: "note.create", evidence: :provenance)
      profile = "osi-l8/p5-biography-provenance@1"

      edges = [
        {
          from_cid: note_cid,
          predicate: "prov:wasDerivedFrom",
          to_cid: request_cid,
          to_iri: nil,
          agent_iri: caller,
          activity_cid: op_req.cid
        },
        {
          from_cid: receipt.cid,
          predicate: "prov:wasGeneratedBy",
          to_cid: note_cid,
          to_iri: nil,
          agent_iri: caller,
          activity_cid: op_req.cid
        },
        {
          from_cid: note_cid,
          predicate: "prov:wasAttributedTo",
          to_cid: nil,
          to_iri: caller,
          agent_iri: caller,
          activity_cid: op_req.cid
        }
      ]

      edges.each do |edge|
        payload = edge.merge("asserted_at" => now.iso8601)
        RailsOsiLevel8::ProvenanceEdge.create!(
          cid: Cid.for_payload(payload),
          profile_id: profile,
          ledger_placement: placement,
          provenance_json: { "operation_request_cid" => op_req.cid },
          payload_digest: Cid.digest_for(payload),
          recorded_at: now,
          from_cid: edge[:from_cid],
          predicate: edge[:predicate],
          to_cid: edge[:to_cid],
          to_iri: edge[:to_iri],
          agent_iri: edge[:agent_iri],
          activity_cid: edge[:activity_cid],
          asserted_at: now
        )
      end
    end

    def record_admission!(params, request_cid, inbound, conforms:)
      now = clock_now
      RailsOsiLevel8::AdmissionAttempt.create!(
        cid: Cid.for_payload("admission" => request_cid, "at" => now.iso8601),
        profile_id: "osi-l8/gateway-audit@1",
        ledger_placement: "private_local",
        provenance_json: {},
        payload_digest: Cid.digest_for(params),
        recorded_at: now,
        operation_name: @operation,
        direction: @direction.to_s,
        request_cid: request_cid,
        request_digest: Cid.digest_for(params),
        caller_iri: params["callerIri"],
        conforms: conforms,
        refusal_reason: conforms ? nil : "grounding_refused",
        shape_id: inbound.shape_id,
        shape_digest: inbound.shape_digest,
        report_json: inbound.safe_report
      )
    end

    def record_refusal!(params, request_cid, inbound)
      record_admission!(params, request_cid, inbound, conforms: false)
    rescue StandardError => e
      warn_log(e, request_cid)
    end

    def clock_now
      RailsOsiLevel8.config.clock.call
    end

    def stringify(obj)
      case obj
      when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
      when Array then obj.map { |v| stringify(v) }
      else obj
      end
    end

    def warn_log(error, request_cid)
      return unless defined?(Rails) && Rails.respond_to?(:logger)

      Rails.logger.error(
        event: "osi_l8.adapter_error",
        operation: @operation,
        cid: request_cid,
        exception: error.class.name,
        message: error.message
      )
    end
  end
end
