# frozen_string_literal: true

require "digest"

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
                   activations: {}, receipts: {}, disputes: {}, resolutions: {},
                   translations: {}, reviews: {}, artifacts: {} }
      end

      def put_concept!(rec) = put!(:concepts, rec, "Concept")
      def put_revision!(rec)
        rec = Request.stringify(rec || {})
        rec["@type"] ||= "DefinitionRevision"
        Contract.validate!(rec)
        ensure_artifact_verifiable!(rec)
        put!(:revisions, rec, "DefinitionRevision")
      end
      def put_attestation!(rec) = put!(:attestations, rec, "SemanticAttestation")
      def put_binding!(rec) = put!(:bindings, rec, "OperationBinding")
      def put_activation!(rec) = put!(:activations, rec, "SemanticActivation")
      def put_receipt!(rec) = put!(:receipts, rec, "ActabilityReceipt")
      def put_dispute!(rec) = put!(:disputes, rec, "SemanticDispute")
      def put_resolution!(rec) = put!(:resolutions, rec, "DisputeResolution")

      def put_translation!(rec)
        rec = Request.stringify(rec || {})
        rec["@type"] ||= "StewardshipTranslation"
        Contract.validate!(rec)
        refuse_ungrounded!(rec)
        put!(:translations, rec, "StewardshipTranslation")
      end

      def put_review!(rec)
        rec = Request.stringify(rec || {})
        rec["@type"] ||= "TranslationReview"
        Contract.validate!(rec)
        tr = translation(rec["translation"])
        if tr.nil?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "missing" => "translation", "translation" => rec["translation"], "profile_id" => Vocabulary::PROFILE_ID }
          )
        end
        refuse_ungrounded!(tr)
        put!(:reviews, rec, "TranslationReview")
      end

      def concept(cid) = at(:concepts, cid)
      def revision(cid) = at(:revisions, cid)
      def receipt(cid) = at(:receipts, cid)
      def translation(cid) = at(:translations, cid)
      def review(cid) = at(:reviews, cid)

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

      def latest_dispute(concept_cid, revision_cid, seq:, scope: nil)
        applicable = log[:disputes].values.select { |r|
          next false if seq && r["sequence"].to_i > seq.to_i
          next false if scope && !scope.to_s.empty? && r["scope"].to_s != scope.to_s
          r["concept"] == concept_cid ||
            r["definitionRevision"] == revision_cid ||
            r["target"] == concept_cid ||
            r["target"] == revision_cid
        }
        return "none" if applicable.empty?
        unresolved = applicable.any? { |d| !resolution_for?(d["cid"], seq) }
        unresolved ? "open" : "resolved"
      end

      def resolution_for?(dispute_cid, seq)
        log[:resolutions].values.any? { |r|
          r["dispute"] == dispute_cid && (seq.nil? || r["sequence"].to_i <= seq.to_i)
        }
      end
      private_class_method :resolution_for?

      # P11.5 — a rendering whose grounding revision is withdrawn, belongs to a
      # different Concept, or has been superseded cannot be affirmed.
      def refuse_ungrounded!(rec)
        concept_iri = rec["refersTo"].to_s
        rev_iri = rec["groundedIn"].to_s
        scope = rec["scope"].to_s
        concept = concept(concept_iri) || concept_by_iri(concept_iri)
        if concept.nil?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:term_unregistered],
            { "concept" => concept_iri, "profile_id" => Vocabulary::PROFILE_ID }
          )
        end
        revision = revision_as_of(rev_iri, nil)
        if revision.nil?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:term_unregistered],
            { "definitionRevision" => rev_iri, "profile_id" => Vocabulary::PROFILE_ID }
          )
        end

        mismatch = revision["concept"].to_s != concept_iri
        withdrawn = revision["definitionLifecycle"].to_s == "withdrawn"
        later = later_revision_for(concept_iri, revision)
        activation = latest_activation(concept_iri, scope, seq: sequence)
        activated_elsewhere = activation && activation["definitionRevision"].to_s != rev_iri
        return unless mismatch || withdrawn || later || activated_elsewhere

        because = {
          "translation" => rec["cid"],
          "concept" => concept_iri,
          "groundedIn" => rev_iri,
          "scope" => scope,
          "satisfy" => [
            "groundedIn belongs to refersTo",
            "definitionLifecycle!=withdrawn",
            "groundedIn is current for Concept in scope"
          ],
          "profile_id" => Vocabulary::PROFILE_ID
        }
        because["revision.concept"] = revision["concept"] if mismatch
        because["definitionLifecycle"] = "withdrawn" if withdrawn
        because["supersededBy"] = later["cid"] if later
        because["activatedRevision"] = activation["definitionRevision"] if activated_elsewhere
        raise KnownRefusal.new(Vocabulary::REFUSAL_CODES[:translation_grounding_insufficient], because)
      end
      private_class_method :refuse_ungrounded!

      def ensure_artifact_verifiable!(rec)
        # Legacy append-only rows still carry `content`. Do not drop it; copy
        # bytes into the artifact log so a receipt can recompute.
        if rec["normativeArtifact"].nil? && !rec["content"].to_s.empty?
          absorb_legacy_content!(rec)
          return
        end
        art = rec["normativeArtifact"]
        iri = art.is_a?(Hash) ? art["artifactIri"].to_s : ""
        digest = art.is_a?(Hash) ? art.dig("contentDigest", "value").to_s : ""
        algo = art.is_a?(Hash) ? art.dig("contentDigest", "algorithm").to_s : ""
        if art.nil? || iri.empty? || digest.empty? || algo != "sha256"
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:artifact_missing],
            {
              "revision" => rec["cid"],
              "artifactIri" => iri,
              "digest" => digest,
              "scope" => rec["scope"],
              "satisfy" => ["normativeArtifact.contentDigest sha256 value"],
              "profile_id" => Vocabulary::PROFILE_ID
            }
          )
        end
        policy = art["retrievalPolicy"].to_s
        stored = log[:artifacts][digest]
        if stored.nil? && %w[local required local-required].include?(policy)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:artifact_missing],
            {
              "revision" => rec["cid"],
              "artifactIri" => iri,
              "digest" => digest,
              "scope" => rec["scope"],
              "satisfy" => ["artifact bytes for contentDigest under retrievalPolicy=#{policy}"],
              "profile_id" => Vocabulary::PROFILE_ID
            }
          )
        end
      end

      def absorb_legacy_content!(rec)
        body = rec["content"].to_s
        digest = Digest::SHA256.hexdigest(body)
        log[:artifacts][digest] ||= { "digest" => digest, "body" => body, "sourceRevision" => rec["cid"] }
        persist_artifact_ar!(digest, body, rec)
      end
      private_class_method :absorb_legacy_content!

      def later_revision_for(concept_iri, revision)
        seq = revision["sequence"].to_i
        log[:revisions].values.select { |r|
          r["concept"].to_s == concept_iri && r["sequence"].to_i > seq
        }.max_by { |r| r["sequence"].to_i }
      end
      private_class_method :later_revision_for

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
        disputes: :MngSemanticDispute,
        resolutions: :MngDisputeResolution,
        translations: :MngStewardshipTranslation,
        reviews: :MngTranslationReview,
        artifacts: :MngNormativeArtifact
      }.freeze

      def persist_ar!(bucket, rec)
        return unless ar_enabled?
        return if bucket == :artifacts

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

      def persist_artifact_ar!(digest, body, rec)
        return unless ar_enabled?
        return unless defined?(::RailsOsiLevel8::MngNormativeArtifact)
        return unless ::RailsOsiLevel8::MngNormativeArtifact.table_exists?
        return if ::RailsOsiLevel8::MngNormativeArtifact.exists?(cid: "cid:artifact:#{digest[0, 32]}")

        ::RailsOsiLevel8::MngNormativeArtifact.create!(
          cid: "cid:artifact:#{digest[0, 32]}",
          profile_id: Vocabulary::PROFILE_ID,
          ledger_placement: "canonical",
          provenance_json: { "sourceRevision" => rec["cid"] },
          payload_digest: "sha256:#{digest}",
          recorded_at: Time.now.utc,
          envelope_json: { "digest" => digest, "body" => body, "sourceRevision" => rec["cid"] },
          sequence: next_seq
        )
      rescue StandardError
        nil
      end
      private_class_method :persist_artifact_ar!
    end
  end
end
