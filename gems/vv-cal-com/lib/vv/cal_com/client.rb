# frozen_string_literal: true

require "uri"

module Vv
  module CalCom
    # API v2 client for `https://api.cal.com`. Bookings, event types,
    # schedules, slots, webhooks, me, teams — not Atoms, not the
    # deprecated Platform managed-user surface.
    #
    # Never raises. Every method returns `{ ok: true, data: }` or
    # `{ ok: false, reason:, because: }`.
    #
    #   client = Vv::CalCom::Client.new(token: ENV["CAL_API_KEY"])
    #   client.list_bookings(status: "upcoming")
    class Client
      attr_reader :uri, :token, :api_version, :transport

      def initialize(token: nil, api_key: nil, uri: nil, api_version: nil,
                     client_id: nil, secret_key: nil, transport: nil,
                     open_timeout: nil, read_timeout: nil)
        @uri = (uri || ENV["CAL_API_URL"] || CalCom::DEFAULT_API_URL).to_s
        @token = (token || api_key || ENV["CAL_API_KEY"] || ENV["CAL_ACCESS_TOKEN"] || ENV["CALCOM_API_KEY"]).to_s
        @api_version = api_version || ENV["CAL_API_VERSION"] || CalCom::DEFAULT_API_VERSION
        @transport = transport || Transport.new(
          uri: @uri,
          token: @token,
          api_version: @api_version,
          client_id: client_id || ENV["CAL_CLIENT_ID"],
          secret_key: secret_key || ENV["CAL_SECRET_KEY"] || ENV["CAL_CLIENT_SECRET"],
          open_timeout: open_timeout || Transport::DEFAULT_OPEN_TIMEOUT,
          read_timeout: read_timeout || Transport::DEFAULT_READ_TIMEOUT
        )
      end

      # Escape hatch for any API v2 path this gem has not named yet.
      def call(method, path, body: nil, query: nil, auth: true, api_version: nil)
        wire = body.nil? ? nil : Keys.to_wire(Keys.compact(body))
        q = query.nil? ? nil : Keys.to_wire(Keys.compact(query))
        @transport.request(method, path, body: wire, query: q, auth: auth, api_version: api_version)
      end

      def get(path, query = nil, **opts)
        call(:get, path, query: query, **opts)
      end

      def post(path, body = nil, **opts)
        call(:post, path, body: body, **opts)
      end

      def patch(path, body = nil, **opts)
        call(:patch, path, body: body, **opts)
      end

      def delete(path, body = nil, **opts)
        call(:delete, path, body: body, **opts)
      end

      # ── me ─────────────────────────────────────────────────────

      def me
        get("/v2/me")
      end

      def update_me(**body)
        patch("/v2/me", body)
      end

      # ── bookings ───────────────────────────────────────────────

      def list_bookings(**query)
        get("/v2/bookings", query, api_version: CalCom::BOOKING_LIST_API_VERSION)
      end

      def get_booking(booking_uid)
        need!(booking_uid, :booking_required, "get_booking needs a booking uid") or return @__refusal
        get("/v2/bookings/#{enc(booking_uid)}", nil, api_version: CalCom::BOOKING_API_VERSION)
      end

      def create_booking(**body)
        post("/v2/bookings", body, auth: :optional, api_version: CalCom::BOOKING_API_VERSION)
      end

      def cancel_booking(booking_uid, **body)
        need!(booking_uid, :booking_required, "cancel_booking needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/cancel", body, auth: :optional, api_version: CalCom::BOOKING_API_VERSION)
      end

      def reschedule_booking(booking_uid, **body)
        need!(booking_uid, :booking_required, "reschedule_booking needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/reschedule", body, auth: :optional, api_version: CalCom::BOOKING_API_VERSION)
      end

      def request_reschedule(booking_uid, **body)
        need!(booking_uid, :booking_required, "request_reschedule needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/request-reschedule", body, api_version: CalCom::BOOKING_API_VERSION)
      end

      def confirm_booking(booking_uid, **body)
        need!(booking_uid, :booking_required, "confirm_booking needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/confirm", body, api_version: CalCom::BOOKING_API_VERSION)
      end

      def decline_booking(booking_uid, **body)
        need!(booking_uid, :booking_required, "decline_booking needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/decline", body, api_version: CalCom::BOOKING_API_VERSION)
      end

      def reassign_booking(booking_uid, user_id: nil, **body)
        need!(booking_uid, :booking_required, "reassign_booking needs a booking uid") or return @__refusal
        path =
          if blank?(user_id)
            "/v2/bookings/#{enc(booking_uid)}/reassign"
          else
            "/v2/bookings/#{enc(booking_uid)}/reassign/#{enc(user_id)}"
          end
        post(path, body, api_version: CalCom::BOOKING_API_VERSION)
      end

      def mark_booking_absent(booking_uid, **body)
        need!(booking_uid, :booking_required, "mark_booking_absent needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/mark-absent", body, api_version: CalCom::BOOKING_API_VERSION)
      end

      def update_booking_location(booking_uid, **body)
        need!(booking_uid, :booking_required, "update_booking_location needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/location", body, api_version: CalCom::BOOKING_API_VERSION)
      end

      def list_booking_attendees(booking_uid, **query)
        need!(booking_uid, :booking_required, "list_booking_attendees needs a booking uid") or return @__refusal
        get("/v2/bookings/#{enc(booking_uid)}/attendees", query, api_version: CalCom::BOOKING_API_VERSION)
      end

      def add_booking_attendee(booking_uid, **body)
        need!(booking_uid, :booking_required, "add_booking_attendee needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/attendees", body, api_version: CalCom::BOOKING_API_VERSION)
      end

      def add_booking_guests(booking_uid, **body)
        need!(booking_uid, :booking_required, "add_booking_guests needs a booking uid") or return @__refusal
        post("/v2/bookings/#{enc(booking_uid)}/guests", body, api_version: CalCom::BOOKING_API_VERSION)
      end

      def booking_calendar_links(booking_uid)
        need!(booking_uid, :booking_required, "booking_calendar_links needs a booking uid") or return @__refusal
        get("/v2/bookings/#{enc(booking_uid)}/calendar-links", nil, api_version: CalCom::BOOKING_API_VERSION)
      end

      def booking_recordings(booking_uid)
        need!(booking_uid, :booking_required, "booking_recordings needs a booking uid") or return @__refusal
        get("/v2/bookings/#{enc(booking_uid)}/recordings")
      end

      def booking_transcripts(booking_uid)
        need!(booking_uid, :booking_required, "booking_transcripts needs a booking uid") or return @__refusal
        get("/v2/bookings/#{enc(booking_uid)}/transcripts")
      end

      def booking_references(booking_uid, **query)
        need!(booking_uid, :booking_required, "booking_references needs a booking uid") or return @__refusal
        get("/v2/bookings/#{enc(booking_uid)}/references", query, api_version: CalCom::BOOKING_API_VERSION)
      end

      # ── event types ────────────────────────────────────────────

      def list_event_types(**query)
        get("/v2/event-types", query, api_version: CalCom::EVENT_TYPE_API_VERSION)
      end

      def get_event_type(event_type_id)
        need!(event_type_id, :event_type_required, "get_event_type needs an event type id") or return @__refusal
        get("/v2/event-types/#{enc(event_type_id)}", nil, api_version: CalCom::EVENT_TYPE_API_VERSION)
      end

      def create_event_type(**body)
        post("/v2/event-types", body, api_version: CalCom::EVENT_TYPE_API_VERSION)
      end

      def update_event_type(event_type_id, **body)
        need!(event_type_id, :event_type_required, "update_event_type needs an event type id") or return @__refusal
        patch("/v2/event-types/#{enc(event_type_id)}", body, api_version: CalCom::EVENT_TYPE_API_VERSION)
      end

      def delete_event_type(event_type_id)
        need!(event_type_id, :event_type_required, "delete_event_type needs an event type id") or return @__refusal
        delete("/v2/event-types/#{enc(event_type_id)}", nil, api_version: CalCom::EVENT_TYPE_API_VERSION)
      end

      # ── schedules ──────────────────────────────────────────────

      def list_schedules(**query)
        get("/v2/schedules", query)
      end

      def get_default_schedule
        get("/v2/schedules/default")
      end

      def get_schedule(schedule_id)
        need!(schedule_id, :schedule_required, "get_schedule needs a schedule id") or return @__refusal
        get("/v2/schedules/#{enc(schedule_id)}")
      end

      def create_schedule(**body)
        post("/v2/schedules", body)
      end

      def update_schedule(schedule_id, **body)
        need!(schedule_id, :schedule_required, "update_schedule needs a schedule id") or return @__refusal
        patch("/v2/schedules/#{enc(schedule_id)}", body)
      end

      def delete_schedule(schedule_id)
        need!(schedule_id, :schedule_required, "delete_schedule needs a schedule id") or return @__refusal
        delete("/v2/schedules/#{enc(schedule_id)}")
      end

      # ── slots ──────────────────────────────────────────────────

      def list_slots(**query)
        if blank?(query[:start] || query["start"])
          return Envelope.refuse(:start_required, "list_slots needs a start time")
        end
        if blank?(query[:end] || query["end"])
          return Envelope.refuse(:end_required, "list_slots needs an end time")
        end

        get("/v2/slots", query, auth: :optional, api_version: CalCom::SLOT_API_VERSION)
      end

      def reserve_slot(**body)
        post("/v2/slots/reservations", body, auth: :optional, api_version: CalCom::SLOT_API_VERSION)
      end

      def get_reserved_slot(uid)
        need!(uid, :slot_required, "get_reserved_slot needs a reservation uid") or return @__refusal
        get("/v2/slots/reservations/#{enc(uid)}", nil, auth: :optional, api_version: CalCom::SLOT_API_VERSION)
      end

      def update_reserved_slot(uid, **body)
        need!(uid, :slot_required, "update_reserved_slot needs a reservation uid") or return @__refusal
        patch("/v2/slots/reservations/#{enc(uid)}", body, auth: :optional, api_version: CalCom::SLOT_API_VERSION)
      end

      def delete_reserved_slot(uid)
        need!(uid, :slot_required, "delete_reserved_slot needs a reservation uid") or return @__refusal
        delete("/v2/slots/reservations/#{enc(uid)}", nil, auth: :optional, api_version: CalCom::SLOT_API_VERSION)
      end

      # ── webhooks ───────────────────────────────────────────────

      def list_webhooks(**query)
        get("/v2/webhooks", query)
      end

      def get_webhook(webhook_id)
        need!(webhook_id, :webhook_required, "get_webhook needs a webhook id") or return @__refusal
        get("/v2/webhooks/#{enc(webhook_id)}")
      end

      def create_webhook(**body)
        post("/v2/webhooks", body)
      end

      def update_webhook(webhook_id, **body)
        need!(webhook_id, :webhook_required, "update_webhook needs a webhook id") or return @__refusal
        patch("/v2/webhooks/#{enc(webhook_id)}", body)
      end

      def delete_webhook(webhook_id)
        need!(webhook_id, :webhook_required, "delete_webhook needs a webhook id") or return @__refusal
        delete("/v2/webhooks/#{enc(webhook_id)}")
      end

      # ── teams ──────────────────────────────────────────────────

      def list_teams(**query)
        get("/v2/teams", query)
      end

      def get_team(team_id)
        need!(team_id, :team_required, "get_team needs a team id") or return @__refusal
        get("/v2/teams/#{enc(team_id)}")
      end

      def create_team(**body)
        post("/v2/teams", body)
      end

      def update_team(team_id, **body)
        need!(team_id, :team_required, "update_team needs a team id") or return @__refusal
        patch("/v2/teams/#{enc(team_id)}", body)
      end

      def delete_team(team_id)
        need!(team_id, :team_required, "delete_team needs a team id") or return @__refusal
        delete("/v2/teams/#{enc(team_id)}")
      end

      def list_team_bookings(team_id, **query)
        need!(team_id, :team_required, "list_team_bookings needs a team id") or return @__refusal
        get("/v2/teams/#{enc(team_id)}/bookings", query, api_version: CalCom::BOOKING_LIST_API_VERSION)
      end

      def list_team_event_types(team_id, **query)
        need!(team_id, :team_required, "list_team_event_types needs a team id") or return @__refusal
        get("/v2/teams/#{enc(team_id)}/event-types", query, api_version: CalCom::EVENT_TYPE_API_VERSION)
      end

      def create_team_event_type(team_id, **body)
        need!(team_id, :team_required, "create_team_event_type needs a team id") or return @__refusal
        post("/v2/teams/#{enc(team_id)}/event-types", body, api_version: CalCom::EVENT_TYPE_API_VERSION)
      end

      def list_team_memberships(team_id, **query)
        need!(team_id, :team_required, "list_team_memberships needs a team id") or return @__refusal
        get("/v2/teams/#{enc(team_id)}/memberships", query)
      end

      def create_team_membership(team_id, **body)
        need!(team_id, :team_required, "create_team_membership needs a team id") or return @__refusal
        post("/v2/teams/#{enc(team_id)}/memberships", body)
      end

      # ── out of office ──────────────────────────────────────────

      def list_ooo(**query)
        get("/v2/out-of-office", query)
      end

      def create_ooo(**body)
        post("/v2/out-of-office", body)
      end

      def update_ooo(ooo_id, **body)
        need!(ooo_id, :ooo_required, "update_ooo needs an out-of-office id") or return @__refusal
        patch("/v2/out-of-office/#{enc(ooo_id)}", body)
      end

      def delete_ooo(ooo_id)
        need!(ooo_id, :ooo_required, "delete_ooo needs an out-of-office id") or return @__refusal
        delete("/v2/out-of-office/#{enc(ooo_id)}")
      end

      private

      def need!(value, reason, because)
        if blank?(value)
          @__refusal = Envelope.refuse(reason, because)
          return false
        end
        true
      end

      def blank?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def enc(value)
        URI.encode_www_form_component(value.to_s)
      end
    end
  end
end
