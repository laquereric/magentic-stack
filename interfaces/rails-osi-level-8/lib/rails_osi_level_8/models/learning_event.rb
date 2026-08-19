# frozen_string_literal: true

module RailsOsiLevel8
  class LearningEvent < Record
    self.table_name = "osi_l8_learning_events"
    include GovernedRecord

    EVENT_KINDS = %w[
      drift_detected
      hypothesis_recorded
      experiment_started
      decision_recorded
      profile_change_proposed
      profile_change_accepted
      profile_change_rejected
    ].freeze
    STATUSES = %w[open accepted rejected superseded].freeze

    # evidence_cids / proposal_json may be empty — do not use presence ({} / [] are blank).
    validates :learning_cycle_id, :event_kind, :status, presence: true
    validates :event_kind, inclusion: { in: EVENT_KINDS }
    validates :status, inclusion: { in: STATUSES }
  end
end
