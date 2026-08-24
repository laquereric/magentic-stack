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
                  "but it is not a durable rollback point", role: auth[:role])
        when :source
          verdict(effect, stage, :reversible, :select_revision,
                  "a prior revision may be selected for a NEW build; this restores no runtime state, " \
                  "generated data, or external effect", role: auth[:role])
        when :oci_image
          verdict(effect, stage, :fork_reversible, :reinstantiate_verified_image,
                  "a verified release image may be re-instantiated; this is deployment selection, " \
                  "not domain rollback", role: auth[:role])
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
                         "a separately declared consistent volume clone can restore this; image selection cannot",
                         role: auth[:role])
        end
        if replayable?(auth[:role]) && !blank?(auth[:reconstructable_from])
          return verdict(effect, stage, :compensable, :reconstruct_from_authority,
                         "the volume holds replayable state reconstructable from retained truth; " \
                         "image selection still does not restore it", role: auth[:role])
        end

        verdict(effect, stage, :irreversible, :not_by_image_selection,
                "a mutable host volume escapes image selection and no clone or reconstruction evidence was supplied",
                role: auth[:role])
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
                "fork-activated -- subject to the full C1-C9 contract", role: role)
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

      def verdict(effect, stage, classification, rollback, because, role: nil)
        # Only a fork_reversible verdict is a Plane C materialization. Everything
        # else is reversible by some OTHER means, or not at all.
        materialization = classification == :fork_reversible

        { ok: true, effect: effect, stage: stage, classification: classification, rollback: rollback,
          because: because,
          # What the caller declared this store to be, carried through. Without it,
          # a declared clone of Plane B truth and a fork of derived state read
          # identically -- both { ok: true, classification: :compensable } -- and
          # they are not the same act.
          authority_role: (role.respond_to?(:to_sym) ? role.to_sym : nil),
          # ok: true means "this classification is sound", NOT "you have a rollback          # point". Callers asking the second question should read this key, which
          # answers it directly instead of leaving it to be inferred from a green
          # envelope.
          materialization: materialization,
          conditions_required: (materialization ? Vocabulary::CONDITION_IDS : []) }
      end
      private_class_method :verdict

      def blank?(v) = v.nil? || v.to_s.strip.empty?

      def refuse(reason, because) = { ok: false, classification: :refused, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
