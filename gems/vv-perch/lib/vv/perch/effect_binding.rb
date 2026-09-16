# frozen_string_literal: true

require "json"

module Vv
  module Perch
    # Stage 5. The seam where an approval meets the things it was approved
    # against.
    #
    # perchv2 §7.3 binds an envelope to `freeze_ids` AND to `reaching_bindings`
    # -- the model bound to every method that can reach the effect -- and says
    # "binding to freeze_ids makes invalidation precise. ONLY a change to a
    # freeze record the envelope depends on invalidates it."
    #
    # That second binding is the one this platform already had a conclusion
    # about, recorded in OrinthDistill.md: A DISTILLED MODEL DOES NOT INHERIT
    # THE APPROVAL GIVEN TO ITS TEACHER. §10.2 says the same from the other end
    # -- swapping a teacher-tier binding for a distilled route is a rung-3 climb
    # that ships through the release train, and is rejected if the outward
    # signal degrades even when the eval gate passed.
    #
    # Before this, prod_binding_ref could be swapped with no consequence
    # anywhere. The rule was written in two documents and enforced in none.
    #
    # R1/R2/R3 all bite here, and all three are absences:
    #   no executor and no credential -- BACK is the gate (ADR 0056)
    #   no proposal, decision, or execution rows -- the journal is admission
    #     truth (ADR 0052); this gem stores what an approval was bound to,
    #     never what happened under it
    #   no signature -- the binding is kept so invalidation is computable
    #     without holding the credential that would make it enforceable here
    class EffectBinding < Record
      MODES = %w[by_receiver per_instance envelope simulated_only].freeze

      # The modes that carry an approval which can go stale. by_receiver is a
      # human acting under authority they already hold (O1) and simulated_only
      # executes nothing, so neither can be invalidated by a route swap.
      BINDABLE = %w[per_instance envelope].freeze

      belongs_to :use_case, class_name: "Vv::Perch::UseCase"
      belongs_to :sized_slice, class_name: "Vv::Perch::Slice", foreign_key: :slice_id,
                               optional: true
      belongs_to :responsible, class_name: "Vv::Base::Actor",
                               foreign_key: :responsible_id, optional: true
      has_many :steps, class_name: "Vv::Perch::Step"

      attr_accessor :binding_now

      validates :effect_ref, :mode, presence: true
      validates :mode, inclusion: { in: MODES }
      validate :bound_to_is_write_once
      # No executor column. No credential column. BACK is the gate (R1).

      def bindable? = BINDABLE.include?(mode.to_s)

      # Records what this approval was given against. Only the write path may
      # write it, for the same reason Freeze.climb! is the only writer of
      # cost_shown_at_climb: a snapshot written later describes a moment nobody
      # was standing in.
      def bind!(now: Time.now.utc)
        unless bindable?
          return Envelope.refuse(
            Refusals::APPROVAL_NOT_BINDABLE,
            "mode #{mode.inspect} carries no approval that can go stale; " \
            "by_receiver is existing human authority (O1) and simulated_only executes nothing"
          )
        end
        if sized_slice.nil?
          return Envelope.refuse(
            Refusals::APPROVAL_NOT_BINDABLE,
            "an envelope is per slice (§7.3); this binding names no slice"
          )
        end

        self.binding_now = true
        snapshot = live_state
        update!(bound_to: JSON.generate(snapshot), bound_at: now)
        Envelope.ok(effect_ref: effect_ref, bound_to: snapshot)
      ensure
        self.binding_now = false
      end

      def bound
        raw = bound_to.to_s
        return nil if raw.empty?

        JSON.parse(raw)
      rescue JSON::ParserError
        nil
      end

      # What is true NOW. The pair with `bound` is the same two-objects shape as
      # cost_shown_at_climb / price_now: one is a record, one is a query, and
      # conflating them is how invalidation becomes a memo.
      def live_state
        {
          "freeze_rungs" => (sized_slice&.freezes || []).to_h { |f| [f.id.to_s, f.rung] },
          "reaching_bindings" => (sized_slice&.slice_methods || [])
            .to_h { |m| [m.name.to_s, m.prod_binding_ref.to_s] }
        }
      end

      # §7.3, precisely: only a change to something this approval DEPENDS ON
      # counts. A new freeze on the slice, or a new method, is not drift --
      # nobody approved against it, so it cannot invalidate what they approved.
      def drift
        was = bound
        return { "unbound" => true } if was.nil?

        now = live_state
        changed_freezes = (was["freeze_rungs"] || {}).filter_map do |id, rung|
          current = now["freeze_rungs"][id]
          next if current == rung

          { "freeze_id" => id, "was" => rung, "now" => current }
        end
        changed_routes = (was["reaching_bindings"] || {}).filter_map do |name, route|
          current = now["reaching_bindings"][name]
          next if current == route

          { "method" => name, "was" => route, "now" => current }
        end

        out = {}
        out["freezes"] = changed_freezes if changed_freezes.any?
        out["routes"] = changed_routes if changed_routes.any?
        out
      end

      def valid_now? = bindable? ? drift.empty? : true

      # The named conclusion, made answerable. A route swap does not carry the
      # approval across; it needs a new one.
      def invalidation
        d = drift
        return nil if d.empty?
        return Envelope.refuse(Refusals::APPROVAL_NOT_BINDABLE,
                               "this approval was never bound") if d["unbound"]

        if d["routes"]&.any?
          swapped = d["routes"].map { |r| "#{r['method']}: #{r['was']} -> #{r['now']}" }.join("; ")
          return Envelope.refuse(
            Refusals::APPROVAL_NOT_INHERITED,
            "a model bound to a reaching method changed (#{swapped}). A distilled model does not " \
            "inherit the approval given to its teacher; §10.2 makes the swap a rung-3 climb that " \
            "ships through the release train"
          )
        end

        moved = d["freezes"].map { |f| "frz #{f['freeze_id']}: rung #{f['was']} -> #{f['now']}" }.join("; ")
        Envelope.refuse(
          Refusals::ENVELOPE_INVALIDATED,
          "a freeze this approval was bound to moved (#{moved})"
        )
      end

      private

      # A snapshot rewritten after the fact is not a record of what was
      # approved. Same rule as cost_shown_at_climb (§5.3).
      def bound_to_is_write_once
        return unless will_save_change_to_bound_to?
        return if binding_now
        return if bound_to_was.nil? || bound_to_was.to_s.empty?

        errors.add(:bound_to, Refusals::COST_SHOWN_IS_A_RECORD)
      end
    end
  end
end
