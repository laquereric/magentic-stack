# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Profile11
    module Request
      ENVELOPE_KEYS = %w[operationId idempotencyKey idempotencyScope callerIri].freeze

      module_function

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

      def digest(obj)
        "sha256:#{Digest::SHA256.hexdigest(JSON.generate(deep_sort(stringify(obj || {}))))}"
      end

      def closed!(params, allowed, reason: Vocabulary::REFUSAL_CODES[:unknown_predicate])
        params = stringify(params || {})
        unknown = params.keys - allowed - ENVELOPE_KEYS
        if unknown.any?
          raise KnownRefusal.new(
            reason,
            {
              "unknown_predicates" => unknown.sort,
              "allowed" => allowed,
              "profile_id" => Vocabulary::PROFILE_ID
            }
          )
        end
        params
      end

      def require_key!(params, key)
        val = params[key]
        val = val.to_s if val.is_a?(String) || val.nil?
        if val.nil? || val.to_s.empty?
          raise KnownRefusal.new(
            Vocabulary::REFUSAL_CODES[:envelope_invalid],
            { "missing" => key, "profile_id" => Vocabulary::PROFILE_ID }
          )
        end
        val
      end
    end
  end
end
