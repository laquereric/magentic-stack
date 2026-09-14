# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Ui
    # Slack Block Kit emit. Date is datepicker, never plain_text_input.
    # Unknown kinds counted, section mrkdwn placeholder.
    module BlockKit
      VERSION = "block-kit-1"
      KIND_MAP = {
        "PageShell" => "modal",
        "PanelFrame" => "section",
        "SemanticText" => "section",
        "StatusBadge" => "context",
        "MetricStrip" => "section",
        "ContextBanner" => "header",
        "DrillDownCard" => "section",
        "DataList" => "section",
        "Timeline" => "section",
        "EvidencePanel" => "section",
        "DecisionForm" => "input",
        "ActionControl" => "button",
        "TabSet" => "overflow",
        "EmptyState" => "section",
        "RefusalNotice" => "section",
        "ScopeTrail" => "context",
        "ReferentBridge" => "section",
        "DateInput" => "datepicker",
        "Input" => "plain_text_input"
      }.freeze

      module_function

      def pin
        { "version" => VERSION }
      end

      def spec_digest
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(pin))}"
      end

      def emit(document, surface_id: "task")
        doc = stringify(document || {})
        root = doc["root"] || doc["rootNode"]
        blocks = []
        unknown = []
        flatten(root, blocks, unknown, root: true)
        {
          "version" => VERSION,
          "specDigest" => spec_digest,
          "surfaceId" => surface_id.to_s,
          "blocks" => blocks,
          "unknownKinds" => unknown,
          "unknownKindCount" => unknown.size
        }
      end

      def flatten(node, blocks, unknown, root: false)
        return unless node.is_a?(Hash)

        kind = node["componentKind"].to_s
        props = (node.dig("props", "valueJson") || {}).transform_keys(&:to_s)
        mapped = KIND_MAP[kind]
        text = (props["text"] || props["title"] || kind).to_s
        if mapped
          case mapped
          when "datepicker"
            blocks << {
              "type" => "input",
              "element" => { "type" => "datepicker", "action_id" => (props["field"] || "date").to_s },
              "label" => { "type" => "plain_text", "text" => (props["field"] || "date").to_s }
            }
          when "plain_text_input"
            if props["datatype"].to_s == "date"
              blocks << {
                "type" => "input",
                "element" => { "type" => "datepicker", "action_id" => (props["field"] || "date").to_s },
                "label" => { "type" => "plain_text", "text" => (props["field"] || "date").to_s }
              }
            else
              blocks << {
                "type" => "input",
                "element" => { "type" => "plain_text_input", "action_id" => (props["field"] || "input").to_s },
                "label" => { "type" => "plain_text", "text" => (props["field"] || "input").to_s }
              }
            end
          when "button"
            blocks << {
              "type" => "actions",
              "elements" => [{
                "type" => "button",
                "text" => { "type" => "plain_text", "text" => (props["label"] || props["action"] || "go").to_s },
                "action_id" => (props["action"] || "submit").to_s
              }]
            }
          when "header"
            blocks << { "type" => "header", "text" => { "type" => "plain_text", "text" => text[0, 150] } }
          else
            blocks << { "type" => "section", "text" => { "type" => "mrkdwn", "text" => text } } unless root
          end
        else
          unknown << { "nodeId" => node["nodeId"].to_s, "componentKind" => kind }
          blocks << { "type" => "section", "text" => { "type" => "mrkdwn", "text" => "[unmapped:#{kind}]" } }
        end
        Array(node["children"]).each { |c| flatten(c, blocks, unknown, root: false) }
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
