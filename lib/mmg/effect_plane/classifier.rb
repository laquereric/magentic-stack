# frozen_string_literal: true
module Mmg
  module EffectPlane
    # Given a placement, what does reversing this effect actually mean?
    #
    # Stage alone is not enough: the same snapshot_image placement is
    # fork-reversible when the captured stores are a MATERIALIZATION of retained
    # truth, and refused when they are the SOLE AUTHORITY for domain facts.
    # Authority and externality decide it.
    module Classifier
      module_function

      # effect:           free-form caller identity, carried through
      # placement:        an accepted Placement.declare result
      # authority:        { role:, reconstructable_from:, clone_evidence: }
      # external_effects: [ { id:, closure: } ]  closure nil == UNCLOSED
      def classify(effect:, placement:, authority:, external_effects:)
        acc = accepted_placement(placement)
        return acc unless acc[:ok]

        stage = acc[:placement][:stage]
        auth  = authority.is_a?(Hash) ? authority : {}

        unclosed = Array(external_effects).reject { |e| closed?(e) }

        case stage
        when :container_layer
          # Ephemeral. Discard-and-recreate only -- never a durable snapshot.
          verdict(effect, stage, :reversible, :discard_and_recreate,
                  "a container writable layer is lost on container death; it can be discarded and recreated, " \
                  "but it is not a durable rollback point")
        when :source
          verdict(effect, stage, :reversible, :select_revision,
                  "a prior revision may be selected for a NEW build; this restores no runtime state, " \
                  "generated data, or external effect")
        when :oci_image
          verdict(effect, stage, :fork_reversible, :reinstantiate_verified_image,
                  "a verified release image may be re-instantiated; this is deployment selection, " \
                  "not domain rollback")
        when :host_volume
          host_volume_verdict(effect, stage, auth)
        when :snapshot_image
          snapshot_verdict(effect, stage, auth, unclosed)
        else
          refuse(:unknown_stage, "no classification rule for stage #{stage.inspect}")
        end
      end

      # A volume NEVER rolls back by image selection. The best it can offer is a
      # separately declared clone, or reconstruction from retained truth.
      def host_volume_verdict(effect, stage, auth)
        if auth[:clone_evidence]
          return verdict(effect, stage, :compensable, :declared_volume_clone,
                         "a separately declared consistent volume clone can restore this; image selection cannot")
        end
        if replayable?(auth[:role]) && !blank?(auth[:reconstructable_from])
          return verdict(effect, stage, :compensable, :reconstruct_from_authority,
                         "the volume holds replayable state reconstructable from retained truth; " \
                         "image selection still does not restore it")
        end

        verdict(effect, stage, :irreversible, :not_by_image_selection,
                "a mutable host volume escapes image selection and no clone or reconstruction evidence was supplied")
      end

      # The narrow transactional-materialization case, and its three refusals.
      def snapshot_verdict(effect, stage, auth, unclosed)
        role = auth[:role]
        return refuse(:unclassified_store_authority,
                      "the captured store declares no authority role; declare it materialization, projection, " \
                      "index, cache, or authoritative") if role.nil?

        return refuse(:sole_authority_store,
                      "the captured store is the SOLE AUTHORITY for domain facts; forking it would discard " \
                      "Plane B truth, which must stay append-only") if role.to_sym == :authoritative

        return refuse(:unclassified_store_authority,
                      "#{role.inspect} is not a known store role") unless Vocabulary::STORE_ROLES.include?(role.to_sym)

        return refuse(:domain_truth_not_retained,
                      "no retained authority cursor was supplied; a fork may not abandon facts that exist " \
                      "only inside the snapshot") if blank?(auth[:reconstructable_from])

        return refuse(:external_effect_unclosed,
                      "#{unclosed.size} external effect(s) lack closure: " \
                      "#{unclosed.map { |e| e[:id] }.join(', ')}") if unclosed.any?

        verdict(effect, stage, :fork_reversible, :fork_and_activate,
                "replayable state with a retained authority cursor and closed external effects may be " \
                "fork-activated -- subject to the full C1-C9 contract")
      end

      def accepted_placement(placement)
        return refuse(:unplaced_target, "classification requires an accepted Placement.declare result") unless placement.is_a?(Hash)
        return refuse(:unplaced_target, "placement was refused: #{placement[:reason]}") unless placement[:ok]
        return refuse(:unplaced_target, "placement result carries no placement") unless placement[:placement].is_a?(Hash)

        placement
      end

      def closed?(effect)
        return false unless effect.is_a?(Hash)

        %i[absent idempotently_fenced compensable irreversible].include?(effect[:closure])
      end

      def replayable?(role) = !role.nil? && Vocabulary::REPLAYABLE_ROLES.include?(role.to_sym)

      def verdict(effect, stage, classification, rollback, because)
        { ok: true, effect: effect, stage: stage, classification: classification, rollback: rollback,
          because: because,
          conditions_required: (classification == :fork_reversible ? Vocabulary::CONDITION_IDS : []) }
      end
      private_class_method :verdict

      def blank?(v) = v.nil? || v.to_s.strip.empty?

      def refuse(reason, because) = { ok: false, classification: :refused, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
