# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::CalCom::Client do
  def ok(data = {})
    { ok: true, data: data }
  end

  def client_with(&handler)
    transport = Vv::CalCom::FakeTransport.new(&handler)
    described_class.new(token: "cal_test_x", transport: transport)
  end

  describe "refusals before the wire" do
    it "refuses a missing booking uid" do
      c = client_with { |_| ok }
      r = c.confirm_booking("")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:booking_required)
    end

    it "refuses a missing event type id" do
      c = client_with { |_| ok }
      r = c.get_event_type(nil)
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:event_type_required)
    end

    it "refuses list_slots without a time range" do
      c = client_with { |_| ok }
      r = c.list_slots(event_type_id: 1)
      expect(r[:reason]).to eq(:start_required)
      r = c.list_slots(event_type_id: 1, start: "2026-09-20")
      expect(r[:reason]).to eq(:end_required)
    end
  end

  describe "bookings" do
    it "lists bookings on GET /v2/bookings with the list API version" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok([{ "uid" => "b1" }])
      end
      r = c.list_bookings(status: "upcoming", limit: 10)
      expect(r[:ok]).to be true
      expect(seen[:method]).to eq(:get)
      expect(seen[:path]).to eq("/v2/bookings")
      expect(seen[:query]).to include("status" => "upcoming", "limit" => 10)
      expect(seen[:api_version]).to eq(Vv::CalCom::BOOKING_LIST_API_VERSION)
    end

    it "creates a booking with camelCase body keys" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok("uid" => "b1")
      end
      c.create_booking(
        event_type_id: 123,
        start: "2026-09-20T15:00:00Z",
        attendee: { name: "Ada", email: "ada@example.com", time_zone: "America/New_York" },
        booking_fields_responses: { custom_field: "hello" }
      )
      expect(seen[:method]).to eq(:post)
      expect(seen[:path]).to eq("/v2/bookings")
      expect(seen[:auth]).to eq(:optional)
      expect(seen[:api_version]).to eq(Vv::CalCom::BOOKING_API_VERSION)
      expect(seen[:body]).to include(
        "eventTypeId" => 123,
        "start" => "2026-09-20T15:00:00Z"
      )
      expect(seen[:body]["attendee"]).to include("name" => "Ada", "timeZone" => "America/New_York")
      expect(seen[:body]["bookingFieldsResponses"]).to eq("custom_field" => "hello")
    end

    it "confirms, declines, cancels, and reassigns by uid" do
      seen = []
      c = client_with do |call|
        seen << call
        ok("uid" => "b1")
      end
      c.confirm_booking("b1")
      c.decline_booking("b1", reason: "busy")
      c.cancel_booking("b1", cancellation_reason: "travel")
      c.reassign_booking("b1")
      c.reassign_booking("b1", user_id: 42)

      expect(seen.map { |s| s[:path] }).to eq([
        "/v2/bookings/b1/confirm",
        "/v2/bookings/b1/decline",
        "/v2/bookings/b1/cancel",
        "/v2/bookings/b1/reassign",
        "/v2/bookings/b1/reassign/42"
      ])
      expect(seen[2][:body]).to include("cancellationReason" => "travel")
    end
  end

  describe "event types" do
    it "creates an event type with camelized length_in_minutes" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok("id" => 1)
      end
      c.create_event_type(title: "Intro", slug: "intro", length_in_minutes: 30)
      expect(seen[:path]).to eq("/v2/event-types")
      expect(seen[:body]).to include("title" => "Intro", "slug" => "intro", "lengthInMinutes" => 30)
      expect(seen[:api_version]).to eq(Vv::CalCom::EVENT_TYPE_API_VERSION)
    end
  end

  describe "slots" do
    it "lists slots on GET /v2/slots with optional auth" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok({})
      end
      c.list_slots(event_type_id: 10, start: "2026-09-20", end: "2026-09-21", time_zone: "Europe/Rome")
      expect(seen[:path]).to eq("/v2/slots")
      expect(seen[:auth]).to eq(:optional)
      expect(seen[:query]).to include(
        "eventTypeId" => 10,
        "start" => "2026-09-20",
        "end" => "2026-09-21",
        "timeZone" => "Europe/Rome"
      )
      expect(seen[:api_version]).to eq(Vv::CalCom::SLOT_API_VERSION)
    end
  end

  describe "webhooks" do
    it "creates a webhook with camelized subscriber_url" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok("id" => 1)
      end
      c.create_webhook(
        subscriber_url: "https://app.example/hooks",
        active: true,
        triggers: %w[BOOKING_CREATED]
      )
      expect(seen[:path]).to eq("/v2/webhooks")
      expect(seen[:body]).to include(
        "subscriberUrl" => "https://app.example/hooks",
        "active" => true,
        "triggers" => %w[BOOKING_CREATED]
      )
    end
  end

  describe "escape hatch" do
    it "forwards call onto the transport with camelized keys" do
      seen = nil
      c = client_with do |call|
        seen = call
        ok({})
      end
      c.call(:post, "/v2/event-types/1/webhooks", body: { subscriber_url: "https://x" })
      expect(seen[:path]).to eq("/v2/event-types/1/webhooks")
      expect(seen[:body]).to eq("subscriberUrl" => "https://x")
    end
  end
end
