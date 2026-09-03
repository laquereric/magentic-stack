# frozen_string_literal: true

# Derive metadata from BACK's operation journal and retain it. Does not
# copy journal rows. Does not call BACK over HTTP (row 72).
# Reads via ApplicationRecord (primary/domain sqlite, SELECT only);
# writes via BusProjection (bus sqlite on bus-data volume).
module Bus
  class Projector
    SOURCE = "operation_journal"

    # Row 75 contract version. Bump on any BREAKING change: method
    # removed/renamed, required params added, envelope keys removed or
    # renamed, result shape narrowed, projection columns dropped.
    # Additive changes (optional params, new methods, new columns) do not
    # bump. Participants pin to a version and refuse a superseded one;
    # with no versioned consumers yet, the gate pins code to spec.
    CONTRACT_VERSION = 1

    def self.latest
      row = retain!
      {
        "source" => row.source,
        "at" => row.projected_at.utc.iso8601,
        "contract_version" => CONTRACT_VERSION,
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
      conn = ApplicationRecord.connection
      unless conn.data_source_exists?("osi_l8_operation_journal_entries")
        return { "journal" => "absent", "by_kind" => {}, "count" => 0 }
      end
      by = RailsOsiLevel8::OperationJournalEntry.group(:event_kind).count
      { "journal" => SOURCE, "by_kind" => by, "count" => by.values.sum }
    end
  end
end
