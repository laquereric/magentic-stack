# frozen_string_literal: true

module Vv
  module Figma
    # One-way push onto an existing Figma file. Figma REST cannot create
    # a file the way Miro REST creates a board, so Share.push requires a
    # `file_key` and only applies REST-capable Effects (comments).
    # Document nodes refuse `plugin_required` at Effects.to_rest.
    module Share
      module_function

      def push(client, file_key:, effects:, name: nil)
        return Envelope.refuse(:client_required, "Share.push needs a Figma client") if client.nil?

        key = file_key.to_s.strip
        return Envelope.refuse(:file_required, "Share.push needs a file_key; Figma REST cannot create files") if key.empty?

        list = Array(effects)
        return Envelope.refuse(:effects_required, "Share.push needs an effects array") if list.empty?

        list.each do |effect|
          result = client.apply_effect(key, stringify(effect))
          return result unless result[:ok]
        end

        Envelope.ok(data: {
          "file_key" => key,
          "name" => name.to_s,
          "view_link" => "#{FILE_URL_BASE}/#{key}/"
        })
      end

      def stringify(value)
        Effects.stringify(value)
      end
    end
  end
end
