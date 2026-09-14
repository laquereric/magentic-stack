# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Ui
    # Adaptive Cards 1.5 emit. A bump is a second adapter, not an edit.
    # Date is Input.Date, never Input.Text. Unknown kinds counted, TextBlock.
    module AdaptiveCards
      VERSION = "1.5"
      SCHEMA = "http://adaptivecards.io/schemas/adaptive-card.json"

      KIND_MAP = {
        "PageShell" => "AdaptiveCard",
        "PanelFrame" => "Container",
        "SemanticText" => "TextBlock",
        "StatusBadge" => "TextBlock",
        "MetricStrip" => "FactSet",
        "ContextBanner" => "Container",
        "DrillDownCard" => "Container",
        "DataList" => "Container",
        "Timeline" => "Container",
        "EvidencePanel" => "Container",
        "DecisionForm" => "Container",
        "ActionControl" => "Action.Submit",
        "TabSet" => "ActionSet",
        "EmptyState" => "TextBlock",
        "RefusalNotice" => "TextBlock",
        "ScopeTrail" => "FactSet",
        "ReferentBridge" => "TextBlock",
        "DateInput" => "Input.Date",
        "Input" => "Input.Text"
      }.freeze

      module_function

      def pin
        { "version" => VERSION, "schema" => SCHEMA }
      end

      def spec_digest
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(pin))}"
      end

      def emit(document, surface_id: "task")
        doc = stringify(document || {})
        root = doc["root"] || doc["rootNode"]
        body = []
        actions = []
        unknown = []
        flatten(root, body, actions, unknown, root: true)
        {
          "version" => VERSION,
          "schema" => SCHEMA,
          "specDigest" => spec_digest,
          "type" => "AdaptiveCard",
          "body" => body,
          "actions" => actions,
          "surfaceId" => surface_id.to_s,
          "unknownKinds" => unknown,
          "unknownKindCount" => unknown.size
        }
      end

      def flatten(node, body, actions, unknown, root: false)
        return unless node.is_a?(Hash)

        kind = node["componentKind"].to_s
        props = (node.dig("props", "valueJson") || {}).transform_keys(&:to_s)
        mapped = KIND_MAP[kind]
        if mapped
          rec = { "type" => mapped }
          rec["text"] = (props["text"] || props["title"] || kind).to_s if mapped == "TextBlock"
          rec["id"] = (props["field"] || node["nodeId"]).to_s if mapped.start_with?("Input.")
          rec["title"] = (props["label"] || props["action"] || "go").to_s if mapped == "Action.Submit"
          if mapped == "Input.Date"
            rec["id"] = (props["field"] || "date").to_s
          elsif mapped == "Input.Text" && props["datatype"].to_s == "date"
            rec["type"] = "Input.Date"
            rec["id"] = (props["field"] || "date").to_s
          end
          if mapped == "Action.Submit"
            actions << rec
          else
            body << rec unless root && mapped == "AdaptiveCard"
          end
        else
          unknown << { "nodeId" => node["nodeId"].to_s, "componentKind" => kind }
          body << { "type" => "TextBlock", "text" => "[unmapped:#{kind}]", "size" => "Small" }
        end
        Array(node["children"]).each { |c| flatten(c, body, actions, unknown, root: false) }
      end
      private_class_method :flatten

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
