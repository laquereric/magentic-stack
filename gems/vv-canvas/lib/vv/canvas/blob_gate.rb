# frozen_string_literal: true

module Vv
  module Canvas
    # Canvas versions are bytes named by digest. graph_iri refused.
    module BlobGate
      GRAPH_KEYS = %w[graph_iri spec_iri graphIri specIri].freeze
      DIGEST = /\Asha256:[0-9a-f]{64}\z/

      module_function

      def stringify(params)
        params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
      end

      def graph_iri_refusal(params)
        p = stringify(params)
        minted = GRAPH_KEYS.select { |k| !p[k].to_s.empty? }
        return nil if minted.empty?

        {
          "ok" => false,
          "reason" => "graph_iri_refused",
          "because" => {
            "keys" => minted,
            "message" => "canvas does not mint graph IRIs; digest is the name"
          }
        }
      end

      def digest_refusal(digest)
        d = digest.to_s
        return nil if d.match?(DIGEST)

        {
          "ok" => false,
          "reason" => "blob_digest_required",
          "because" => { "blobDigest" => d, "want" => "sha256:<64 hex>" }
        }
      end

      def put(params)
        refused = graph_iri_refusal(params)
        return refused if refused

        unless defined?(::Mmg::Blob::Operations)
          return { "ok" => false, "reason" => "blob_store_unavailable",
                   "because" => "mmg-blob is not loaded" }
        end

        Mmg::Blob::Operations.put(stringify(params))
      end

      def get(params)
        return { "ok" => false, "reason" => "blob_store_unavailable" } unless defined?(::Mmg::Blob::Operations)

        Mmg::Blob::Operations.get(stringify(params))
      end

      def list(params = {})
        return { "ok" => false, "reason" => "blob_store_unavailable" } unless defined?(::Mmg::Blob::Operations)

        Mmg::Blob::Operations.list(stringify(params))
      end

      def stat(params)
        return { "ok" => false, "reason" => "blob_store_unavailable" } unless defined?(::Mmg::Blob::Operations)

        Mmg::Blob::Operations.stat(stringify(params))
      end
    end
  end
end
