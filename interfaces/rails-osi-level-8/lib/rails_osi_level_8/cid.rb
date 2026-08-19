# frozen_string_literal: true

require "digest"
require "json"

module RailsOsiLevel8
  module Cid
    module_function

    def for_payload(payload)
      canonical = canonical_json(payload)
      digest = Digest::SHA256.hexdigest(canonical)
      "cid:sha256:#{digest}"
    end

    def digest_for(payload)
      Digest::SHA256.hexdigest(canonical_json(payload))
    end

    def for_record(record)
      for_payload(
        "@type" => record.class.name,
        "id" => record.try(:id),
        "body" => record.try(:body),
        "title" => record.try(:title),
        "created_at" => record.try(:created_at)&.iso8601
      )
    end

    def canonical_json(obj)
      JSON.generate(deep_sort(obj))
    end

    def deep_sort(obj)
      case obj
      when Hash
        obj.keys.map(&:to_s).sort.each_with_object({}) { |k, h| h[k] = deep_sort(obj[k] || obj[k.to_sym]) }
      when Array
        obj.map { |v| deep_sort(v) }
      else
        obj
      end
    end
  end
end
