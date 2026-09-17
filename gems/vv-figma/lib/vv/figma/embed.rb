# frozen_string_literal: true

require "uri"

module Vv
  module Figma
    # Embed URL builder. FRONT puts the file in its own UI with an
    # iframe; this module never scrapes figma.com's DOM.
    #
    #   https://www.figma.com/embed?embed_host=figma&url=https://www.figma.com/file/{key}
    module Embed
      module_function

      def url(file_key, embed_host: "figma")
        key = file_key.to_s.strip
        return Envelope.refuse(:file_required, "an embed URL needs a file_key") if key.empty?

        file = "#{FILE_URL_BASE}/#{URI.encode_www_form_component(key)}"
        query = {
          "embed_host" => embed_host.to_s.empty? ? "figma" : embed_host.to_s,
          "url" => file
        }
        Envelope.ok(data: "#{EMBED_BASE}?#{URI.encode_www_form(query)}")
      end

      def iframe_attrs(file_key, width: 800, height: 450, **opts)
        built = url(file_key, **opts)
        return built unless built[:ok]

        Envelope.ok(data: {
          src: built[:data],
          width: width,
          height: height,
          frameborder: "0",
          allowfullscreen: true
        })
      end
    end
  end
end
