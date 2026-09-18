# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::CalCom::Cpcp do
  def ok(data = {})
    { ok: true, data: data }
  end

  def client_with(&handler)
    transport = Vv::CalCom::FakeTransport.new(&handler)
    Vv::CalCom::Client.new(token: "cal_test_x", transport: transport)
  end

  def never_dial
    client_with { |_| raise "must not hit the wire" }
  end

  describe "register!" do
    it "is absent without rails-cpcp" do
      expect(described_class.register![:reason]).to eq(:cpcp_absent)
    end

    it "names every operation it projects" do
      expect(described_class::OPERATIONS).to contain_exactly(
        "booking.create", "booking.get", "booking.list",
        "booking.confirm", "booking.decline", "booking.reschedule", "booking.cancel",
        "slot.list", "slot.reserve",
        "event_type.list", "event_type.get",
        "webhook.verify",
        "embed.url"
      )
    end
  end

  describe "Bookings" do
    let(:handlers) { described_class::Bookings }

    it "creates with camelCase wire keys" do
      seen = nil
      client = client_with { |call| seen = call; ok("uid" => "b1") }
      r = handlers.create(
        {
          "eventTypeId" => 123, "start" => "2026-09-20T15:00:00Z",
          "attendeeName" => "Ada", "attendeeEmail" => "ada@example.com",
          "attendeeTimeZone" => "America/New_York"
        },
        client: client
      )
      expect(r[:ok]).to be(true)
      expect(seen[:method]).to eq(:post)
      expect(seen[:path]).to eq("/v2/bookings")
      expect(seen[:body]).to include("eventTypeId" => 123, "start" => "2026-09-20T15:00:00Z")
      expect(seen[:body]["attendee"]).to include(
        "name" => "Ada", "email" => "ada@example.com", "timeZone" => "America/New_York"
      )
    end

    it "omits the attendee block when no attendee params are given" do
      seen = nil
      client = client_with { |call| seen = call; ok("uid" => "b1") }
      handlers.create({ "eventTypeId" => 123, "start" => "2026-09-20T15:00:00Z" }, client: client)
      expect(seen[:body]).not_to have_key("attendee")
    end

    it "gets one booking by uid" do
      seen = nil
      client = client_with { |call| seen = call; ok("uid" => "b1") }
      r = handlers.get({ "uid" => "b1" }, client: client)
      expect(r[:ok]).to be(true)
      expect(seen[:method]).to eq(:get)
      expect(seen[:path]).to eq("/v2/bookings/b1")
    end

    it "refuses get without a uid before the wire" do
      r = handlers.get({}, client: never_dial)
      expect(r[:ok]).to be(false)
      expect(r[:reason]).to eq(:booking_required)
    end

    it "lists with an optional status filter" do
      seen = nil
      client = client_with { |call| seen = call; ok([]) }
      handlers.list({ "status" => "upcoming" }, client: client)
      expect(seen[:path]).to eq("/v2/bookings")
      expect(seen[:query]).to include("status" => "upcoming")
    end

    it "confirms by uid" do
      seen = nil
      client = client_with { |call| seen = call; ok("uid" => "b1") }
      handlers.confirm({ "uid" => "b1" }, client: client)
      expect(seen[:path]).to eq("/v2/bookings/b1/confirm")
    end

    it "declines with a reason" do
      seen = nil
      client = client_with { |call| seen = call; ok("uid" => "b1") }
      handlers.decline({ "uid" => "b1", "reason" => "host unavailable" }, client: client)
      expect(seen[:path]).to eq("/v2/bookings/b1/decline")
      expect(seen[:body]).to include("reason" => "host unavailable")
    end

    it "reschedules to a new start" do
      seen = nil
      client = client_with { |call| seen = call; ok("uid" => "b1") }
      handlers.reschedule({ "uid" => "b1", "start" => "2026-09-21T15:00:00Z" }, client: client)
      expect(seen[:path]).to eq("/v2/bookings/b1/reschedule")
      expect(seen[:body]).to include("start" => "2026-09-21T15:00:00Z")
    end

    it "cancels with a cancellation reason" do
      seen = nil
      client = client_with { |call| seen = call; ok("uid" => "b1") }
      handlers.cancel({ "uid" => "b1", "reason" => "travel" }, client: client)
      expect(seen[:path]).to eq("/v2/bookings/b1/cancel")
      expect(seen[:body]).to include("cancellationReason" => "travel")
    end
  end

  describe "Slots" do
    let(:handlers) { described_class::Slots }

    it "lists slots for an event type in a range" do
      seen = nil
      client = client_with { |call| seen = call; ok([]) }
      handlers.list(
        { "eventTypeId" => 10, "start" => "2026-09-20", "end" => "2026-09-21" },
        client: client
      )
      expect(seen[:path]).to eq("/v2/slots")
      expect(seen[:query]).to include("eventTypeId" => 10, "start" => "2026-09-20", "end" => "2026-09-21")
    end

    it "refuses list without a time range before the wire" do
      r = handlers.list({ "eventTypeId" => 10 }, client: never_dial)
      expect(r[:reason]).to eq(:start_required)
    end

    it "reserves with eventTypeId and slotStart" do
      seen = nil
      client = client_with { |call| seen = call; ok("uid" => "r1") }
      handlers.reserve(
        { "eventTypeId" => 10, "slotStart" => "2026-09-20T15:00:00Z" },
        client: client
      )
      expect(seen[:path]).to eq("/v2/slots/reservations")
      expect(seen[:body]).to include("eventTypeId" => 10, "slotStart" => "2026-09-20T15:00:00Z")
    end
  end

  describe "EventTypes" do
    let(:handlers) { described_class::EventTypes }

    it "gets one event type by id" do
      seen = nil
      client = client_with { |call| seen = call; ok("id" => 123) }
      handlers.get({ "id" => 123 }, client: client)
      expect(seen[:path]).to eq("/v2/event-types/123")
    end

    it "refuses get without an id before the wire" do
      r = handlers.get({}, client: never_dial)
      expect(r[:reason]).to eq(:event_type_required)
    end
  end

  describe "local handlers (no network)" do
    it "webhook.verify accepts a locally-signed payload" do
      secret = "whsec_test_key"
      body = JSON.generate(
        "triggerEvent" => "BOOKING_CREATED",
        "payload" => { "uid" => "b1", "status" => "ACCEPTED" }
      )
      sig = Vv::CalCom::Webhooks.signed_payload(secret, body)
      r = Vv::CalCom::Webhooks.verify(
        body,
        { "X-Cal-Signature-256" => sig },
        signing_secret: secret
      )
      expect(r[:ok]).to be(true)
      expect(r[:type]).to eq("BOOKING_CREATED")
      expect(r[:event_id]).to eq("b1")
    end

    it "webhook.verify refuses a forged signature" do
      r = Vv::CalCom::Webhooks.verify(
        JSON.generate("triggerEvent" => "BOOKING_CREATED"),
        { "X-Cal-Signature-256" => "0" * 64 },
        signing_secret: "whsec_test_key"
      )
      expect(r[:ok]).to be(false)
      expect(r[:reason]).to eq(:webhook_invalid)
    end

    it "embed.url builds the public booking URL" do
      r = Vv::CalCom::Embed.booking_url("ada", "intro")
      expect(r).to eq({ ok: true, data: "https://cal.com/ada/intro" })
    end
  end
end
