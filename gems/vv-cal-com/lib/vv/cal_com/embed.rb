# frozen_string_literal: true

require "json"
require "uri"

module Vv
  module CalCom
    # Public booking URL and embed.js snippet builder. FRONT puts the
    # booker on a page with an iframe or a popup button; this module
    # never scrapes cal.com's DOM and does not wrap Platform Atoms
    # (`@calcom/atoms` — closed to new signups).
    #
    # Direct-link format:
    #   https://cal.com/{username}/{event_slug}
    module Embed
      module_function

      def booking_url(username, event_slug = nil, origin: nil, **config)
        user = username.to_s.strip
        return Envelope.refuse(:username_required, "a booking URL needs a username") if user.empty?

        base = (origin || ENV["CAL_ORIGIN"] || CalCom::DEFAULT_CAL_ORIGIN).to_s.sub(%r{/\z}, "")
        path = "/#{URI.encode_www_form_component(user)}"
        path += "/#{URI.encode_www_form_component(event_slug.to_s)}" unless blank?(event_slug)
        qs = prefill_query(config)
        Envelope.ok(data: qs.empty? ? "#{base}#{path}" : "#{base}#{path}?#{qs}")
      end

      def cal_link(username, event_slug = nil)
        user = username.to_s.strip
        return Envelope.refuse(:username_required, "a calLink needs a username") if user.empty?

        link = user.dup
        link += "/#{event_slug}" unless blank?(event_slug)
        Envelope.ok(data: link)
      end

      def embed_js_url(origin: nil)
        host = (origin || ENV["CAL_APP_URL"] || CalCom::DEFAULT_APP_URL).to_s.sub(%r{/\z}, "")
        Envelope.ok(data: "#{host}/embed/embed.js")
      end

      def iframe_attrs(username, event_slug = nil, width: "100%", height: 630, origin: nil, **config)
        built = booking_url(username, event_slug, origin: origin, embed: true, **config)
        return built unless built[:ok]

        Envelope.ok(data: {
          src: built[:data],
          width: width,
          height: height,
          frameborder: "0",
          scrolling: "no",
          allow: "camera; microphone; fullscreen; payment"
        })
      end

      def popup_attrs(username, event_slug = nil, namespace: nil, **config)
        link = cal_link(username, event_slug)
        return link unless link[:ok]

        attrs = { "data-cal-link" => link[:data] }
        attrs["data-cal-namespace"] = namespace.to_s unless blank?(namespace)
        unless config.empty?
          attrs["data-cal-config"] = JSON.generate(stringify_keys(config))
        end
        Envelope.ok(data: attrs)
      end

      def prefill_query(config)
        return "" if config.nil? || config.empty?

        URI.encode_www_form(stringify_keys(Keys.compact(config)))
      end

      def stringify_keys(hash)
        hash.each_with_object({}) { |(k, v), out| out[k.to_s] = v }
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end
    end
  end
end
