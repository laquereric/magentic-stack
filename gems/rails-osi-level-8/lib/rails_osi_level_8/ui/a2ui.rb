# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Ui
    # S5 fixture mapper. Pinned to A2UI 0.9.1. A bump to 1.0 is a second
    # adapter (`as=a2ui` stays 0.9.1). Unknown ghis kinds are counted in
    # the envelope and still appear as Text placeholders — never dropped.
    module A2ui
      VERSION = "v0.9.1"
      SPEC_URL = "https://a2ui.org/specification/v0.9.1-a2ui/"
      CATALOG_ID = "https://a2ui.org/specification/v0_9_1/catalogs/basic/catalog.json"

      # ghis-19 → Basic catalog. Missing = unknown (counted).
      KIND_MAP = {
        "PageShell" => "Column",
        "SemanticText" => "Text",
        "ActionControl" => "Button",
        "DecisionForm" => "Card",
        "RefusalNotice" => "Card",
        "EmptyState" => "Text",
        "DateInput" => "DateTimeInput",
        "Input" => "TextField"
      }.freeze

      module_function

      def pin
        {
          "version" => VERSION,
          "specUrl" => SPEC_URL,
          "catalogId" => CATALOG_ID
        }
      end

      def spec_digest
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(pin))}"
      end

      def emit(document, surface_id: "task")
        doc = stringify(document || {})
        root = doc["root"] || doc["rootNode"]
        components = []
        unknown = []
        flatten(root, components, unknown, root: true)
        {
          "version" => VERSION,
          "specUrl" => SPEC_URL,
          "catalogId" => CATALOG_ID,
          "specDigest" => spec_digest,
          "createSurface" => {
            "surfaceId" => surface_id.to_s,
            "catalogId" => CATALOG_ID
          },
          "updateComponents" => {
            "surfaceId" => surface_id.to_s,
            "components" => components
          },
          "unknownKinds" => unknown,
          "unknownKindCount" => unknown.size
        }
      end

      def flatten(node, components, unknown, root: false)
        return unless node.is_a?(Hash)

        kind = node["componentKind"].to_s
        node_id = root ? "root" : slug(node["nodeId"])
        mapped = KIND_MAP[kind]
        props = (node.dig("props", "valueJson") || {}).transform_keys(&:to_s)
        child_nodes = Array(node["children"])
        child_ids = child_nodes.map { |c| c.is_a?(Hash) ? slug(c["nodeId"]) : nil }.compact

        if mapped
          rec = mapped_component(node_id, mapped, kind, props, child_ids)
          components << rec
          if rec["component"] == "Button"
            components << {
              "id" => rec["child"],
              "component" => "Text",
              "text" => (props["label"] || props["action"] || "go").to_s
            }
          end
        else
          unknown << { "nodeId" => node["nodeId"].to_s, "componentKind" => kind }
          components << {
            "id" => node_id,
            "component" => "Text",
            "text" => "[unmapped:#{kind}]",
            "variant" => "caption"
          }
        end

        child_nodes.each { |c| flatten(c, components, unknown, root: false) }
      end
      private_class_method :flatten

      def mapped_component(id, a2ui_kind, ghis_kind, props, child_ids)
        rec = { "id" => id, "component" => a2ui_kind }
        case a2ui_kind
        when "Column"
          rec["children"] = child_ids
        when "Text"
          rec["text"] = props["text"] || props["title"] || ghis_kind
          rec["variant"] = "body"
        when "Button"
          rec["child"] = "#{id}-label"
          rec["action"] = { "event" => { "name" => (props["action"] || "submit").to_s } }
          rec["variant"] = "primary"
        when "Card"
          rec["child"] = child_ids.first if child_ids.any?
          rec["text"] = props["choices"] || props["reason"] || props["field"] || ghis_kind
        when "DateTimeInput"
          rec["value"] = props["value"] if props["value"]
          rec["label"] = props["field"] || "date"
        when "TextField"
          if props["datatype"].to_s == "boolean"
            rec["component"] = "CheckBox"
            rec["label"] = props["field"] || "flag"
          else
            rec["label"] = props["field"] || "input"
            rec["variant"] = props["datatype"].to_s == "integer" ? "number" : "shortText"
          end
        end
        rec
      end
      private_class_method :mapped_component

      def slug(node_id)
        s = node_id.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-+\z/, "")
        s = "n" if s.empty?
        s[0, 48]
      end
      private_class_method :slug

      def stringify(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
        when Array then obj.map { |v| stringify(v) }
        else obj
        end
      end
      private_class_method :stringify
    end
  end
end
