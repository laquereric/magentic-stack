# frozen_string_literal: true

# Derive metadata from BACK's operation journal and retain it. Does not
# copy journal rows. Does not call BACK over HTTP (row 72).
module Bus
  class Projector
    SOURCE = "operation_journal"

    def self.latest
      row = retain!
      {
        "source" => row.source,
        "at" => row.projected_at.utc.iso8601,
        "derived" => JSON.parse(row.payload_json)
      }
    end

    def self.retain!
      BusProjection.create!(
        source: SOURCE,
        payload_json: JSON.generate(derive),
        projected_at: Time.now.utc
      )
    end

    def self.derive
      conn = ActiveRecord::Base.connection
      unless conn.data_source_exists?("osi_l8_operation_journal_entries")
        return { "journal" => "absent", "by_kind" => {}, "count" => 0 }
      end
      by = RailsOsiLevel8::OperationJournalEntry.group(:event_kind).count
      { "journal" => SOURCE, "by_kind" => by, "count" => by.values.sum }
    end
  end
end
