# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Profile9
    # P9.1 — minimal in-repo ACIA document schema + validator.
    # HTML is never a source; props are closed; SLT tuple is mandatory.
    module Acia
      SEMANTIC_ROLES = %w[
        landmark heading list listitem article figure form
        input button status alert dialog table timeline
      ].freeze
      CONTENT_ROLES = %w[
        context evidence provenance authorization observation
        outcome drift action navigation help empty refusal
      ].freeze
      LAYOUT_KINDS = %w[stack inline grid split overlay timeline table].freeze
      LAYOUT_ARITIES = %w[one two three many].freeze
      BEHAVIOR_KINDS = %w[static disclose filter navigate inspect collect_effect acknowledge confirm].freeze
      VARIANTS = %w[default compact expanded quiet emphasis warning danger disabled readonly].freeze

      FORBIDDEN_PROP_KEYS = %w[
        html style css className class dangerouslySetInnerHTML innerHTML
        rawHtml rawCSS onClick onclick href javascript childrenHtml
      ].freeze

      NODE_KEYS = %w[
        nodeId componentKind slt props slots variant children
        tokenSignature
      ].freeze

      SLT_KEYS = %w[
        semanticRole contentRole layoutKind layoutArity
        behaviorKind responsiveSignature tokenSignature
      ].freeze

      Result = Data.define(:conforms?, :digest, :reason, :because) do
        def to_h
          { "conforms" => conforms?, "digest" => digest, "reason" => reason, "because" => because }
        end
      end

      module_function

      def validate(doc)
        doc = stringify(doc || {})
        return fail_r("acia_envelope_invalid", { "missing" => "root" }) unless doc["root"].is_a?(Hash) || doc["rootNode"].is_a?(Hash)

        root = doc["root"] || doc["rootNode"]
        schema_version = doc["schemaVersion"] || doc["schema_version"] || "acia/v1"
        return fail_r("acia_schema_version_invalid", { "schemaVersion" => schema_version }) unless schema_version.to_s.start_with?("acia/")

        walk = validate_node(root, path: "root")
        return walk unless walk.conforms?

        digest = canonical_digest(doc)
        Result.new(true, "sha256:#{digest}", nil, { "schemaVersion" => schema_version })
      end

      def validate!(doc)
        r = validate(doc)
        return r if r.conforms?

        raise KnownRefusal.new(
          r.reason || Vocabulary::REFUSAL_CODES[:acia_contract_invalid],
          (r.because || {}).merge("profile_id" => Vocabulary::PROFILE_ID)
        )
      end

      def eight_panel_fixture
        panels = %w[
          CyborgChannel ReferencePassing SwitchYard DurableExecution
          Biography Authorization ObservationOutcome LearningLoop
        ]
        {
          "schemaVersion" => "acia/v1",
          "componentRegistryVersion" => "ghis-17@1",
          "root" => {
            "nodeId" => "governance-shell",
            "componentKind" => "PageShell",
            "slt" => slt("landmark", "context", "stack", "one", "static"),
            "props" => { "propsSchemaCid" => "cid:schema:pageshell", "valueJson" => { "title" => "Governance" } },
            "variant" => { "variantName" => "default" },
            "slots" => [{ "name" => "body", "ordered" => true }],
            "children" => panels.each_with_index.map { |name, i|
              {
                "nodeId" => "panel-#{i + 1}-#{name.downcase}",
                "componentKind" => "PanelFrame",
                "slt" => slt("article", "context", "stack", "one", "static"),
                "props" => {
                  "propsSchemaCid" => "cid:schema:panelframe",
                  "valueJson" => { "title" => name, "panelKey" => name }
                },
                "variant" => { "variantName" => "default" },
                "slots" => [],
                "children" => [
                  {
                    "nodeId" => "banner-#{i + 1}",
                    "componentKind" => "ContextBanner",
                    "slt" => slt("status", "context", "inline", "one", "static"),
                    "props" => {
                      "propsSchemaCid" => "cid:schema:contextbanner",
                      "valueJson" => { "freshness" => "live", "policy" => "canonical-only" }
                    },
                    "variant" => { "variantName" => "default" },
                    "slots" => [],
                    "children" => []
                  }
                ]
              }
            }
          }
        }
      end

      def slt(semantic, content, layout, arity, behavior)
        {
          "semanticRole" => semantic,
          "contentRole" => content,
          "layoutKind" => layout,
          "layoutArity" => arity,
          "behaviorKind" => behavior,
          "responsiveSignature" => "default",
          "tokenSignature" => { "setRef" => "tokens:ghis@1" }
        }
      end
      private_class_method :slt

      def validate_node(node, path:)
        return fail_r("acia_node_invalid", { "path" => path, "message" => "node must be object" }) unless node.is_a?(Hash)

        unknown = node.keys.map(&:to_s) - NODE_KEYS
        return fail_r("acia_unknown_node_key", { "path" => path, "unknown" => unknown }) if unknown.any?

        kind = node["componentKind"].to_s
        return fail_r(Vocabulary::REFUSAL_CODES[:unknown_component], { "path" => path, "componentKind" => kind }) unless Vocabulary.component_kind?(kind)

        node_id = node["nodeId"].to_s
        return fail_r("acia_node_id_invalid", { "path" => path }) unless node_id.match?(/\A[a-z][a-z0-9_-]{2,63}\z/)

        slt_r = validate_slt(node["slt"], path: "#{path}.slt")
        return slt_r unless slt_r.conforms?

        props_r = validate_props(node["props"], path: "#{path}.props")
        return props_r unless props_r.conforms?

        var = node["variant"]
        return fail_r("acia_variant_required", { "path" => path }) unless var.is_a?(Hash)
        vname = var["variantName"].to_s
        return fail_r("acia_variant_invalid", { "path" => path, "variantName" => vname }) unless VARIANTS.include?(vname)

        children = node["children"] || []
        return fail_r("acia_children_invalid", { "path" => path }) unless children.is_a?(Array)

        children.each_with_index do |child, i|
          r = validate_node(child, path: "#{path}.children[#{i}]")
          return r unless r.conforms?
        end

        Result.new(true, nil, nil, {})
      end
      private_class_method :validate_node

      def validate_slt(slt, path:)
        return fail_r("acia_slt_required", { "path" => path }) unless slt.is_a?(Hash)

        unknown = slt.keys.map(&:to_s) - SLT_KEYS
        return fail_r("acia_slt_unknown_key", { "path" => path, "unknown" => unknown }) if unknown.any?

        checks = [
          ["semanticRole", SEMANTIC_ROLES],
          ["contentRole", CONTENT_ROLES],
          ["layoutKind", LAYOUT_KINDS],
          ["layoutArity", LAYOUT_ARITIES],
          ["behaviorKind", BEHAVIOR_KINDS]
        ]
        checks.each do |key, allowed|
          val = slt[key].to_s
          return fail_r("acia_slt_invalid", { "path" => path, "field" => key, "value" => val }) unless allowed.include?(val)
        end
        return fail_r("acia_slt_responsive_invalid", { "path" => path }) unless slt["responsiveSignature"].to_s.match?(/\A[a-z0-9._-]+\z/)
        return fail_r("acia_slt_token_required", { "path" => path }) unless slt["tokenSignature"].is_a?(Hash)

        Result.new(true, nil, nil, {})
      end
      private_class_method :validate_slt

      def validate_props(props, path:)
        return fail_r("acia_props_required", { "path" => path }) unless props.is_a?(Hash)
        return fail_r("acia_props_schema_required", { "path" => path }) if props["propsSchemaCid"].to_s.empty?
        return fail_r("acia_props_value_required", { "path" => path }) unless props.key?("valueJson")

        value = props["valueJson"]
        return fail_r("acia_props_value_must_be_object", { "path" => path }) unless value.is_a?(Hash)

        forbidden = value.keys.map(&:to_s) & FORBIDDEN_PROP_KEYS
        if forbidden.any?
          return fail_r(
            Vocabulary::REFUSAL_CODES[:acia_contract_invalid],
            { "path" => path, "forbidden_props" => forbidden, "message" => "raw HTML/style props refused" }
          )
        end

        # Closed-ish: no nested html/style smuggling
        if deep_has_forbidden?(value)
          return fail_r(
            Vocabulary::REFUSAL_CODES[:acia_contract_invalid],
            { "path" => path, "message" => "nested forbidden prop key" }
          )
        end

        Result.new(true, nil, nil, {})
      end
      private_class_method :validate_props

      def deep_has_forbidden?(obj)
        case obj
        when Hash
          return true if (obj.keys.map(&:to_s) & FORBIDDEN_PROP_KEYS).any?
          obj.values.any? { |v| deep_has_forbidden?(v) }
        when Array
          obj.any? { |v| deep_has_forbidden?(v) }
        else
          false
        end
      end
      private_class_method :deep_has_forbidden?

      def canonical_digest(doc)
        Digest::SHA256.hexdigest(JSON.generate(deep_sort(stringify(doc))))
      end
      private_class_method :canonical_digest

      def deep_sort(obj)
        case obj
        when Hash
          obj.keys.map(&:to_s).sort.each_with_object({}) { |k, h| h[k] = deep_sort(obj[k]) }
        when Array then obj.map { |v| deep_sort(v) }
        else obj
        end
      end
      private_class_method :deep_sort

      def stringify(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
        when Array then obj.map { |v| stringify(v) }
        else obj
        end
      end
      private_class_method :stringify

      def fail_r(reason, because)
        Result.new(false, nil, reason, because)
      end
      private_class_method :fail_r
    end
  end
end
