# frozen_string_literal: true

module Vv
  module Miro
    # Generic one-way push: create a board, apply Effects, return a view link.
    # Use-case vocabulary does not live here. Callers supply Effects.
    #
    #   Vv::Miro::Share.push(client, name: "Workshop", effects: [
    #     { op: "create", item: { type: "shape", id: "a", shape: "circle", x: 0, y: 0 } },
    #     { op: "create", item: { type: "connector", start: { id: "a" }, end: { id: "b" } } }
    #   ])
    #
    # Local `item.id` on creates is a caller key, stripped before REST, and
    # used to rewrite connector start/end onto Miro item ids.
    module Share
      CONNECTOR = "connector"

      module_function

      def push(client, name:, effects:)
        return Envelope.refuse(:client_required, "Share.push needs a Miro client") if client.nil?

        title = name.to_s.strip
        return Envelope.refuse(:name_required, "Share.push needs a board name") if title.empty?

        list = Array(effects)
        return Envelope.refuse(:effects_required, "Share.push needs an effects array") if list.empty?

        created = client.create_board(name: title)
        return created unless created[:ok]

        board_id = resource_id(created)
        if board_id.to_s.empty?
          return Envelope.refuse(:board_required, "create_board returned no id")
        end

        ids = {}
        shapes, connectors = partition(list)

        shapes.each do |effect|
          local = local_id(effect)
          wired = strip_local_id(effect)
          result = client.apply_effect(board_id, wired)
          return result unless result[:ok]

          mid = resource_id(result)
          ids[local] = mid unless local.empty? || mid.to_s.empty?
        end

        connectors.each do |effect|
          wired = rewrite_connector(effect, ids)
          return wired unless wired[:ok]

          result = client.apply_effect(board_id, wired[:data])
          return result unless result[:ok]
        end

        Envelope.ok(data: {
          "board_id" => board_id,
          "view_link" => view_link(created, board_id)
        })
      end

      def partition(effects)
        shapes = []
        connectors = []
        effects.each do |effect|
          item = stringify((stringify(effect)["item"]) || {})
          if item["type"].to_s == CONNECTOR
            connectors << effect
          else
            shapes << effect
          end
        end
        [shapes, connectors]
      end

      def local_id(effect)
        item = stringify((stringify(effect)["item"]) || {})
        item["id"].to_s
      end

      def strip_local_id(effect)
        e = stringify(effect)
        item = stringify(e["item"] || {})
        item = item.dup
        item.delete("id")
        e.merge("item" => item)
      end

      def rewrite_connector(effect, ids)
        e = stringify(effect)
        item = stringify(e["item"] || {}).dup
        %w[start end].each do |key|
          node = stringify(item[key] || {})
          ref = (node["id"] || node["item"]).to_s
          if ref.empty?
            return Envelope.refuse(:connector_unresolved, "connector #{key} needs an id")
          end
          mapped = ids[ref]
          if mapped.to_s.empty?
            return Envelope.refuse(:connector_unresolved, "connector #{key} id #{ref.inspect} was not created")
          end
          item[key] = { "id" => mapped }
        end
        item.delete("id")
        Envelope.ok(data: e.merge("item" => item))
      end

      def resource_id(result)
        data = result[:data] || result["data"]
        return nil unless data.is_a?(Hash)

        (data["id"] || data[:id]).to_s
      end

      def view_link(result, board_id)
        data = result[:data] || result["data"] || {}
        links = data["links"] || data[:links] || {}
        link = data["viewLink"] || data["view_link"] || data[:viewLink] ||
               links["view"] || links[:view]
        return link.to_s unless link.to_s.empty?

        "https://miro.com/app/board/#{board_id}/"
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
    end
  end
end
