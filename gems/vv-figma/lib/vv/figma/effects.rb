# frozen_string_literal: true

require "uri"

module Vv
  module Figma
    # Shared Effect contract. The plugin load applies these through the
    # Plugin API; MIND/BACK applies the same shape through REST when
    # nobody has the file open.
    #
    #   { op: "create"|"update"|"delete"|"sync"|"broadcast",
    #     item: { type:, id:, ...flat fields... },
    #     event:, payload: }
    #
    # Figma REST cannot create document nodes (rectangles, frames, text).
    # Those Effects refuse `plugin_required`. REST can create comments
    # and webhooks. This module does not call Figma.
    module Effects
      REST_TYPES = {
        "comment" => "comments"
      }.freeze

      PLUGIN_TYPES = %w[
        rectangle ellipse text frame line star polygon group
      ].freeze

      module_function

      def to_rest(effect, file_key:)
        effect = stringify(effect)
        op = effect["op"].to_s
        item = stringify(effect["item"] || {})
        type = item["type"].to_s

        return Envelope.refuse(:op_required, "an Effect needs op:") if op.empty?
        if file_key.to_s.strip.empty?
          return Envelope.refuse(:file_required, "to_rest needs a file_key")
        end

        case op
        when "create"
          if PLUGIN_TYPES.include?(type)
            return Envelope.refuse(
              :plugin_required,
              "Figma REST cannot create #{type} nodes; apply this Effect in the plugin sandbox"
            )
          end
          collection_for(type) or return @__refusal
          Envelope.ok(data: {
            method: :post,
            path: "/v1/files/#{enc(file_key)}/#{collection_for(type)}",
            body: comment_body(item)
          })
        when "update", "sync"
          Envelope.refuse(
            :plugin_required,
            "Figma REST cannot update document nodes; apply this Effect in the plugin sandbox"
          )
        when "delete"
          id = item["id"].to_s
          return Envelope.refuse(:item_id_required, "delete needs item.id") if id.empty?
          if type == "comment" || type.empty?
            Envelope.ok(data: {
              method: :delete,
              path: "/v1/files/#{enc(file_key)}/comments/#{enc(id)}",
              body: nil
            })
          else
            Envelope.refuse(
              :plugin_required,
              "Figma REST cannot delete #{type} nodes; apply this Effect in the plugin sandbox"
            )
          end
        when "broadcast"
          Envelope.refuse(
            :broadcast_rest_unsupported,
            "plugin postMessage is sandbox-only; REST has no equivalent. Use webhooks for durable events."
          )
        else
          Envelope.refuse(:op_unsupported, "unknown Effect op #{op.inspect}")
        end
      end

      def comment_body(item)
        item = stringify(item)
        body = {}
        body[:message] = item["message"] || item["content"] || item["title"]
        meta = {}
        meta[:x] = item["x"] if item.key?("x")
        meta[:y] = item["y"] if item.key?("y")
        node = item["node_id"] || item["nodeId"]
        meta[:node_id] = node unless node.to_s.empty?
        body[:client_meta] = meta unless meta.empty?
        Keys.compact(body)
      end

      def collection_for(type)
        col = REST_TYPES[type.to_s]
        if col.nil?
          @__refusal = Envelope.refuse(:item_type_unsupported, "unknown item type #{type.inspect}")
          return nil
        end
        col
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
