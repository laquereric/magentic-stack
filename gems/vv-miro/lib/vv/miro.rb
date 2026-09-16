# frozen_string_literal: true

require_relative "miro/version"
require_relative "miro/keys"
require_relative "miro/envelope"
require_relative "miro/transport"
require_relative "miro/oauth"
require_relative "miro/effects"
require_relative "miro/client"
require_relative "miro/share"
require_relative "miro/embed"
require_relative "miro/assets"

module Vv
  # Miro boundary for Magentic. Three planes, because Miro has three:
  #
  #   public/vv-miro.js     — Web SDK 2.0 + Live Embed (the single browser load)
  #   Vv::Miro::Client      — api.miro.com/v2 (boards, items, webhooks)
  #   Vv::Miro::Oauth       — /v1/oauth/token (authorization code + refresh)
  #
  # Never raises across the Ruby boundary. Editor.js does not call
  # window.miro; it loads vv-miro.js and talks in Effects.
  module Miro
    def self.client(**kwargs)
      Client.new(**kwargs)
    end

    def self.oauth(**kwargs)
      Oauth.new(**kwargs)
    end

    def self.embed
      Embed
    end

    def self.assets
      Assets
    end

    def self.share
      Share
    end
  end
end
