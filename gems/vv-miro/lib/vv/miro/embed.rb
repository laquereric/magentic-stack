# frozen_string_literal: true

require "uri"

module Vv
  module Miro
    # Live Embed URL builder. FRONT puts the board in its own UI with
    # an iframe; this module never scrapes miro.com's DOM.
    #
    # Direct-link format:
    #   https://miro.com/app/live-embed/{board_id}?autoplay=true&...
    module Embed
      PARAMS = %i[autoplay embed_mode move_to_widget move_to_viewport].freeze

      module_function

      def url(board_id, autoplay: true, embed_mode: nil, move_to_widget: nil, move_to_viewport: nil)
        id = board_id.to_s.strip
        return Envelope.refuse(:board_required, "a Live Embed URL needs a board_id") if id.empty?

        query = {}
        query["autoplay"] = autoplay ? "true" : "false" unless autoplay.nil?
        query["embedMode"] = embed_mode.to_s unless blank?(embed_mode)
        query["moveToWidget"] = move_to_widget.to_s unless blank?(move_to_widget)
        unless move_to_viewport.nil?
          mapped = viewport_value(move_to_viewport)
          return mapped unless mapped[:ok]

          query["moveToViewport"] = mapped[:data]
        end
        if query["moveToWidget"] && query["moveToViewport"]
          return Envelope.refuse(
            :viewport_conflict,
            "a Live Embed URL may set moveToWidget or moveToViewport, not both"
          )
        end

        qs = query.empty? ? "" : "?#{URI.encode_www_form(query)}"
        Envelope.ok(data: "#{LIVE_EMBED_BASE}/#{URI.encode_www_form_component(id)}/#{qs}")
      end

      def iframe_attrs(board_id, width: 768, height: 432, **opts)
        built = url(board_id, **opts)
        return built unless built[:ok]

        Envelope.ok(data: {
          src: built[:data],
          width: width,
          height: height,
          frameborder: "0",
          scrolling: "no",
          allowfullscreen: true
        })
      end

      def viewport_value(value)
        case value
        when String
          Envelope.ok(data: value)
        when Array
          if value.length != 4
            return Envelope.refuse(:viewport_invalid, "move_to_viewport needs [x, y, width, height]")
          end
          Envelope.ok(data: value.join(","))
        when Hash
          keys = %i[x y width height]
          missing = keys.reject { |k| value.key?(k) || value.key?(k.to_s) }
          unless missing.empty?
            return Envelope.refuse(:viewport_invalid, "move_to_viewport needs x, y, width, height")
          end
          nums = keys.map { |k| value[k] || value[k.to_s] }
          Envelope.ok(data: nums.join(","))
        else
          Envelope.refuse(:viewport_invalid, "move_to_viewport must be a string, array, or hash")
        end
      end

      def blank?(value)
        value.nil? || value.to_s.strip.empty?
      end
    end
  end
end
