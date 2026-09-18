# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::CalCom::Keys do
  describe ".camel_key" do
    it "camelizes snake_case" do
      expect(described_class.camel_key(:event_type_id)).to eq("eventTypeId")
      expect(described_class.camel_key("time_zone")).to eq("timeZone")
      expect(described_class.camel_key(:subscriber_url)).to eq("subscriberUrl")
      expect(described_class.camel_key(:booking_fields_responses)).to eq("bookingFieldsResponses")
    end

    it "leaves already-camel and bare words alone" do
      expect(described_class.camel_key("eventTypeId")).to eq("eventTypeId")
      expect(described_class.camel_key(:start)).to eq("start")
    end
  end

  describe ".to_wire" do
    it "camelizes request keys recursively" do
      wire = described_class.to_wire({
        event_type_id: 123,
        start: "2026-09-20T15:00:00Z",
        attendee: { name: "Ada", time_zone: "America/New_York", phone_number: "+1" }
      })
      expect(wire).to eq(
        "eventTypeId" => 123,
        "start" => "2026-09-20T15:00:00Z",
        "attendee" => { "name" => "Ada", "timeZone" => "America/New_York", "phoneNumber" => "+1" }
      )
    end

    it "does not camelize booking field response keys" do
      wire = described_class.to_wire({
        event_type_id: 1,
        booking_fields_responses: { "custom_field" => "hello", my_note: "x" }
      })
      expect(wire["bookingFieldsResponses"]).to eq("custom_field" => "hello", "my_note" => "x")
    end

    it "does not camelize metadata keys" do
      wire = described_class.to_wire({ metadata: { "source_app" => "mm" } })
      expect(wire["metadata"]).to eq("source_app" => "mm")
    end
  end

  describe ".compact" do
    it "drops nils so REST bodies stay sparse" do
      expect(described_class.compact(a: 1, b: nil, c: [])).to eq(a: 1, c: [])
    end

    it "treats nil as empty" do
      expect(described_class.compact(nil)).to eq({})
    end
  end
end
