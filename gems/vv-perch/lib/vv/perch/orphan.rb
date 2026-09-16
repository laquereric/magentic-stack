# frozen_string_literal: true

module Vv
  module Perch
    # Stage 4. The orphan ledger.
    #
    # P3: "Purpose is a floor; orphaning is a price. A cut that yields a piece
    # with no receiver is refused. A cut that freezes a decision a sibling could
    # overturn MAY be taken, but only with the liability written down and
    # managed."
    #
    # So this table is not a record that something was orphaned. It is the
    # record that the liability is being MANAGED, and §11.2 lists the seven
    # obligations that constitute managing it. An entry that is open while
    # discharging none of them is the unmanaged liability wearing a ledger
    # entry, which is worse than no entry at all: it reads as handled.
    class Orphan < Record
      # §11.1 draws a line the first cut left as a free string, and the two
      # sides call for opposite responses. A shared decision surface is a
      # dependency to MANAGE. A boundary running through the middle of one
      # purpose -- where neither side can name an aim of its own -- is a
      # boundary to QUESTION, and managing it harder is the wrong answer.
      KINDS = %w[
        cross_team_datamodel
        shared_return_type
        shared_model_route
        shared_effect_owner
        included_subfunction
        boundary_to_question
      ].freeze

      QUESTIONABLE = "boundary_to_question"
      OPEN = "open"
      CLOSED = "closed"
      CLOSE_REASONS = %w[release_group_released cut_changed].freeze

      belongs_to :release_group, class_name: "Vv::Perch::ReleaseGroup", optional: true
      has_many :parties, class_name: "Vv::Perch::OrphanParty", dependent: :destroy

      validates :kind, presence: true, inclusion: { in: KINDS }
      validate :shared_means_two_parties
      validate :open_entry_meets_its_obligations
      validate :closed_entry_says_why

      def open? = status.to_s != CLOSED

      # A boundary to question is recorded so it can be ESCALATED, not so it can
      # be scheduled. §11.1 is explicit that it is "not a dependency to manage",
      # so it is not held to the convergence machinery the others are.
      def questionable? = kind.to_s == QUESTIONABLE

      # §11.2, as data. Every obligation that is not met is named, so the answer
      # to "what does this entry still owe" is a list rather than a judgement.
      def unmet_obligations
        return [] unless open?

        missing = []
        missing << "visible_on_both_boards" if common_parent.to_s.strip.empty?
        missing << "someone_with_standing" if standing_owner_id.nil?
        missing << "accepted_by_both" if accepted_by.to_s.strip.empty?
        missing << "decisions_held_loosely" if reversibility_measures.to_s.strip.empty?
        missing << "learning_arranged" if collaboration_cadence.to_s.strip.empty?
        return missing if questionable?

        missing << "ranked_together" unless rank_together
        missing << "released_together" if release_group_id.nil?
        missing << "kept_close_in_time" if convergence[:start_offset_days].nil?
        missing
      end

      def managed? = unmet_obligations.empty?

      # §11.3: "The two items need to be READY together, not merely started
      # together. Start the one with the slower or more variable cycle time
      # earlier, by roughly the difference in their 85th-percentile cycle
      # times, and revisit as they progress."
      #
      # Derived, never stored. Cycle times move, and a stored offset would be a
      # plan that quietly stopped describing the work -- the same trap as
      # cost_shown_at_climb vs price_now (§5.3), on a different axis.
      def convergence
        known = parties.reject { |p| p.cycle_time_p85_days.nil? }
        return { start_offset_days: nil, start_first: nil, because: "no cycle times recorded" } if known.length < 2

        slowest = known.max_by(&:cycle_time_p85_days)
        fastest = known.min_by(&:cycle_time_p85_days)
        {
          start_offset_days: slowest.cycle_time_p85_days - fastest.cycle_time_p85_days,
          start_first: slowest.item_ref,
          p85: known.to_h { |p| [p.item_ref, p.cycle_time_p85_days] },
          because: "probability of convergence, not a plan; revisit as they progress"
        }
      end

      # Entries close when the release group releases, or when the cut is
      # changed and the dependency disappears. Those are different facts and
      # the ledger keeps which one, because "it closed" without "why" cannot
      # tell a delivered dependency from an abandoned one.
      def close!(reason:, now: Time.now.utc)
        unless CLOSE_REASONS.include?(reason.to_s)
          return Envelope.refuse(
            Refusals::ORPHAN_CLOSE_UNNAMED,
            "close reason must be one of #{CLOSE_REASONS.join(', ')}, got #{reason.inspect}"
          )
        end

        if reason.to_s == "release_group_released" && release_group&.released_at.nil?
          return Envelope.refuse(
            Refusals::ORPHAN_CLOSE_UNNAMED,
            "no release group has released; an entry cannot close on a release that did not happen"
          )
        end

        update!(status: CLOSED, closed_at: now, closed_reason: reason.to_s)
        Envelope.ok(orphan_id: id, closed_reason: reason.to_s)
      end

      private

      # "Shared" is the whole word. One party is a note about a decision, not a
      # decision two boards share.
      def shared_means_two_parties
        return unless persisted? || parties.any?
        return if parties.size >= 2

        errors.add(:parties, Refusals::ORPHAN_NOT_SHARED)
      end

      def open_entry_meets_its_obligations
        return unless open?
        return if unmet_obligations.empty?

        errors.add(:status, Refusals::ORPHAN_OBLIGATIONS_UNMET)
      end

      def closed_entry_says_why
        return if open?
        return if CLOSE_REASONS.include?(closed_reason.to_s)

        errors.add(:closed_reason, Refusals::ORPHAN_CLOSE_UNNAMED)
      end
    end
  end
end
