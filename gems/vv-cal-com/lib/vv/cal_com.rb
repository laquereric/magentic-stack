# frozen_string_literal: true

require_relative "cal_com/version"
require_relative "cal_com/keys"
require_relative "cal_com/envelope"
require_relative "cal_com/transport"
require_relative "cal_com/client"
require_relative "cal_com/oauth"
require_relative "cal_com/webhooks"
require_relative "cal_com/embed"
require_relative "cal_com/cpcp"

module Vv
  # Ruby client for the Cal.com API v2 (and local webhook crypto / embed URLs).
  #
  # Four planes, because Cal.com has four:
  #
  #   Vv::CalCom::Client    — api.cal.com/v2 (bookings, event types, schedules)
  #   Vv::CalCom::Oauth     — /v2/auth/oauth2 (authorization code + refresh)
  #   Vv::CalCom::Webhooks  — HMAC-SHA256 over the raw body
  #   Vv::CalCom::Embed     — cal.com/{user}/{slug} + embed.js snippets
  #
  # Never raises across the boundary.
  module CalCom
    DEFAULT_API_URL = "https://api.cal.com"
    DEFAULT_APP_URL = "https://app.cal.com"
    DEFAULT_CAL_ORIGIN = "https://cal.com"
    DEFAULT_API_VERSION = "2024-08-13"
    BOOKING_API_VERSION = "2026-02-25"
    BOOKING_LIST_API_VERSION = "2026-05-01"
    EVENT_TYPE_API_VERSION = "2026-06-12"
    SLOT_API_VERSION = "2024-09-04"
    AUTHORIZE_PATH = "/v2/auth/oauth2/authorize"
    TOKEN_PATH = "/v2/auth/oauth2/token"

    DEFAULT_SCOPES = %w[
      BOOKING_READ
      BOOKING_WRITE
      EVENT_TYPE_READ
      EVENT_TYPE_WRITE
      SCHEDULE_READ
      SCHEDULE_WRITE
      PROFILE_READ
      WEBHOOK_READ
      WEBHOOK_WRITE
    ].freeze

    def self.client(**kwargs)
      Client.new(**kwargs)
    end

    def self.oauth(**kwargs)
      Oauth.new(**kwargs)
    end

    def self.webhooks
      Webhooks
    end

    def self.embed
      Embed
    end
  end
end
