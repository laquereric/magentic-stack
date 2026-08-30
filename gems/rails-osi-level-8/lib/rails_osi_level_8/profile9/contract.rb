# frozen_string_literal: true

require "digest"

module RailsOsiLevel8
  module Profile9
    # Profile-9 M0 contract: introspection envelopes + closed-predicate checks.
    # No persistence yet — later milestones add Journey/Flow/Page tables.
    module Contract
      module_function

      def describe
        digest = Vocabulary.shape_digest
        {
          "profile_id" => Vocabulary::PROFILE_ID,
          "profile_key" => Vocabulary::PROFILE_KEY,
          "vocab_iri" => Vocabulary::VOCAB_IRI,
          "shape_bundle" => {
            "path" => Vocabulary::SHAPE_FILE,
            "digest" => "sha256:#{digest}",
            "absolute_path" => Vocabulary.shape_path.to_s
          },
          "component_kinds" => Vocabulary::COMPONENT_KINDS,
          "operations" => Vocabulary::OPERATIONS.map { |op|
            {
              "name" => op[:name],
              "direction" => op[:direction].to_s,
              "result" => op[:result].to_s,
              "status" => op[:status] || "available",
              "summary" => op[:summary],
              "request_shape" => op[:request_shape],
              "response_shape" => op[:response_shape]
            }
          },
          "refusal_codes" => Vocabulary::REFUSAL_CODES.transform_keys(&:to_s),
          "governed_fields" => %w[cid profileId ledgerPlacement digest created wasGeneratedBy],
          "envelope" => jsonld_envelope_template
        }
      end

      NOISE_KEYS = %w[
        operationId idempotencyKey idempotencyScope callerIri forceDeny
        title body references routeKey routeDecision routeReason routeTarget
        routeHopFailure routeFailover routeFailureCode
      ].freeze

      def check(params)
        params = stringify(params || {})
        graph = params["graph"] || params["node"] || params.except(*NOISE_KEYS)
        unknown = collect_unknown_predicates(graph)
        unknown_kinds = collect_unknown_component_kinds(graph)

        if unknown.any?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:unknown_predicate],
            {
              "reason_code" => Vocabulary::REFUSAL_CODES[:shacl_closed],
              "profile_id" => Vocabulary::PROFILE_ID,
              "unknown_predicates" => unknown.sort,
              "shape_digest" => "sha256:#{Vocabulary.shape_digest}",
              "message" => "Profile-9 closed shape forbids unknown predicates"
            }
          )
        end

        if unknown_kinds.any?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:unknown_component],
            {
              "reason_code" => Vocabulary::REFUSAL_CODES[:acia_contract_invalid],
              "profile_id" => Vocabulary::PROFILE_ID,
              "unknown_component_kinds" => unknown_kinds.sort,
              "allowed" => Vocabulary::COMPONENT_KINDS
            }
          )
        end

        control_violations = collect_control_action_violations(graph, "graph", [])
        if control_violations.any?
          invalid = control_violations.flat_map { |v| Array(v["invalid"]) }.uniq
          kinds = control_violations.map { |v| v["componentKind"] }.compact.uniq
          because = {
            "reason_code" => Vocabulary::REFUSAL_CODES[:acia_contract_invalid],
            "profile_id" => Vocabulary::PROFILE_ID,
            "paths" => control_violations.map { |v| v["path"] },
            "invalid" => invalid
          }
          because["componentKind"] = kinds.size == 1 ? kinds.first : kinds
          raise KnownRefusal.new(Vocabulary::REFUSAL_CODES[:acia_contract_invalid], because)
        end

        inspecting = graph.is_a?(Hash) && graph["projectionKind"].to_s == "inspect"
        state_violations = collect_presentation_state_violations(graph, "graph", [], inspecting)
        if state_violations.any?
          invalid = state_violations.flat_map { |v| Array(v["invalid"]) }.uniq
          because = {
            "reason_code" => Vocabulary::REFUSAL_CODES[:acia_contract_invalid],
            "profile_id" => Vocabulary::PROFILE_ID,
            "paths" => state_violations.map { |v| v["path"] },
            "invalid" => invalid
          }
          raise KnownRefusal.new(Vocabulary::REFUSAL_CODES[:acia_contract_invalid], because)
        end

        refusal_violations = collect_refusal_notice_violations(graph, "graph", [])
        if refusal_violations.any?
          missing = refusal_violations.flat_map { |v| Array(v["missing"]) }.uniq
          invalid = refusal_violations.flat_map { |v| Array(v["invalid"]) }.uniq
          because = {
            "reason_code" => Vocabulary::REFUSAL_CODES[:acia_contract_invalid],
            "profile_id" => Vocabulary::PROFILE_ID,
            "componentKind" => "RefusalNotice",
            "paths" => refusal_violations.map { |v| v["path"] }
          }
          because["missing"] = missing unless missing.empty?
          because["invalid"] = invalid unless invalid.empty?
          raise KnownRefusal.new(Vocabulary::REFUSAL_CODES[:acia_contract_invalid], because)
        end

        {
          "ok" => true,
          "profile_id" => Vocabulary::PROFILE_ID,
          "conforms" => true,
          "shape_digest" => "sha256:#{Vocabulary.shape_digest}",
          "checked_predicates" => flatten_keys(graph).uniq.sort
        }
      end

      def jsonld_envelope_template
        {
          "@context" => {
            "@vocab" => Vocabulary::VOCAB_IRI,
            "cid" => "@id",
            "type" => "@type",
            "profileId" => "#{Vocabulary::VOCAB_IRI}profileId",
            "ledgerPlacement" => "#{Vocabulary::VOCAB_IRI}ledgerPlacement",
            "digest" => "#{Vocabulary::VOCAB_IRI}digest"
          },
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical"
        }
      end

      STRUCTURAL_WRAPPERS = %w[graph node root rootNode document children child slots slot].freeze

      def collect_unknown_predicates(obj, acc = [])
        case obj
        when Hash
          obj.each do |k, v|
            key = k.to_s
            # TypedProps.valueJson is rdf:JSON; JSON-LD @context is a context object.
            # Interior keys are not Profile-9 RDF predicates.
            next if key == "valueJson" || key == "@context"

            acc << key unless Vocabulary.allowed_predicate?(key) || STRUCTURAL_WRAPPERS.include?(key)
            collect_unknown_predicates(v, acc)
          end
        when Array
          obj.each { |v| collect_unknown_predicates(v, acc) }
        end
        acc
      end
      private_class_method :collect_unknown_predicates

      def collect_presentation_state_violations(obj, path, acc, inspecting)
        case obj
        when Hash
          kind = (obj["componentKind"] || obj["component_kind"]).to_s
          if !kind.empty?
            payload = Vocabulary.control_action_payload_from(obj)
            v = Vocabulary.presentation_state_violation(payload, path: path, kind: kind, inspecting: inspecting)
            acc << v if v
          end
          obj.each do |k, val|
            collect_presentation_state_violations(val, "#{path}.#{k}", acc, inspecting)
          end
        when Array
          obj.each_with_index { |val, i| collect_presentation_state_violations(val, "#{path}[#{i}]", acc, inspecting) }
        end
        acc
      end
      private_class_method :collect_presentation_state_violations

      def collect_control_action_violations(obj, path, acc)
        case obj
        when Hash
          kind = (obj["componentKind"] || obj["component_kind"]).to_s
          if kind == "ActionControl" || kind == "DecisionForm"
            payload = Vocabulary.control_action_payload_from(obj)
            v = Vocabulary.control_action_violation(payload, path: path, kind: kind)
            acc << v if v
          end
          obj.each do |k, v|
            collect_control_action_violations(v, "#{path}.#{k}", acc)
          end
        when Array
          obj.each_with_index { |v, i| collect_control_action_violations(v, "#{path}[#{i}]", acc) }
        end
        acc
      end
      private_class_method :collect_control_action_violations

      def collect_refusal_notice_violations(obj, path, acc)
        case obj
        when Hash
          kind = obj["componentKind"] || obj["component_kind"]
          if kind.to_s == "RefusalNotice"
            payload = Vocabulary.refusal_notice_payload_from(obj)
            v = Vocabulary.refusal_notice_violation(payload, path: path)
            acc << v if v
          end
          obj.each do |k, v|
            collect_refusal_notice_violations(v, "#{path}.#{k}", acc)
          end
        when Array
          obj.each_with_index { |v, i| collect_refusal_notice_violations(v, "#{path}[#{i}]", acc) }
        end
        acc
      end
      private_class_method :collect_refusal_notice_violations

      def collect_unknown_component_kinds(obj, acc = [])
        case obj
        when Hash
          kind = obj["componentKind"] || obj["component_kind"]
          acc << kind.to_s if kind && !Vocabulary.component_kind?(kind)
          obj.each_value { |v| collect_unknown_component_kinds(v, acc) }
        when Array
          obj.each { |v| collect_unknown_component_kinds(v, acc) }
        end
        acc
      end
      private_class_method :collect_unknown_component_kinds

      def flatten_keys(obj, acc = [])
        case obj
        when Hash
          obj.each do |k, v|
            acc << k.to_s
            flatten_keys(v, acc)
          end
        when Array
          obj.each { |v| flatten_keys(v, acc) }
        end
        acc
      end
      private_class_method :flatten_keys

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
