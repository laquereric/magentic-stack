# frozen_string_literal: true

require "json"

module Vv
  module Perch
    # Stage 3. F5: "Every climb writes a freeze record listing what it depends
    # on. A proposed change at rung j shows the reversal cost for everything
    # above it BEFORE the author accepts. The change can still be made; it is
    # just never a surprise."
    #
    # The first cut had the graph and none of the pricing: cascade_from returned
    # the affected set, and cost_shown_at_climb / climbed_at had no writer at
    # all -- columns only specs filled in. A cascade with no cost does not
    # satisfy F5, because "what else this touches" is not "what it will cost
    # whom".
    class Freeze < Record
      RUNGS = (0..4).to_a.freeze

      # perchv2 6.1, verbatim in structure: each rung names a reversal cost and
      # WHO BEARS IT. The bearer is the point -- a change at rung 3 is cheap for
      # the person making it and expensive for the ML team, and F5 exists so
      # that asymmetry is visible before the decision, not after.
      BEARERS = {
        0 => { cost: "minutes", bearer: "building team" },
        1 => { cost: "hours", bearer: "building team + sibling slices" },
        2 => { cost: "days", bearer: "DataModeling team + consumers" },
        3 => { cost: "gpu_days", bearer: "Fledge / ML team" },
        4 => { cost: "re_signature", bearer: "responsible humans" }
      }.freeze

      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id
      has_many :edges, class_name: "Vv::Perch::FreezeEdge", foreign_key: :freeze_id,
                       inverse_of: :rung_freeze, dependent: :destroy
      has_many :dependencies, through: :edges, source: :depends_on_freeze

      attr_accessor :climbing

      validates :rung, presence: true, inclusion: { in: RUNGS }
      validate :subject_is_not_a_draft
      validate :cost_shown_is_write_once

      # O2: no draft namespace. A freeze names a released artifact.
      DRAFT_MARK = /(?:^|[.\-\/_])draft(?:$|[.\-\/_])/i

      # Current cascade cost is a QUERY, never a column. cost_shown_at_climb
      # is the record of what the climber was shown; it is never recomputed.
      def self.cascade_from(freeze)
        seen = {}
        walk = lambda do |id|
          return if seen[id]

          seen[id] = true
          FreezeEdge.where(depends_on_freeze_id: id).find_each do |edge|
            walk.call(edge.freeze_id)
          end
        end
        walk.call(freeze.id)
        seen.delete(freeze.id)
        where(id: seen.keys)
      end

      # What a change HERE costs, computed now. Everything in it is derived from
      # the graph; nothing is stored.
      #
      # NO INVENTED MAGNITUDES. perchv2 6.3 shows `gpu_hours: 180`, and this
      # gem has no basis for that number -- no training history, no signer
      # roster. Reporting a made-up 180 would be worse than reporting none,
      # because it would be acted on. What IS knowable is counted: how many
      # frozen decisions sit above this one, at which rungs, and therefore which
      # teams get the bill.
      def self.price(freeze)
        affected = cascade_from(freeze).to_a
        by_rung = affected.group_by(&:rung).transform_values(&:length)
        slices = affected.map(&:slice_id).uniq

        {
          "freeze_id" => freeze.id,
          "rung" => freeze.rung,
          "affected" => affected.length,
          "by_rung" => by_rung.sort.to_h,
          "bearers" => by_rung.keys.sort.filter_map { |r| BEARERS[r] }
                              .map { |b| b[:bearer] }.uniq,
          "reversal_costs" => by_rung.keys.sort.filter_map { |r| BEARERS[r]&.dig(:cost) }.uniq,
          "linked_slices" => slices,
          "re_signature_required" => by_rung.key?(4),
          "redistill_required" => by_rung.key?(3),
          "magnitudes" => "not estimated: this gem holds no training history or signer roster. " \
                          "Counts and bearers are measured; hours are not"
        }
      end

      def price_now = self.class.price(self)

      # THE ONLY WRITER of cost_shown_at_climb and climbed_at.
      #
      # Pricing and acceptance are one operation on purpose. If a caller could
      # create a Freeze directly and stamp the cost afterwards, the record would
      # say "this is what I was shown" about something nobody was shown -- and
      # that record is the entire evidentiary value of F5.
      def self.climb!(sized_slice:, rung:, depends_on: [], climbed_by_id: nil, **attrs)
        f = new(sized_slice: sized_slice, rung: rung, **attrs)
        f.climbing = true
        outcome = nil

        transaction do
          unless f.save
            outcome = Envelope.refuse(f.errors.first&.type.to_s.presence || "invalid_freeze",
                                      f.errors.full_messages.join("; "))
            raise ActiveRecord::Rollback
          end

          Array(depends_on).each do |dep|
            edge = FreezeEdge.new(rung_freeze: f, depends_on_freeze: dep)
            next if edge.save

            outcome = Envelope.refuse(Refusals::FREEZE_DEPENDS_ON_ITSELF,
                                      edge.errors.full_messages.join("; "))
            raise ActiveRecord::Rollback
          end

          shown = price(f)
          f.update_columns(
            cost_shown_at_climb: JSON.generate(shown),
            climbed_at: Time.now.utc,
            climbed_by_id: climbed_by_id
          )
          outcome = Envelope.ok(freeze_id: f.id, rung: f.rung, shown: shown)
        end

        outcome
      end

      # F6: descending is allowed, and the cascade then applies. Priced the same
      # way, because moving a decision DOWN a rung is still a change everything
      # above it has to absorb.
      def descend!(to:, now: Time.now.utc)
        return Envelope.refuse(Refusals::CLIMB_NOT_MINTED_HERE,
                               "rung #{to} is not 0..4") unless RUNGS.include?(to)
        return Envelope.refuse(Refusals::CLIMB_NOT_MINTED_HERE,
                               "descend! goes down; #{rung} -> #{to} does not") unless to < rung

        shown = price_now
        self.climbing = true
        update!(rung: to)
        update_columns(climbed_at: now)
        Envelope.ok(freeze_id: id, rung: to, shown: shown)
      end

      def cost_shown
        raw = cost_shown_at_climb.to_s
        return nil if raw.empty?

        JSON.parse(raw)
      rescue JSON::ParserError
        raw
      end

      private

      def subject_is_not_a_draft
        ref = subject_ref.to_s
        return if ref.empty?
        return unless DRAFT_MARK.match?(ref) || ref.end_with?("-draft")

        errors.add(:subject_ref, Refusals::DRAFT_NAMESPACE_UNDECIDED)
      end

      # 5.3: cost_shown_at_climb is EVIDENCE ABOUT A PAST DECISION. It records
      # what the climber was shown when they accepted, so it is immutable for
      # the same reason a dated measurement is never rewritten. The current cost
      # is `price_now`, and conflating the two is how F5 turns into a memo.
      def cost_shown_is_write_once
        return unless will_save_change_to_cost_shown_at_climb?
        return if climbing
        return if cost_shown_at_climb_was.nil? || cost_shown_at_climb_was.to_s.empty?

        errors.add(:cost_shown_at_climb, Refusals::COST_SHOWN_IS_A_RECORD)
      end
    end
  end
end
