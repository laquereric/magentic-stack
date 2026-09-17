# frozen_string_literal: true

require_relative "figma/version"
require_relative "figma/keys"
require_relative "figma/envelope"
require_relative "figma/transport"
require_relative "figma/oauth"
require_relative "figma/effects"
require_relative "figma/client"
require_relative "figma/share"
require_relative "figma/embed"
require_relative "figma/assets"

module Vv
  # Figma boundary for Magentic. Three planes, because Figma has three:
  #
  #   public/vv-figma.js    — Plugin API (sandbox + UI postMessage)
  #   Vv::Figma::Client     — api.figma.com (files, comments, webhooks)
  #   Vv::Figma::Oauth      — /v1/oauth/token (authorization code + refresh)
  #
  # Never raises across the Ruby boundary. Editor.js does not call
  # `figma` / `window.figma`; it loads vv-figma.js and talks in Effects.
  module Figma
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
