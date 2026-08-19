# frozen_string_literal: true

require "digest"
require "json"
require "securerandom"

module RailsOsiLevel8
  module Intent
    # Helpers to create immutable INTENT entity rows with governed fields.
    module Factory
      module_function

      def create!(klass, attrs)
        attrs = attrs.transform_keys(&:to_s)
        intrinsic = attrs.except(
          "cid", "profile_id", "ledger_placement", "state", "payload_digest",
          "provenance_actor_cid", "provenance_source_cid", "created_at"
        )
        digest = Digest::SHA256.hexdigest(JSON.generate(intrinsic.sort.to_h))
        cid = attrs["cid"] || "cid:sha256:#{Digest::SHA256.hexdigest("#{klass.name}:#{digest}:#{SecureRandom.hex(4)}")}"
        klass.create!(
          cid: cid,
          profile_id: attrs["profile_id"] || "osi-level-8/profile-10",
          ledger_placement: attrs["ledger_placement"] || "canonical",
          state: attrs["state"] || "draft",
          payload_digest: digest,
          provenance_actor_cid: attrs["provenance_actor_cid"],
          provenance_source_cid: attrs["provenance_source_cid"],
          created_at: Time.now.utc,
          **intrinsic.transform_keys(&:to_sym)
        )
      end

      def seed_demo!
        GraphStore.reset!
        st = create!(Stakeholder, name: "Customers", stakeholder_kind: "customer",
                                  stake_statement: "Reliable governed Effects", state: "ratified")
        vp = create!(ValueProposition, value_statement: "Traceable purpose for every Effect",
                                       proposition_status: "validated", state: "ratified")
        create!(Offer, name: "Governance review", offer_kind: "service",
                       description: "Authorization review as a service", state: "ratified")
        seg = create!(MarketSegment, name: "Regulated enterprises", kind: "segment",
                                     definition_statement: "Orgs with audit obligations", state: "ratified")
        create!(EconomicActor, name: "Mind Pod Operator Co", actor_kind: "organization",
                               external_identifier: "org:mind-pod", state: "ratified")
        goal = create!(Goal, title: "Zero ungrounded commits", kind: "goal",
                             goal_status: "active", state: "ratified")
        create!(KeyResult, title: "100% effects with IntentTrace", target_value: "100",
                           comparison: "gte", target_unit: "percent", result_status: "open", state: "ratified")
        create!(ValueMetric, name: "grounded_effect_ratio", metric_dimension: "operational",
                             unit: "ratio", desired_direction: "increase", state: "ratified")
        create!(Constraint, name: "No private_local egress", kind: "policy",
                            normative_statement: "private_local never crosses CPCP",
                            constraint_status: "binding", state: "ratified")
        create!(Externality, externality_statement: "Reduced audit burden",
                             externality_polarity: "positive", state: "ratified")
        create!(Stakeholder, name: "Secret regulators", stakeholder_kind: "regulator",
                             stake_statement: "classified", ledger_placement: "private_local", state: "draft")

        { stakeholder: st, value_proposition: vp, segment: seg, goal: goal }
      end
    end
  end
end
