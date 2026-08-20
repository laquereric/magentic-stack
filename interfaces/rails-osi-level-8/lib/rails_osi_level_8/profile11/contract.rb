# frozen_string_literal: true

module RailsOsiLevel8
  module Profile11
    module Contract
      Result = Data.define(:ok, :reason, :because, :record) do
        def to_h
          if ok
            { "ok" => true, "profile_id" => Vocabulary::PROFILE_ID, "record" => record }
          else
            { "ok" => false, "reason" => reason, "because" => because }
          end
        end
      end

      # SHACL minCount 1 on the P11.5 anchors. Missing keys are named, not narrated.
      REQUIRED = {
        "StewardshipTranslation" => %w[refersTo groundedIn audience scope author rendering],
        "TranslationReview" => %w[translation reviewer scope authorityRef outcome]
      }.freeze

      module_function

      def describe
        root = RailsOsiLevel8.config.shape_root
        digest = Vocabulary.shape_digest(root)
        {
          "profile_id" => Vocabulary::PROFILE_ID,
          "profile_key" => Vocabulary::PROFILE_KEY,
          "vocab_iri" => Vocabulary::VOCAB_IRI,
          "shape_bundle" => {
            "path" => Vocabulary::SHAPE_FILE,
            "digest" => "sha256:#{digest}",
            "absolute_path" => Vocabulary.shape_path(root).to_s
          },
          "record_types" => Vocabulary::RECORD_TYPES,
          "dimensions" => Vocabulary::DIMENSIONS,
          "derived_bands" => Vocabulary::BANDS,
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
          "refusal_codes" => Vocabulary::REFUSAL_CODES.transform_keys(&:to_s)
        }
      end

      def check(params)
        params = Request.stringify(params || {})
        rec = params["record"] || params["graph"] || params
        validate!(rec)
        { "ok" => true, "conforms" => true, "profile_id" => Vocabulary::PROFILE_ID }
      end

      def validate(record)
        rec = Request.stringify(record || {})
        type = (rec["@type"] || rec["type"]).to_s.sub(/\Amng:/, "")
        unless Vocabulary::TYPE_KEYS.key?(type)
          return fail_r(Vocabulary::REFUSAL_CODES[:type_invalid], { "type" => type, "allowed" => Vocabulary::RECORD_TYPES })
        end

        band_hit = (rec.keys & Vocabulary::BAND_KEYS)
        unless type == "ActabilityReceipt" || band_hit.empty?
          return fail_r(
            Vocabulary::REFUSAL_CODES[:band_forbidden],
            { "type" => type, "forbidden" => band_hit.sort, "note" => "actabilityBand is derived; persist only on ActabilityReceipt" }
          )
        end

        allowed = Vocabulary::TYPE_KEYS.fetch(type)
        unknown = rec.keys - allowed - Request::ENVELOPE_KEYS
        if unknown.any?
          return fail_r(
            Vocabulary::REFUSAL_CODES[:unknown_predicate],
            { "type" => type, "unknown_predicates" => unknown.sort, "allowed" => allowed }
          )
        end

        Vocabulary::DIMENSIONS.each do |dim, allowed_vals|
          next unless rec.key?(dim)
          # DisputeResolution.dispute is the target IRI, not the none|open|resolved dimension.
          next if type == "DisputeResolution" && dim == "dispute"

          val = rec[dim].to_s
          unless allowed_vals.include?(val)
            return fail_r(
              Vocabulary::REFUSAL_CODES[:enum_invalid],
              { "dimension" => dim, "value" => val, "allowed" => allowed_vals }
            )
          end
        end

        if rec.key?("disposition")
          val = rec["disposition"].to_s
          unless Vocabulary::DISPOSITIONS.include?(val)
            return fail_r(
              Vocabulary::REFUSAL_CODES[:enum_invalid],
              { "dimension" => "disposition", "value" => val, "allowed" => Vocabulary::DISPOSITIONS }
            )
          end
        end

        if rec.key?("outcome")
          val = rec["outcome"].to_s
          unless Vocabulary::REVIEW_OUTCOMES.include?(val)
            return fail_r(
              Vocabulary::REFUSAL_CODES[:enum_invalid],
              { "dimension" => "outcome", "value" => val, "allowed" => Vocabulary::REVIEW_OUTCOMES }
            )
          end
        end

        required = REQUIRED.fetch(type, [])
        missing = required.select { |k| rec[k].nil? || rec[k].to_s.empty? }
        if missing.any?
          return fail_r(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "type" => type, "missing" => missing.sort }
          )
        end

        if type == "ActabilityReceipt" && rec.key?("actabilityBand")
          unless Vocabulary::BANDS.include?(rec["actabilityBand"].to_s)
            return fail_r(
              Vocabulary::REFUSAL_CODES[:enum_invalid],
              { "dimension" => "actabilityBand", "value" => rec["actabilityBand"], "allowed" => Vocabulary::BANDS }
            )
          end
        end

        Result.new(true, nil, nil, rec)
      end

      def validate!(record)
        r = validate(record)
        return r.record if r.ok

        raise KnownRefusal.new(r.reason, r.because)
      end

      def fail_r(reason, because)
        Result.new(false, reason, because.merge("profile_id" => Vocabulary::PROFILE_ID), nil)
      end
      private_class_method :fail_r
    end
  end
end
