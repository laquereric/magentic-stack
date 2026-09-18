# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "catalog"

module Vv
  module Mobile
    # F4 — AIUX intention → ACIA document. Deterministic. No LLM.
    # The mobile client already holds ghis-19; this only *names* parts.
    module Compiler
      SHA256 = /\Asha256:[0-9a-f]{64}\z/

      module_function

      def compile(task_kind:, title: nil, fields: [], blob_digest: nil, catalog_version: nil)
        kind = task_kind.to_s
        intention = Catalog.intention(kind)
        unless intention
          return fail_e("kind_not_in_catalog", "taskKind #{kind.inspect} is not one of the 12 AIUX intentions")
        end

        version = (catalog_version.nil? || catalog_version.to_s.empty?) ? intention["catalogVersion"] : catalog_version.to_s

        if kind == "task.date" && version == Catalog::GHIS_19
          return fail_e("date_kind_missing", "date does not compile to text; needs ghis-20@1 DateInput")
        end

        if kind == "task.form" && Array(fields).empty?
          return fail_e("information_model_required", "task.form requires fields")
        end

        if kind == "task.preview"
          digest = blob_digest.to_s
          unless digest.match?(SHA256)
            return fail_e("blob_digest_required", "task.preview requires blobDigest sha256:<64 hex>")
          end
        end

        composed = intention["composedOf"]
        unknown = composed.reject { |c| Catalog.acia_kind?(c, version: version) }
        if unknown.any?
          return fail_e("kind_not_in_catalog", "composedOf #{unknown.inspect} not in #{version}")
        end

        root_kind, *child_kinds = composed
        children = child_kinds.map { |ck| node("#{ck.downcase}-1", ck, child_value(kind, ck, title, blob_digest)) }
        children.concat(field_nodes(fields)) if kind == "task.form"

        doc = {
          "schemaVersion" => "acia/v1",
          "componentRegistryVersion" => version,
          "root" => node("page-shell-1", root_kind, {
            "title" => (title.nil? || title.to_s.empty?) ? kind : title.to_s,
            "pagePurpose" => kind
          }, children: children)
        }

        { ok: true, document: doc, catalogVersion: version, taskKind: kind }
      end

      def node(node_id, kind, value, children: [])
        {
          "nodeId" => node_id,
          "componentKind" => kind,
          "slt" => {
            "semanticRole" => "landmark",
            "contentRole" => "context",
            "layoutKind" => "stack",
            "layoutArity" => children.empty? ? "one" : "many",
            "behaviorKind" => "static",
            "tokenSignature" => { "setRef" => "tokens:ghis@1" }
          },
          "props" => {
            "propsSchemaCid" => "cid:schema:#{kind.to_s.downcase}",
            "valueJson" => value
          },
          "variant" => { "variantName" => "default" },
          "slots" => [],
          "children" => children
        }
      end
      private_class_method :node

      def child_value(task_kind, component_kind, title, blob_digest)
        case component_kind
        when "EmptyState" then { "text" => "No rows" }
        when "RefusalNotice" then { "reason" => "task-error", "operation" => "report-error" }
        when "SemanticText"
          if task_kind == "task.preview"
            { "text" => blob_digest.to_s, "blobDigest" => blob_digest.to_s }
          else
            { "text" => title.to_s.empty? ? task_kind : title.to_s }
          end
        when "ActionControl" then { "action" => "submit", "label" => "Submit" }
        when "DataList" then { "title" => title.to_s.empty? ? "Table" : title.to_s }
        when "StatusBadge" then { "text" => title.to_s.empty? ? "waiting" : title.to_s, "state" => "waiting" }
        when "TabSet" then { "title" => title.to_s.empty? ? "Choice" : title.to_s }
        when "Timeline" then { "title" => title.to_s.empty? ? "Progress" : title.to_s }
        when "ReferentBridge" then { "targetExpression" => title.to_s.empty? ? "grounded claim" : title.to_s }
        when "DateInput" then { "field" => "date", "datatype" => "date" }
        when "DecisionForm" then { "field" => "decision", "choices" => "approve,deny" }
        else { "kind" => component_kind }
        end
      end
      private_class_method :child_value

      def field_nodes(fields)
        Array(fields).map do |f|
          h = f.is_a?(Hash) ? f.transform_keys(&:to_s) : {}
          name = h["name"].to_s
          node("field-#{name}", "DecisionForm", { "field" => name, "datatype" => h["datatype"].to_s })
        end
      end
      private_class_method :field_nodes

      def fail_e(reason, because)
        { ok: false, reason: reason, because: because }
      end
      private_class_method :fail_e
    end
  end
end
