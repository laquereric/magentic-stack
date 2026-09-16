# frozen_string_literal: true

module Vv
  module Perch
    class Slice < Record
      WORKSHOP_STATES = %w[compiled merged deployed trained signed rehearsed].freeze
      FORBIDDEN_RECEIVER_PREFIXES = %w[perch: fledge:].freeze
      FORBIDDEN_RECEIVER_KEYS = %w[gate building_team datamodeling].freeze

      belongs_to :use_case, class_name: "Vv::Perch::UseCase"
      belongs_to :release_group, class_name: "Vv::Perch::ReleaseGroup", optional: true
      belongs_to :receiver, class_name: "Vv::Base::Actor",
                            foreign_key: :receiver_id, optional: true

      has_many :slice_steps, class_name: "Vv::Perch::SliceStep", foreign_key: :slice_id,
                            inverse_of: :sized_slice, dependent: :destroy
      has_many :steps, through: :slice_steps, source: :step
      has_many :requirements, class_name: "Vv::Perch::SliceRequirement", foreign_key: :slice_id,
                              inverse_of: :sized_slice, dependent: :destroy
      has_many :required_slices, through: :requirements, source: :requires_slice
      has_many :outward_signals, class_name: "Vv::Perch::OutwardSignal", foreign_key: :slice_id,
                                 inverse_of: :sized_slice, dependent: :destroy
      has_many :wholeness_findings, class_name: "Vv::Perch::WholenessFinding", foreign_key: :slice_id,
                                    inverse_of: :sized_slice, dependent: :destroy
      has_many :freezes, class_name: "Vv::Perch::Freeze", foreign_key: :slice_id,
                         inverse_of: :sized_slice, dependent: :destroy
      has_many :slice_methods, class_name: "Vv::Perch::SliceMethod", foreign_key: :slice_id,
                               inverse_of: :sized_slice, dependent: :destroy

      # Transient, never a column: the release capability ReleaseGroup#release!
      # hands to a member for the duration of one save.
      attr_accessor :released_by_group

      validates :slice_key, presence: true
      validate :receiver_predates_the_cut
      validate :terminating_aim_is_outward
      validate :released_at_not_minted_here

      # O1: all effect steps by_receiver → advisory, no envelope, no Gate.
      def advisory?
        effect_steps = steps.select { |st| st.kind == "effect" }
        return true if effect_steps.empty?

        effect_steps.all? { |st| st.effect_binding&.mode == "by_receiver" }
      end

      def needs_envelope?
        !advisory?
      end

      # T4. actor_id is bound by the seam (ActorBinding), never minted here.
      def restate!(aim:, receiver:, actor_id:)
        if aim.to_s.strip.empty? || receiver.to_s.strip.empty? || actor_id.nil?
          return Envelope.refuse(
            Refusals::T4,
            "a non-engineering owner restates Aim and Receiver in their own words"
          )
        end

        update!(aim_restated: aim.to_s, receiver_restated: receiver.to_s, restated_by_id: actor_id)
        Envelope.ok(slice_key: slice_key)
      end

      # §12.1: done is computed, and is not a column. Released, instrumented,
      # and REPORTING -- all three, and reporting means an outward window has
      # actually closed, not that someone stamped a date.
      def done?(now: Time.now.utc)
        released_at.present? &&
          outward_signals.any? &&
          outward_signals.all? { |s| s.maturity(now: now) == :reporting }
      end

      # NO `succeeding?` HERE, deliberately. §12.1 draws two lines, not one: a
      # slice is DONE when it is released and reporting, and SUCCEEDING when the
      # signal "holds at the level the business owner declared at P4". Stage 2
      # gives this gem the first; it cannot give the second, because no declared
      # level is stored anywhere -- P4 is stage 4.
      #
      # Writing succeeding? now would mean inventing a sentinel for "met" and
      # comparing readings against it. That invents the contract instead of
      # reading it, and a success number derived from a guessed vocabulary is
      # worse than an absent one. It lands with the declared level.

      # What a reader actually wants: which of the three states, and why.
      def signal_state(now: Time.now.utc)
        return :not_instrumented if outward_signals.none? { |s| !s.instrumented_at.nil? }

        states = outward_signals.map { |s| s.maturity(now: now) }
        return :reporting if states.all? { |st| st == :reporting }

        states.include?(:not_instrumented) ? :not_instrumented : :pending
      end

      def ready_waiting_on_group?
        gate_passed_at.present? && released_at.nil?
      end

      def pass_gate!
        update!(gate_passed_at: Time.now.utc)
      end

      private

      def receiver_predates_the_cut
        return if receiver_id.nil?

        role = receiver_role_key
        return if role.nil?

        forbidden = FORBIDDEN_RECEIVER_KEYS.include?(role) ||
                    FORBIDDEN_RECEIVER_PREFIXES.any? { |p| role.start_with?(p) }
        return unless forbidden

        errors.add(:receiver_id, Refusals::T1)
      end

      def receiver_role_key
        return receiver.role_key if receiver.respond_to?(:role_key)

        nil
      rescue NameError, ActiveRecord::StatementInvalid
        nil
      end

      def terminating_aim_is_outward
        text = terminates_at.to_s.downcase
        return if text.empty?
        return unless WORKSHOP_STATES.any? { |w| text.split(/\W+/).include?(w) }

        errors.add(:terminates_at, Refusals::T2)
      end

      def released_at_not_minted_here
        return unless will_save_change_to_released_at?
        return if released_at.nil?
        # The capability is handed to THIS record by the group that owns it,
        # not read from ambient state. It was `Thread.current[:perch_releasing]`,
        # which any code could set before writing the column -- an invariant
        # anyone may switch off is a comment. The group must also be this
        # slice's own, so one group cannot stamp another's member.
        return if released_by_group.is_a?(ReleaseGroup) &&
                  !release_group_id.nil? &&
                  released_by_group.id == release_group_id

        errors.add(:released_at, Refusals::RELEASE)
      end
    end
  end
end
