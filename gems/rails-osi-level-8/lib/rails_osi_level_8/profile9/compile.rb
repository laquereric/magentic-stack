# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Profile9
    # F4 — InformationModel → ACIA. Deterministic. No LLM.
    # ghis-19@1 has no Date or Input kind. Date never compiles to text.
    module Compile
      CATALOG_VERSION = "ghis-19@1"
      GHIS_20 = "ghis-20@1"
      GHIS_21 = "ghis-21@1"
      TOKEN_SET_REF = "tokens:ghis@1"

      # datatype → ghis kind. Date is ghis-20@1; Input is ghis-21@1.
      FIELD_KIND_BY_VERSION = {
        CATALOG_VERSION => { "enum" => "DecisionForm" },
        GHIS_20 => { "enum" => "DecisionForm", "date" => "DateInput" },
        GHIS_21 => {
          "enum" => "DecisionForm",
          "date" => "DateInput",
          "string" => "Input",
          "text" => "Input",
          "integer" => "Input",
          "boolean" => "Input",
          "iri" => "Input"
        }
      }.freeze
      FIELD_KIND = FIELD_KIND_BY_VERSION[CATALOG_VERSION]

      J1_FIELDS = [
        {
          "name" => "decision",
          "datatype" => "enum",
          "required" => true,
          "cardinality" => "1",
          "enum_key" => "approve-deny",
          "ordinal" => 1
        }
      ].freeze

      module_function

      def fields_from(model)
        model.fields.order(:ordinal).map { |f|
          {
            "name" => f.name,
            "datatype" => f.datatype,
            "required" => f.required,
            "cardinality" => f.cardinality,
            "enum_key" => f.enum_key,
            "ordinal" => f.ordinal
          }
        }
      end

      def call(fields:, step_kind:, title:, catalog_version: CATALOG_VERSION, frame: nil, reviewed_digest: nil, blob_digest: nil)
        fields = normalize_fields(fields)
        refused = refuse_fields(fields, catalog_version)
        return refused if refused

        if %w[collect decide date].include?(step_kind.to_s) && fields.empty?
          return fail_e("information_model_required", { "step_kind" => step_kind })
        end

        if step_kind.to_s == "preview"
          d = blob_digest.to_s
          unless d.match?(/\Asha256:[0-9a-f]{64}\z/)
            return fail_e("blob_digest_required", { "blobDigest" => d })
          end
        end

        doc = document_for(
          fields: fields, step_kind: step_kind.to_s, title: title.to_s,
          frame: frame, reviewed_digest: reviewed_digest, blob_digest: blob_digest,
          catalog_version: catalog_version
        )
        validation = Acia.validate(doc)
        unless validation.conforms?
          return fail_e(validation.reason, validation.because || {})
        end

        {
          "ok" => true,
          "document" => doc,
          "digest" => validation.digest,
          "aciaCid" => "cid:acia:#{validation.digest.delete_prefix('sha256:')}",
          "catalogVersion" => catalog_version,
          "stepKind" => step_kind.to_s
        }
      end

      def j1_document(fields: J1_FIELDS)
        call(fields: fields, step_kind: "decide", title: "Authorization review", frame: "j1")
      end

      def normalize_fields(fields)
        Array(fields).map { |f|
          h = f.is_a?(Hash) ? f.transform_keys(&:to_s) : {}
          h["ordinal"] = h["ordinal"].to_i
          h
        }.sort_by { |f| [f["ordinal"], f["name"].to_s] }
      end
      private_class_method :normalize_fields

      def refuse_fields(fields, catalog_version)
        map = FIELD_KIND_BY_VERSION[catalog_version.to_s]
        unless map
          return fail_e("kind_not_in_catalog", { "catalogVersion" => catalog_version })
        end

        fields.each do |f|
          datatype = f["datatype"].to_s
          if datatype == "date" && map["date"].nil?
            return fail_e("date_kind_missing", {
              "field" => f["name"],
              "datatype" => "date",
              "catalogVersion" => catalog_version,
              "wouldHaveBeen" => "text",
              "message" => "date does not compile to text"
            })
          end
          kind = map[datatype]
          next if kind && Vocabulary.component_kind?(kind, version: catalog_version)

          return fail_e("kind_not_in_catalog", {
            "field" => f["name"],
            "datatype" => datatype,
            "catalogVersion" => catalog_version
          })
        end
        nil
      end
      private_class_method :refuse_fields

      def document_for(fields:, step_kind:, title:, frame:, reviewed_digest: nil, blob_digest: nil, catalog_version: CATALOG_VERSION)
        children =
          case step_kind
          when "confirm" then confirm_children(title)
          when "approval" then approval_children(title, reviewed_digest)
          when "preview" then preview_children(title, blob_digest)
          when "error" then error_children
          when "empty" then empty_children
          when "date" then field_nodes(fields, catalog_version) + action_nodes("collect")
          else
            inspect_frame(frame) + field_nodes(fields, catalog_version) + action_nodes(step_kind)
          end

        {
          "schemaVersion" => "acia/v1",
          "componentRegistryVersion" => catalog_version,
          "root" => Acia.node(
            frame.to_s == "j1" ? "j1-pageshell-1" : "page-shell-1",
            "PageShell",
            Acia.slt("landmark", "context", "stack", "many", "static"),
            { "title" => title, "pagePurpose" => frame.to_s == "j1" ? "effect-review" : step_kind },
            children: children
          )
        }
      end
      private_class_method :document_for

      def inspect_frame(frame)
        return [] unless frame.to_s == "j1"

        [
          Acia.node("j1-contextbanner-1", "ContextBanner",
            Acia.slt("status", "context", "inline", "one", "static"),
            { "freshness" => "live", "policy" => "canonical-only", "shown" => "Profile-6 authorization evidence" }),
          Acia.node("j1-evidencepanel-1", "EvidencePanel",
            Acia.slt("article", "evidence", "stack", "one", "inspect"),
            { "source" => "p6:authorization-evidence", "evidenceCid" => "cid:p6:authorization-demo" }),
          Acia.node("j1-timeline-1", "Timeline",
            Acia.slt("timeline", "provenance", "timeline", "many", "static"),
            { "source" => "p5:biography", "items" => "request-then-evidence" }),
          Acia.node("j1-disclosure-1", "Disclosure",
            Acia.slt("article", "provenance", "stack", "one", "disclose"),
            { "label" => "Full provenance", "policy" => "canonical-only" })
        ]
      end
      private_class_method :inspect_frame

      def field_nodes(fields, catalog_version = CATALOG_VERSION)
        map = FIELD_KIND_BY_VERSION.fetch(catalog_version.to_s)
        fields.map { |f|
          if f["datatype"] == "enum"
            Acia.node(
              f["name"] == "decision" ? "j1-decisionform-1" : "field-#{slug(f['name'])}",
              "DecisionForm",
              Acia.slt("form", "authorization", "stack", "one", "collect_effect"),
              {
                "effectContractCid" => "cid:effect-contract:authorization-review",
                "choices" => choices_for(f["enum_key"]),
                "confirmation" => "required",
                "field" => f["name"]
              }
            )
          else
            Acia.node(
              "field-#{slug(f['name'])}",
              map.fetch(f["datatype"].to_s),
              Acia.slt("input", "action", "stack", "one", "collect_effect"),
              { "field" => f["name"], "datatype" => f["datatype"] }
            )
          end
        }
      end
      private_class_method :field_nodes

      def action_nodes(step_kind)
        return [] unless %w[collect decide].include?(step_kind)

        [
          Acia.node("j1-actioncontrol-1", "ActionControl",
            Acia.slt("button", "action", "inline", "one", "confirm"),
            { "effectContractCid" => "cid:effect-contract:authorization-review", "action" => "submit-decision" }),
          Acia.node("j1-refusalnotice-1", "RefusalNotice",
            Acia.slt("alert", "refusal", "stack", "one", "acknowledge"),
            {
              "operation" => "ux.interaction.record",
              "reason" => "UX_EFFECT_AFFORDANCE_DENIED",
              "failedCriteria" => ["authorization.scope"],
              "evidenceRefs" => ["https://ex/p6/authorization-evidence"],
              "remediation" => "Present in-scope Profile-6 authorization evidence and retry.",
              "overridePolicy" => "none"
            },
            variant: "warning")
        ]
      end
      private_class_method :action_nodes

      def confirm_children(title)
        [
          Acia.node("confirm-heading-1", "SemanticText",
            Acia.slt("heading", "action", "stack", "one", "static"),
            { "text" => title.to_s.empty? ? "Confirm" : title }),
          Acia.node("confirm-accept-1", "ActionControl",
            Acia.slt("button", "action", "inline", "one", "confirm"),
            { "action" => "accept", "label" => "Accept" }),
          Acia.node("confirm-reject-1", "ActionControl",
            Acia.slt("button", "action", "inline", "one", "confirm"),
            { "action" => "reject", "label" => "Reject" })
        ]
      end
      private_class_method :confirm_children

      def preview_children(title, blob_digest)
        [
          Acia.node("preview-heading-1", "SemanticText",
            Acia.slt("heading", "context", "stack", "one", "static"),
            { "text" => title.to_s.empty? ? "Preview" : title }),
          Acia.node("preview-blob-1", "SemanticText",
            Acia.slt("figure", "context", "stack", "one", "static"),
            { "blobDigest" => blob_digest.to_s, "text" => blob_digest.to_s })
        ]
      end
      private_class_method :preview_children

      def approval_children(title, reviewed_digest)
        [
          Acia.node("approval-heading-1", "SemanticText",
            Acia.slt("heading", "action", "stack", "one", "static"),
            { "text" => title.to_s.empty? ? "Human review" : title,
              "reviewedDigest" => reviewed_digest.to_s }),
          Acia.node("approval-accept-1", "ActionControl",
            Acia.slt("button", "action", "inline", "one", "confirm"),
            { "action" => "accept", "label" => "Accept" }),
          Acia.node("approval-reject-1", "ActionControl",
            Acia.slt("button", "action", "inline", "one", "confirm"),
            { "action" => "reject", "label" => "Reject" })
        ]
      end
      private_class_method :approval_children

      def error_children
        [
          Acia.node("error-notice-1", "RefusalNotice",
            Acia.slt("alert", "refusal", "stack", "one", "acknowledge"),
            {
              "operation" => "report-error",
              "reason" => "task-error",
              "failedCriteria" => ["task"],
              "evidenceRefs" => ["cid:task:error"],
              "remediation" => "Fix the failing input and retry.",
              "overridePolicy" => "none"
            },
            variant: "warning")
        ]
      end
      private_class_method :error_children

      def empty_children
        [
          Acia.node("empty-state-1", "EmptyState",
            Acia.slt("status", "empty", "stack", "one", "static"),
            { "text" => "No rows" })
        ]
      end
      private_class_method :empty_children

      def choices_for(enum_key)
        case enum_key.to_s
        when "approve-deny" then "approve,deny"
        else enum_key.to_s.tr("-", ",")
        end
      end
      private_class_method :choices_for

      def slug(name)
        name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/\A-|-+\z/, "")[0, 48]
      end
      private_class_method :slug

      def fail_e(reason, because)
        { "ok" => false, "reason" => reason.to_s, "because" => because }
      end
      private_class_method :fail_e
    end
  end
end
