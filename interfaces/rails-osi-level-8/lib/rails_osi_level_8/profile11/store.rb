# frozen_string_literal: true

module RailsOsiLevel8
  module Profile11
    # Append-only meaning store. Memory always; AR when osi_l8_mng_* tables exist.
    module Store
      module_function

      def reset!
        @log = nil
        @seq = 0
      end

      def sequence = (@seq || 0)

      def next_seq
        @seq = sequence + 1
      end

      def log
        @log ||= { concepts: {}, revisions: {}, attestations: {}, bindings: {},
                   activations: {}, receipts: {}, disputes: {} }
      end

      def put_concept!(rec) = put!(:concepts, rec, "Concept")
      def put_revision!(rec) = put!(:revisions, rec, "DefinitionRevision")
      def put_attestation!(rec) = put!(:attestations, rec, "SemanticAttestation")
      def put_binding!(rec) = put!(:bindings, rec, "OperationBinding")
      def put_activation!(rec) = put!(:activations, rec, "SemanticActivation")
      def put_receipt!(rec) = put!(:receipts, rec, "ActabilityReceipt")
      def put_dispute!(rec) = put!(:disputes, rec, "Dispute")

      def concept(cid) = at(:concepts, cid)
      def revision(cid) = at(:revisions, cid)
      def receipt(cid) = at(:receipts, cid)

      def concept_by_iri(iri, seq: nil)
        latest(:concepts, seq) { |r| r["cid"] == iri || r["@id"] == iri }
      end

      def revision_as_of(cid, seq)
        at(:revisions, cid, seq: seq)
      end

      def latest_attestation(revision_cid, seq:)
        latest(:attestations, seq) { |r| r["definitionRevision"] == revision_cid }
      end

      def latest_binding(revision_cid, operation_cid, seq:)
        latest(:bindings, seq) { |r|
          r["definitionRevision"] == revision_cid &&
            (operation_cid.to_s.empty? || r["operationRevision"] == operation_cid)
        }
      end

      def latest_activation(concept_cid, scope, seq:)
        latest(:activations, seq) { |r| r["concept"] == concept_cid && r["scope"] == scope }
      end

      def latest_dispute(concept_cid, revision_cid, seq:)
        rec = latest(:disputes, seq) { |r|
          r["concept"] == concept_cid || r["definitionRevision"] == revision_cid
        }
        rec ? rec["dispute"].to_s : "none"
      end

      def put!(bucket, rec, type)
        rec = Request.stringify(rec || {})
        rec["@type"] ||= type
        rec["profileId"] ||= Vocabulary::PROFILE_ID
        rec["ledgerPlacement"] ||= "canonical"
        rec["cid"] = rec["cid"].to_s
        rec["digest"] ||= Request.digest(rec.except("digest", "sequence", "cid"))
        Contract.validate!(rec)
        seq = next_seq
        if rec["cid"].empty? || type == "ActabilityReceipt"
          rec["cid"] = "cid:#{type}:#{seq}:#{rec['digest'].to_s.delete_prefix('sha256:')[0, 16]}"
        end
        rec = rec.merge("sequence" => seq)
        raise ArgumentError, "append-only: #{rec['cid']}" if log[bucket].key?(rec["cid"])

        log[bucket][rec["cid"]] = rec
        persist_ar!(bucket, rec)
        rec
      end
      private_class_method :put!

      def at(bucket, cid, seq: nil)
        rec = log[bucket][cid.to_s]
        return nil unless rec
        return nil if seq && rec["sequence"].to_i > seq.to_i

        rec
      end
      private_class_method :at

      def latest(bucket, seq)
        recs = log[bucket].values
        recs = recs.select { |r| r["sequence"].to_i <= seq.to_i } if seq
        recs.select { |r| yield r }.max_by { |r| r["sequence"].to_i }
      end
      private_class_method :latest

      def ar_enabled?
        defined?(::ActiveRecord::Base) &&
          defined?(::RailsOsiLevel8::MngConcept) &&
          ::RailsOsiLevel8::MngConcept.table_exists?
      rescue StandardError
        false
      end
      private_class_method :ar_enabled?

      AR_MAP = {
        concepts: :MngConcept,
        revisions: :MngDefinitionRevision,
        attestations: :MngAttestation,
        bindings: :MngBinding,
        activations: :MngActivation,
        receipts: :MngReceipt,
        disputes: :MngDispute
      }.freeze

      def persist_ar!(bucket, rec)
        return unless ar_enabled?

        klass = ::RailsOsiLevel8.const_get(AR_MAP.fetch(bucket))
        return if klass.exists?(cid: rec["cid"])

        klass.create!(
          cid: rec["cid"],
          profile_id: rec["profileId"] || Vocabulary::PROFILE_ID,
          ledger_placement: rec["ledgerPlacement"] || "canonical",
          provenance_json: {},
          payload_digest: rec["digest"] || Request.digest(rec),
          recorded_at: Time.now.utc,
          envelope_json: rec,
          sequence: rec["sequence"]
        )
      end
      private_class_method :persist_ar!
    end
  end
end
