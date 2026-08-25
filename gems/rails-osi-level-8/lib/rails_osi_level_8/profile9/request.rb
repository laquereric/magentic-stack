# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Profile9
    # Closed request-shape helpers shared by P9.3 PULLs and P9.4 mutations.
    module Request
      ENVELOPE_KEYS = %w[operationId idempotencyKey idempotencyScope callerIri].freeze

      module_function

      def closed!(params, allowed)
        params = stringify(params || {})
        unknown = params.keys - allowed - ENVELOPE_KEYS
        if unknown.any?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:unknown_predicate],
            {
              "reason_code" => Vocabulary::REFUSAL_CODES[:shacl_closed],
              "profile_id" => Vocabulary::PROFILE_ID,
              "unknown_predicates" => unknown.sort,
              "allowed" => allowed,
              "message" => "Profile-9 closed request shape forbids unknown keys"
            }
          )
        end
        params
      end

      def require_cid!(params, key)
        val = params[key].to_s
        if val.empty?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "missing" => key, "profile_id" => Vocabulary::PROFILE_ID }
          )
        end
        val
      end

      def unresolved!(kind, cid)
        raise KnownRefusal.new(
          Vocabulary::REFUSAL_CODES[:lineage_unresolved],
          { "resource" => kind, "cid" => cid, "profile_id" => Vocabulary::PROFILE_ID }
        )
      end

      def present?(val)
        !val.to_s.empty?
      end

      def digest(obj)
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(deep_sort(stringify(obj || {}))))}"
      end

      def stringify(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify(v) }
        when Array then obj.map { |v| stringify(v) }
        else obj
        end
      end

      def deep_sort(obj)
        case obj
        when Hash
          obj.keys.map(&:to_s).sort.each_with_object({}) { |k, h| h[k] = deep_sort(obj[k]) }
        when Array then obj.map { |v| deep_sort(v) }
        else obj
        end
      end
    end
  end
end
