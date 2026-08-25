# frozen_string_literal: true

module RailsOsiLevel8
  module Profile11
    # P11.2 — five stored dimensions → three derived bands. Never writes a band
    # onto Concept/Revision/Attestation/Binding/Activation.
    module Evaluator
      EVAL_KEYS = %w[
        concept definitionRevision scope namedUse operationRevision
        contractDigest shapeDigest implementationDigest policyRevision asOfSequence
      ].freeze

      USE_BAND = {
        "explore" => "explorable",
        "quote" => "explorable",
        "plan" => "plan-eligible",
        "effect" => "effect-eligible",
        "dispatch" => "effect-eligible"
      }.freeze

      RANK = {
        "explorable" => 1,
        "plan-eligible" => 2,
        "effect-eligible" => 3,
        "none" => 0, "local" => 1, "federated" => 2,
        "narrative" => 0, "structured" => 1, "testable" => 2
      }.freeze

      module_function

      def evaluate(params)
        params = Request.closed!(
          params,
          EVAL_KEYS,
          reason: Vocabulary::REFUSAL_CODES[:policy_indeterminate]
        )
        named_use = params["namedUse"].to_s
        named_use = params["operationRevision"].to_s.empty? ? "explore" : "effect" if named_use.empty?
        unless Vocabulary::NAMED_USES.include?(named_use)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:enum_invalid],
            { "dimension" => "namedUse", "value" => named_use, "allowed" => Vocabulary::NAMED_USES }
          )
        end

        seq = params["asOfSequence"]
        seq = seq.nil? || seq.to_s.empty? ? Store.sequence : seq.to_i

        concept_iri = params["concept"].to_s
        revision_iri = params["definitionRevision"].to_s
        scope = params["scope"].to_s

        if concept_iri.empty? && revision_iri.empty?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "missing" => %w[concept definitionRevision] }
          )
        end

        concept = concept_iri.empty? ? nil : (Store.concept(concept_iri) || Store.concept_by_iri(concept_iri, seq: seq))
        if revision_iri.empty?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:definition_version_required],
            { "concept" => concept_iri, "satisfy" => ["definitionRevision"] }
          )
        end
        raise KnownRefusal.new(Vocabulary::REFUSAL_CODES[:term_unregistered], { "concept" => concept_iri }) if concept_iri != "" && concept.nil?

        revision = Store.revision_as_of(revision_iri, seq)
        raise KnownRefusal.new(Vocabulary::REFUSAL_CODES[:term_unregistered], { "definitionRevision" => revision_iri }) unless revision
        Store.ensure_artifact_verifiable!(revision)

        unless scope.empty? || revision["scope"].to_s == scope || Array(revision["scope"]).include?(scope)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:scope_mismatch],
            { "requested" => scope, "admissible" => revision["scope"] }
          )
        end

        formalization = revision["formalization"].to_s
        if formalization == "testable"
          by_kind = Store.latest_verifications_by_kind(revision_iri, seq: seq)
          fail_ev = by_kind.values.find { |r| r["result"].to_s == "failing" }
          if fail_ev
            raise KnownRefusal.new(
              Vocabulary::REFUSAL_CODES[:verification_failed],
              {
                "revision" => revision_iri,
                "verificationKind" => fail_ev["verificationKind"],
                "result" => fail_ev["result"],
                "finding" => fail_ev["finding"],
                "scope" => scope.empty? ? revision["scope"] : scope,
                "satisfy" => ["SemanticVerificationEvidence result=passing finding"],
                "profile_id" => Vocabulary::PROFILE_ID
              }
            )
          end
          pass_ev = by_kind["ontology-consistency"]
          unless pass_ev && pass_ev["result"].to_s == "passing"
            raise KnownRefusal.new(
              Vocabulary::REFUSAL_CODES[:verification_missing],
              {
                "revision" => revision_iri,
                "verificationKind" => "ontology-consistency",
                "result" => pass_ev && pass_ev["result"],
                "finding" => pass_ev && pass_ev["finding"],
                "scope" => scope.empty? ? revision["scope"] : scope,
                "satisfy" => ["SemanticVerificationEvidence ontology-consistency result=passing finding"],
                "profile_id" => Vocabulary::PROFILE_ID
              }
            )
          end
        end

        lifecycle = revision["definitionLifecycle"].to_s
        if lifecycle == "withdrawn"
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:definition_inactive],
            { "definitionLifecycle" => lifecycle, "satisfy" => ["definitionLifecycle=active"] }
          )
        end

        subject = concept_iri.empty? ? revision["concept"] : concept_iri
        dispute = Store.latest_dispute(subject, revision_iri, seq: seq)
        agreement = Store.latest_agreement(subject, revision_iri, seq: seq, scope: scope)
        attestation = Store.latest_attestation(revision_iri, seq: seq)
        binding = Store.latest_binding(revision_iri, params["operationRevision"], seq: seq)

        if %w[effect dispatch].include?(named_use)
          if binding.nil?
            raise KnownRefusal.new(
              Vocabulary::REFUSAL_CODES[:operation_binding_missing],
              { "definitionRevision" => revision_iri, "operationRevision" => params["operationRevision"], "satisfy" => ["OperationBinding"] }
            )
          end
          req_digest = params["contractDigest"].to_s
          if !req_digest.empty? && binding["contractDigest"].to_s != req_digest
            raise KnownRefusal.new(
              Vocabulary::REFUSAL_CODES[:binding_stale],
              {
                "pinned" => binding["contractDigest"],
                "requested" => req_digest,
                "satisfy" => ["contractDigest matches OperationBinding"]
              }
            )
          end
        end

        if attestation && attestation["authorityRef"].to_s.empty? && %w[effect dispatch].include?(named_use)
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:attestation_invalid],
            { "missing" => "authorityRef", "satisfy" => ["SemanticAttestation.authorityRef (P6)"] }
          )
        end

        dimensions = {
          "definitionLifecycle" => lifecycle,
          "agreement" => agreement,
          "dispute" => dispute,
          "formalization" => revision["formalization"].to_s,
          "binding" => (binding && binding["binding"]) || "unbound"
        }
        band = derive_band(dimensions, binding, attestation, params)

        required = USE_BAND.fetch(named_use)
        if RANK.fetch(band, 0) < RANK.fetch(required, 0)
          if dispute == "open" && required != "explorable"
            raise KnownRefusal.new(
              Vocabulary::REFUSAL_CODES[:definition_contested],
              { "dispute" => "open", "asOfSequence" => seq, "satisfy" => ["dispute=resolved|none"] }
            )
          end
          if lifecycle != "active" && required != "explorable"
            raise KnownRefusal.new(
              Vocabulary::REFUSAL_CODES[:definition_inactive],
              { "definitionLifecycle" => lifecycle, "haveBand" => band, "requiredBand" => required,
                "satisfy" => ["definitionLifecycle=active"] }
            )
          end
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:actability_insufficient],
            {
              "haveBand" => band,
              "requiredBand" => required,
              "dimensions" => dimensions,
              "satisfy" => satisfy_for(required, dimensions)
            }
          )
        end

        if dispute == "open" && required != "explorable"
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:definition_contested],
            { "dispute" => "open", "asOfSequence" => seq, "satisfy" => ["dispute=resolved|none"] }
          )
        end

        policy = params["policyRevision"].to_s
        policy = "cid:policy:default" if policy.empty?
        receipt_body = {
          "@type" => "ActabilityReceipt",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "definitionRevision" => revision_iri,
          "operationRevision" => params["operationRevision"],
          "policyRevision" => policy,
          "scope" => scope.empty? ? revision["scope"] : scope,
          "namedUse" => named_use,
          "actabilityBand" => band,
          "asOfSequence" => seq,
          "dispute" => dispute,
          "dimensions" => dimensions,
          "contractDigest" => binding && binding["contractDigest"],
          "shapeDigest" => binding && (binding["shapeDigest"] || binding["implementationDigest"])
        }
        receipt_body["digest"] = Request.digest(receipt_body)
        receipt = Store.put_receipt!(receipt_body)
        receipt.merge(
          "eligibilityExplanation" => explain(
            dimensions: dimensions,
            concept_iri: subject,
            revision_iri: revision_iri,
            binding: binding
          )
        )
      end

      def explain(dimensions:, concept_iri:, revision_iri:, binding:)
        crit = lambda { |id, ok, ref|
          { "criterion" => id, "result" => (ok ? "passing" : "failing"), "ref" => ref }.compact
        }
        {
          "@type" => "EligibilityExplanation",
          "criteria" => [
            crit.call("term-registered", !concept_iri.to_s.empty?, concept_iri),
            crit.call("definition-revision", !revision_iri.to_s.empty?, revision_iri),
            crit.call("definitionLifecycle!=withdrawn", dimensions["definitionLifecycle"] != "withdrawn", revision_iri),
            crit.call("agreement>=local", RANK.fetch(dimensions["agreement"], 0) >= RANK["local"], concept_iri),
            crit.call("formalization>=structured", RANK.fetch(dimensions["formalization"], 0) >= RANK["structured"], revision_iri),
            crit.call("dispute!=open", dimensions["dispute"] != "open", revision_iri),
            crit.call("binding=verified", dimensions["binding"] == "verified", binding && binding["cid"])
          ]
        }
      end
      private_class_method :explain

      def reproduce(params)
        params = Request.closed!(params, %w[receiptCid cid], reason: Vocabulary::REFUSAL_CODES[:policy_indeterminate])
        cid = (params["receiptCid"] || params["cid"]).to_s
        rec = Store.receipt(cid)
        raise KnownRefusal.new(Vocabulary::REFUSAL_CODES[:envelope_invalid], { "missing" => "receiptCid" }) if rec.nil?

        replay = evaluate(
          "definitionRevision" => rec["definitionRevision"],
          "concept" => rec["concept"],
          "scope" => rec["scope"],
          "namedUse" => rec["namedUse"],
          "operationRevision" => rec["operationRevision"],
          "contractDigest" => rec["contractDigest"],
          "shapeDigest" => rec["shapeDigest"],
          "policyRevision" => rec["policyRevision"],
          "asOfSequence" => rec["asOfSequence"]
        )
        {
          "ok" => true,
          "matches" => replay["digest"] == rec["digest"] && replay["actabilityBand"] == rec["actabilityBand"],
          "original" => rec,
          "recomputed" => replay
        }
      end

      def derive_band(dimensions, binding, attestation, params)
        lifecycle = dimensions["definitionLifecycle"]
        return nil if lifecycle == "withdrawn"

        explorable = true
        plan = explorable &&
               lifecycle == "active" &&
               RANK.fetch(dimensions["agreement"], 0) >= RANK["local"] &&
               RANK.fetch(dimensions["formalization"], 0) >= RANK["structured"] &&
               dimensions["dispute"] != "open"
        effect = plan &&
                 dimensions["binding"] == "verified" &&
                 binding &&
                 !binding["operationRevision"].to_s.empty? &&
                 !binding["contractDigest"].to_s.empty? &&
                 attestation &&
                 !attestation["authorityRef"].to_s.empty? &&
                 !params["policyRevision"].to_s.empty?
        return "effect-eligible" if effect
        return "plan-eligible" if plan
        return "explorable" if explorable

        nil
      end
      private_class_method :derive_band

      def satisfy_for(required, dimensions)
        case required
        when "plan-eligible"
          %w[definitionLifecycle=active agreement>=local formalization>=structured dispute!=open]
        when "effect-eligible"
          %w[plan-eligible binding=verified OperationBinding.contractDigest SemanticAttestation.authorityRef policyRevision]
        else
          ["registered DefinitionRevision", "definitionLifecycle!=withdrawn"]
        end + [{ "have" => dimensions }]
      end
      private_class_method :satisfy_for
    end
  end
end
