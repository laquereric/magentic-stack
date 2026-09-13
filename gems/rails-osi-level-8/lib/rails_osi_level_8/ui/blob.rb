# frozen_string_literal: true

require "digest"

module RailsOsiLevel8
  module Ui
    # Content-addressed canvas bytes. Digest is the name. Never a graph IRI.
    # Mind-pod's CPCP `blob.put` (mmg-blob / vv-blob) is the durable store;
    # this is the same rule in-process so preview can cite a digest in gem
    # specs without depending on those gems.
    module Blob
      GRAPH_KEYS = %w[graph_iri spec_iri graphIri specIri].freeze

      module_function

      def reset!
        @store = {}
      end

      def put(params)
        params = stringify(params)
        minted = GRAPH_KEYS.select { |k| present?(params[k]) }
        if minted.any?
          raise KnownRefusal.new(
            "graph_iri_refused",
            { "keys" => minted, "message" => "canvas does not mint graph IRIs; digest is the name" }
          )
        end
        bytes = params["bytes"]
        if bytes.nil?
          raise KnownRefusal.new("content_required", { "message" => "blob.put needs bytes" })
        end
        raw = bytes.to_s.dup.force_encoding(Encoding::BINARY)
        digest = "sha256:#{Digest::SHA256.hexdigest(raw)}"
        store[digest] = raw
        rec = { "ok" => true, "digest" => digest, "size" => raw.bytesize }
        GRAPH_KEYS.each { |k| rec[k] = nil }
        rec.reject { |k, _| GRAPH_KEYS.include?(k) }
      end

      def get(digest)
        d = digest.to_s
        raw = store[d]
        unless raw
          raise KnownRefusal.new(
            Profile9::Vocabulary::REFUSAL_CODES[:lineage_unresolved],
            { "resource" => "blob", "digest" => d }
          )
        end
        { "ok" => true, "digest" => d, "size" => raw.bytesize, "bytes" => raw }
      end

      def has?(digest)
        store.key?(digest.to_s)
      end

      def store
        @store ||= {}
      end
      private_class_method :store

      def present?(val)
        !val.to_s.empty?
      end
      private_class_method :present?

      def stringify(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = v }
        else { "bytes" => obj }
        end
      end
      private_class_method :stringify
    end
  end
end
