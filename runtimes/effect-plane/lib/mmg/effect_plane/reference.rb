# frozen_string_literal: true
module Mmg
  module EffectPlane
    # The retention anchor for a result reference.
    #
    # An IRI may identify a result INSIDE an immutable snapshot digest, together
    # with its branch, typed locator, and retention policy. The digest is not
    # itself the IRI protocol, and this gem does not define that protocol's
    # authorization model.
    #
    # Garbage collection must not create a false "not found": a collected
    # snapshot resolves to :snapshot_collected with its former digest, which is
    # a different fact from an unknown IRI.
    module Reference
      module_function

      FIELDS = %i[iri snapshot_digest branch locator media_type schema_ref retention].freeze

      # The four outcomes a consumer must be able to tell apart.
      REFUSALS = %i[unknown_iri reference_inaccessible reference_expired snapshot_collected].freeze

      def describe(reference)
        return refuse(:unknown_iri, "expected a reference Hash") unless reference.is_a?(Hash)
        return refuse(:unknown_iri, "reference carries no iri") if blank?(reference[:iri])
        return refuse(:reference_inaccessible, "reference names no snapshot digest") if blank?(reference[:snapshot_digest])

        { ok: true, reference: FIELDS.to_h { |f| [f, reference[f]] } }
      end

      # Ask the resolver for AT MOST max_bytes, and bound whatever comes back.
      # The second bound is not redundant: a resolver that ignores the cap must
      # not be able to flood a caller with an unbounded database or graph.
      def preview(reference:, resolver:, max_bytes:)
        d = describe(reference)
        return d unless d[:ok]
        return refuse(:invalid_max_bytes, "max_bytes must be a positive Integer") unless max_bytes.is_a?(Integer) && max_bytes.positive?
        return refuse(:no_resolver, "a resolver capability is required") unless resolver.respond_to?(:call)

        raw = resolver.call(reference, max_bytes)
        return collected(reference, raw) if collected?(raw)
        return refuse(:reference_inaccessible, "resolver refused: #{raw[:reason]}") if raw.is_a?(Hash) && raw[:ok] == false
        return refuse(:reference_inaccessible, "resolver returned no body") unless raw.is_a?(Hash) && raw[:body]

        body      = raw[:body].to_s
        truncated = body.bytesize > max_bytes
        sample    = truncated ? body.byteslice(0, max_bytes) : body

        { ok: true, iri: reference[:iri], snapshot_digest: reference[:snapshot_digest],
          branch: reference[:branch], locator: reference[:locator],
          media_type: raw[:media_type] || reference[:media_type], schema_ref: reference[:schema_ref],
          bytes: sample.bytesize, truncated: truncated, sample: sample }
      end

      def resolve(reference:, resolver:)
        d = describe(reference)
        return d unless d[:ok]
        return refuse(:no_resolver, "a resolver capability is required") unless resolver.respond_to?(:call)

        raw = resolver.call(reference, nil)
        return collected(reference, raw) if collected?(raw)
        return refuse(:reference_inaccessible, "resolver refused: #{raw[:reason]}") if raw.is_a?(Hash) && raw[:ok] == false

        { ok: true, iri: reference[:iri], snapshot_digest: reference[:snapshot_digest],
          branch: reference[:branch], handle: raw.is_a?(Hash) ? raw[:handle] : nil }
      end

      # The stable refusal a retention owner must be able to serve AFTER the
      # bytes are gone, so a collected snapshot never reads as an unknown IRI.
      def tombstone(reference:, collection_receipt:)
        d = describe(reference)
        return d unless d[:ok]

        r = collection_receipt.is_a?(Hash) ? collection_receipt : {}
        return refuse(:reference_inaccessible, "a collection receipt must name the collected digest") if blank?(r[:former_snapshot_digest])

        { ok: false, reason: :snapshot_collected,
          because: "the referenced snapshot was collected under retention policy",
          iri: reference[:iri], former_snapshot_digest: r[:former_snapshot_digest],
          collected_at: r[:collected_at], policy_reason: r[:policy_reason] }
      end

      def collected?(raw) = raw.is_a?(Hash) && (raw[:reason] == :collected || raw[:collected])

      def collected(reference, raw)
        tombstone(reference: reference,
                  collection_receipt: raw[:tombstone] || { former_snapshot_digest: reference[:snapshot_digest] })
      end
      private_class_method :collected

      def blank?(v) = v.nil? || v.to_s.strip.empty?

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
      private_class_method :refuse
    end
  end
end
