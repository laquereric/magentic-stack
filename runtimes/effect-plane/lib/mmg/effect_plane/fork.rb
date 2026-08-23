# frozen_string_literal: true
module Mmg
  module EffectPlane
    # Fork activation -- the ONLY legitimate form of Plane C rollback.
    #
    # An approved activation creates a NEW materialized branch. It does not
    # mutate the selected snapshot and does not erase the branch that was
    # previously active. Both remain addressable; the fork itself is an appended
    # fact. That is what makes this a fork rather than a rewind.
    module Fork
      module_function

      EVENT_TYPE = :EffectForkActivated

      # A writable mount that is simply left attached is the classic false
      # rollback: the image looks restored while the volume never moved.
      VOLUME_DISPOSITIONS = %i[fresh_branch_seed branch_seeded excluded immutable_input].freeze

      REASONS = %i[operator_selected_recovery_point
                   failed_materialization
                   policy_revocation
                   harness_checkpoint_discard].freeze

      def activation_event(branch:, parent_snapshot:, selected_snapshot:, reason:, authority_cursor:,
                           volume_disposition:)
        return refuse(:branch_missing, "an activation must name its branch") if blank?(branch)
        return refuse(:parent_snapshot_missing, "an activation must name the currently active parent") if blank?(parent_snapshot)
        return refuse(:selected_snapshot_missing, "an activation must name the snapshot being selected") if blank?(selected_snapshot)

        if parent_snapshot.to_s == selected_snapshot.to_s
          return refuse(:no_op_activation, "parent and selected snapshot are identical; nothing would change")
        end

        # C1 again, at the moment it matters most.
        if blank?(authority_cursor)
          return refuse(:domain_truth_not_retained,
                        "an activation must name the retained Plane B boundary it is reconstructable from")
        end
        unless REASONS.include?(reason)
          return refuse(:unknown_reason, "#{reason.inspect} is not one of #{REASONS.join(', ')}")
        end
        unless VOLUME_DISPOSITIONS.include?(volume_disposition)
          return refuse(:unresolved_writable_volume,
                        "volume_disposition #{volume_disposition.inspect} leaves writable state unresolved; " \
                        "instantiating a prior image with the original RW volume still attached is not a rollback")
        end

        { ok: true, event: {
          type: EVENT_TYPE, branch: branch, parent_snapshot: parent_snapshot,
          selected_snapshot: selected_snapshot, authority_cursor: authority_cursor,
          reason: reason, volume_disposition: volume_disposition
          # activated_at is supplied by the event owner, not by this gem.
        } }
      end

      # An activation that was not appended did not happen (C8).
      def verify_activation(event:, append_receipt:)
        ev = event.is_a?(Hash) && event[:event].is_a?(Hash) ? event[:event] : event
        return refuse(:no_event, "expected an activation event") unless ev.is_a?(Hash)
        return refuse(:no_event, "event is not an #{EVENT_TYPE}") unless ev[:type] == EVENT_TYPE

        r = append_receipt
        return refuse(:fork_not_recorded, "no append receipt supplied") unless r.is_a?(Hash)

        mismatched = %i[branch parent_snapshot selected_snapshot].reject { |k| r[k].to_s == ev[k].to_s }
        if mismatched.any?
          return refuse(:fork_not_recorded,
                        "the append receipt does not match the proposed activation on: #{mismatched.join(', ')}")
        end
        return refuse(:fork_not_recorded, "the append receipt carries no event reference") if blank?(r[:event_ref])

        { ok: true, activated: true, event_ref: r[:event_ref], branch: ev[:branch] }
      end

      # ADDRESSABLE is not ACTIVATABLE. A snapshot retained for audit may still
      # fail current policy or provenance, and the plane must preserve that
      # distinction rather than reporting it as missing.
      def activatable?(snapshot:, retention:, provenance:)
        return refuse(:no_snapshot, "expected a snapshot digest") if blank?(snapshot)

        ret = retention.is_a?(Hash) ? retention : {}
        unless ret[:retained]
          return { ok: true, addressable: false, activatable: false, reason: :snapshot_collected,
                   because: "the snapshot is no longer retained" }
        end

        adm = Snapshot.admissibility(provenance)
        unless adm[:ok] && adm[:admissible]
          return { ok: true, addressable: true, activatable: false,
                   reason: (adm[:ok] ? :provenance_not_admissible : adm[:reason]),
                   because: "retained and addressable for audit, but not activatable: #{adm[:because]}" }
        end

        { ok: true, addressable: true, activatable: true,
          because: "retained with admissible provenance" }
      end

      def blank?(v) = v.nil? || v.to_s.strip.empty?

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
