# frozen_string_literal: true

require "uri"

module Vv
  module Miro
    # Shared Effect contract. The browser load applies these through
    # the Web SDK; MIND/BACK applies the same shape through REST when
    # nobody has the board open.
    #
    #   { op: "create"|"update"|"delete"|"sync"|"broadcast",
    #     item: { type:, id:, ...flat fields... },
    #     event:, payload: }
    #
    # This module does not call Miro. It only maps the contract onto
    # REST paths so magentic-stack does not grow a second mapping.
    module Effects
      ITEM_COLLECTIONS = {
        "app_card" => "app_cards",
        "sticky_note" => "sticky_notes",
        "shape" => "shapes",
        "text" => "texts",
        "frame" => "frames",
        "connector" => "connectors",
        "image" => "images",
        "card" => "cards",
        "embed" => "embeds",
        "tag" => "tags"
      }.freeze

      DATA_KEYS = %w[
        title description content content_type shape status fields
        assignee due_date format url preview_url html
      ].freeze

      GEOMETRY_KEYS = %w[width height rotation].freeze
      POSITION_KEYS = %w[x y origin relative_to].freeze
      CONNECTOR_KEYS = %w[start end captions].freeze

      module_function

      def to_rest(effect, board_id:)
        effect = stringify(effect)
        op = effect["op"].to_s
        item = stringify(effect["item"] || {})
        type = item["type"].to_s

        return Envelope.refuse(:op_required, "an Effect needs op:") if op.empty?
        if board_id.to_s.strip.empty?
          return Envelope.refuse(:board_required, "to_rest needs a board_id")
        end

        case op
        when "create"
          collection_for(type) or return @__refusal
          Envelope.ok(data: {
            method: :post,
            path: "/v2/boards/#{enc(board_id)}/#{collection_for(type)}",
            body: item_body(item)
          })
        when "update", "sync"
          id = item["id"].to_s
          return Envelope.refuse(:item_id_required, "update/sync needs item.id") if id.empty?
          collection_for(type) or return @__refusal
          Envelope.ok(data: {
            method: :patch,
            path: "/v2/boards/#{enc(board_id)}/#{collection_for(type)}/#{enc(id)}",
            body: item_body(item)
          })
        when "delete"
          id = item["id"].to_s
          return Envelope.refuse(:item_id_required, "delete needs item.id") if id.empty?
          Envelope.ok(data: {
            method: :delete,
            path: "/v2/boards/#{enc(board_id)}/items/#{enc(id)}",
            body: nil
          })
        when "broadcast"
          Envelope.refuse(
            :broadcast_rest_unsupported,
            "board.events.broadcast is Web SDK only; REST has no equivalent. Use webhooks for durable events."
          )
        else
          Envelope.refuse(:op_unsupported, "unknown Effect op #{op.inspect}")
        end
      end

      def item_body(item)
        item = stringify(item)
        body = {}
        data = slice(item, DATA_KEYS)
        body[:data] = data unless data.empty?
        style = item["style"]
        body[:style] = style unless style.nil? || style == {}
        geometry = slice(item, GEOMETRY_KEYS)
        body[:geometry] = geometry unless geometry.empty?
        position = slice(item, POSITION_KEYS)
        body[:position] = position unless position.empty?
        CONNECTOR_KEYS.each { |k| body[k.to_sym] = item[k] if item.key?(k) }
        parent = item["parent_id"] || item["parentId"]
        body[:parent] = { id: parent } if parent && !parent.to_s.empty? && parent.to_s != "null"
        body
      end

      def collection_for(type)
        col = ITEM_COLLECTIONS[type.to_s]
        if col.nil?
          @__refusal = Envelope.refuse(:item_type_unsupported, "unknown item type #{type.inspect}")
          return nil
        end
        col
      end

      def slice(hash, keys)
        keys.each_with_object({}) do |k, out|
          next unless hash.key?(k)
          next if hash[k].nil?

          out[k.to_sym] = hash[k]
        end
      end

      def stringify(value)
        case value
        when Hash
          value.each_with_object({}) { |(k, v), out| out[k.to_s] = stringify(v) }
        when Array
          value.map { |v| stringify(v) }
        else
          value
        end
      end

      def enc(value)
        URI.encode_www_form_component(value.to_s)
      end
    end
  end
end
