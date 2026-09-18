# frozen_string_literal: true

module Vv
  module CalCom
    # CPCP projection. No-op when rails-cpcp is absent (canvas pattern).
    #
    # Credentials never travel in params: every handler builds Client.new
    # with no arguments, which reads CAL_API_KEY / CAL_API_URL from the
    # environment. CPCP params are camelCase at the boundary (canvas:
    # operationId, blobDigest); the client camelizes snake_case kwargs
    # onto the Cal.com wire, and nils are compacted before the request.
    #
    # Handlers take an optional client so specs can inject a FakeTransport
    # without touching the network (WebMock disables it in spec_helper).
    module Cpcp
      module_function

      OPERATIONS = %w[
        booking.create booking.get booking.list
        booking.confirm booking.decline booking.reschedule booking.cancel
        slot.list slot.reserve
        event_type.list event_type.get
        webhook.verify
        embed.url
      ].freeze

      def register!
        unless defined?(::RailsCpcp)
          return { ok: false, reason: :cpcp_absent, because: "rails-cpcp is not loaded" }
        end

        ::RailsCpcp.project(model: "Booking") do
          operation "booking.create",
            direction: :push, params: %w[operationId eventTypeId start],
            summary: "Create a booking. Public endpoint; token sent when configured.",
            via: ->(p, _c) { Bookings.create(p) }

          operation "booking.get",
            direction: :pull, params: %w[uid],
            summary: "One booking by uid.",
            via: ->(p, _c) { Bookings.get(p) }

          operation "booking.list",
            direction: :pull,
            summary: "Bookings, newest first. Optional status filter.",
            via: ->(p, _c) { Bookings.list(p) }

          operation "booking.confirm",
            direction: :push, params: %w[operationId uid],
            summary: "Confirm a pending booking.",
            via: ->(p, _c) { Bookings.confirm(p) }

          operation "booking.decline",
            direction: :push, params: %w[operationId uid],
            summary: "Decline a booking. Optional reason.",
            via: ->(p, _c) { Bookings.decline(p) }

          operation "booking.reschedule",
            direction: :push, params: %w[operationId uid start],
            summary: "Reschedule a booking to a new start. Optional reason.",
            via: ->(p, _c) { Bookings.reschedule(p) }

          operation "booking.cancel",
            direction: :push, params: %w[operationId uid],
            summary: "Cancel a booking. Optional reason.",
            via: ->(p, _c) { Bookings.cancel(p) }
        end

        ::RailsCpcp.project(model: "Slot") do
          operation "slot.list",
            direction: :pull, params: %w[eventTypeId start end],
            summary: "Available slots for an event type in a time range.",
            via: ->(p, _c) { Slots.list(p) }

          operation "slot.reserve",
            direction: :push, params: %w[operationId eventTypeId slotStart],
            summary: "Hold a slot before booking it.",
            via: ->(p, _c) { Slots.reserve(p) }
        end

        ::RailsCpcp.project(model: "EventType") do
          operation "event_type.list",
            direction: :pull,
            summary: "Event types on the account.",
            via: ->(p, _c) { EventTypes.list(p) }

          operation "event_type.get",
            direction: :pull, params: %w[id],
            summary: "One event type by id.",
            via: ->(p, _c) { EventTypes.get(p) }
        end

        ::RailsCpcp.project(model: "Webhook") do
          operation "webhook.verify",
            direction: :pull, params: %w[body signature],
            summary: "Verify an inbound webhook signature locally (HMAC-SHA256, no network).",
            via: ->(p, _c) {
              Webhooks.verify(
                p["body"].to_s,
                { "X-Cal-Signature-256" => p["signature"].to_s },
                signing_secret: p["signingSecret"]
              )
            }
        end

        ::RailsCpcp.project(model: "Embed") do
          operation "embed.url",
            direction: :pull, params: %w[username],
            summary: "Public booking URL for a user/event slug (no network).",
            via: ->(p, _c) { Embed.booking_url(p["username"].to_s, p["eventSlug"]) }
        end

        { ok: true, operations: OPERATIONS }
      end

      # Booking lifecycle. The client refuses a missing uid before the
      # wire, so get/confirm/decline/reschedule/cancel never raise and
      # never dial without an identifier.
      module Bookings
        module_function

        def create(p, client: Client.new)
          attendee = {
            name: p["attendeeName"],
            email: p["attendeeEmail"],
            time_zone: p["attendeeTimeZone"] || p["timeZone"]
          }
          attendee = nil if attendee.values.all?(&:nil?)
          client.create_booking(
            event_type_id: p["eventTypeId"],
            event_type_slug: p["eventTypeSlug"],
            username: p["username"],
            team_slug: p["teamSlug"],
            organization_slug: p["organizationSlug"],
            start: p["start"],
            attendee: attendee,
            time_zone: p["timeZone"],
            location: p["location"],
            notes: p["notes"]
          )
        end

        def get(p, client: Client.new)
          client.get_booking(p["uid"])
        end

        def list(p, client: Client.new)
          client.list_bookings(status: p["status"])
        end

        def confirm(p, client: Client.new)
          client.confirm_booking(p["uid"])
        end

        def decline(p, client: Client.new)
          client.decline_booking(p["uid"], reason: p["reason"])
        end

        def reschedule(p, client: Client.new)
          client.reschedule_booking(p["uid"], start: p["start"], reason: p["reason"])
        end

        def cancel(p, client: Client.new)
          client.cancel_booking(p["uid"], cancellation_reason: p["reason"])
        end
      end

      # Availability. list_slots refuses a missing time range before the
      # wire (:start_required / :end_required).
      module Slots
        module_function

        def list(p, client: Client.new)
          client.list_slots(
            event_type_id: p["eventTypeId"],
            start: p["start"],
            end: p["end"],
            time_zone: p["timeZone"]
          )
        end

        def reserve(p, client: Client.new)
          client.reserve_slot(
            event_type_id: p["eventTypeId"],
            slot_start: p["slotStart"]
          )
        end
      end

      # Event types. get_event_type refuses a missing id before the wire.
      module EventTypes
        module_function

        def list(p, client: Client.new)
          client.list_event_types(username: p["username"], team_slug: p["teamSlug"])
        end

        def get(p, client: Client.new)
          client.get_event_type(p["id"])
        end
      end
    end
  end
end
