# frozen_string_literal: true

module RailsOsiLevel8
  # Grounding = closed-shape validation + profile evidence.
  # Deviation (M1): mm-shacl-reader is not wired in-process here (Rust/Ruby facade lives in
  # magentic-market-ai). We apply a minimal closed-shape check keyed by profile catalog entry,
  # returning the same Result contract so SHACL can replace MmShaclValidator later.
  module Grounding
    Result = Data.define(:conforms?, :profile_id, :shape_id, :shape_digest, :violations) do
      def safe_report
        {
          "profile_id" => profile_id,
          "shape_id" => shape_id,
          "shape_digest" => shape_digest,
          "violations" => violations.first(20).map { |v|
            {
              "focus_node" => v[:focus_node] || v["focus_node"],
              "path" => v[:path] || v["path"],
              "constraint" => v[:constraint] || v["constraint"],
              "message" => v[:message] || v["message"]
            }
          }
        }
      end
    end

    module_function

    def validate(graph, profile:)
      entry = RailsOsiLevel8.config.profile_catalog&.[](profile) ||
              RailsOsiLevel8.config.profile_catalog&.fetch(profile)
      graph = stringify_keys(graph || {})
      violations = closed_shape_violations(graph, profile)
      Result.new(
        violations.empty?,
        entry&.id || profile.to_s,
        entry&.shape_iri || profile.to_s,
        entry&.sha256 || "unsigned",
        violations
      )
    rescue KeyError
      Result.new(
        false,
        profile.to_s,
        profile.to_s,
        "unknown",
        [{ focus_node: nil, path: nil, constraint: "catalog", message: "unknown profile shape #{profile}" }]
      )
    end

    def closed_shape_violations(graph, profile)
      case profile.to_s
      when "P1::NoteCreateEffectShape", "P4::NoteCreateEffectShape"
        req = []
        req << violation(graph, "cpcp:idempotencyKey", "must have at least one idempotency key") if blank?(graph["idempotencyKey"] || graph["operationId"])
        req << violation(graph, "title", "must have a title") if blank?(graph["title"])
        # Closed-ish: refuse explicit private_local placement from client
        if graph.key?("ledgerPlacement") || graph.key?("ledger_placement")
          req << violation(graph, "ledgerPlacement", "client must not supply ledger placement")
        end
        req
      when "P1::NoteListPullShape"
        [] # PULL request params are optional filters
      when "P1::NoteCreateContextShape", "P1::NoteListContextShape", "P4::DurableReceiptShape"
        []
      else
        []
      end
    end
    private_class_method :closed_shape_violations

    def violation(graph, path, message)
      {
        focus_node: graph["@id"] || graph["cid"],
        path: path,
        constraint: "MinCountConstraintComponent",
        message: message
      }
    end
    private_class_method :violation

    def blank?(v)
      v.nil? || (v.respond_to?(:empty?) && v.empty?)
    end
    private_class_method :blank?

    def stringify_keys(obj)
      case obj
      when Hash
        obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_keys(v) }
      when Array
        obj.map { |v| stringify_keys(v) }
      else
        obj
      end
    end
    private_class_method :stringify_keys
  end
end
