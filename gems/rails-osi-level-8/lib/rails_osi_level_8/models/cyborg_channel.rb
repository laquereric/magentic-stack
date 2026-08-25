# frozen_string_literal: true

module RailsOsiLevel8
  class CyborgChannel < Record
    self.table_name = "osi_l8_cyborg_channels"
    include GovernedRecord

    validates :cyborg_iri, :channel_key, :direction, :transport, :channel_status, presence: true
    validates :direction, inclusion: { in: %w[inbound outbound bidirectional] }
    validates :transport, inclusion: { in: %w[cpcp] }
  end
end
