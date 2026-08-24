# frozen_string_literal: true
require "base64"
require "vv-blob"

module Mmg
  module Blob
    # Storage exposed at the boundary: to a thin-slice Rails app as plain Ruby,
    # and to an LLM as tool calls over the same operations.
    #
    # ONE definition, two callers. If the app and the model reached storage by
    # different paths they would drift, and the one that drifted would be the one
    # nobody was watching.
    #
    # Bytes cross the wire BASE64. JSON has no binary type, and a blob store that
    # quietly mangles anything with a null in it is worse than one that refuses.
    module Operations
      module_function

      def store
        @store ||= ::Vv::Blob::Store.open(path: path)
      end

      def path
        ENV.fetch("MMG_BLOB_PATH", "db/blobs.sqlite3")
      end

      def reset!(new_path = nil)
        ENV["MMG_BLOB_PATH"] = new_path if new_path
        @store = nil
      end

      # PUSH. Takes base64, returns the digest it minted.
      def put(params)
        b64 = params["bytes"] || params[:bytes]
        return refuse(:content_required, "blob.put needs bytes (base64)") if b64.nil?

        raw = begin
          ::Base64.strict_decode64(b64.to_s)
        rescue ArgumentError
          return refuse(:bytes_not_base64, "bytes must be strict base64; JSON has no binary type")
        end

        store.put(raw, content_type: params["content_type"] || params[:content_type])
      end

      # PULL. Returns base64 for the same reason.
      def get(params)
        digest = (params["digest"] || params[:digest]).to_s
        return refuse(:digest_required, "blob.get needs a digest") if digest.empty?

        res = store.get(digest)
        return res unless res[:ok]

        res.merge(bytes: ::Base64.strict_encode64(res[:bytes].to_s), encoding: "base64")
      end

      # PULL. Existence and size WITHOUT moving the bytes -- the answer an agent
      # usually wants, and the one that costs nothing to give.
      def stat(params)
        digest = (params["digest"] || params[:digest]).to_s
        return refuse(:digest_required, "blob.stat needs a digest") if digest.empty?

        res = store.get(digest)
        return res unless res[:ok]

        { ok: true, digest: res[:digest], size: res[:size],
          content_type: res[:content_type], created_at: res[:created_at] }
      end

      def list(params = {})
        limit = (params["limit"] || params[:limit] || 100).to_i.clamp(1, 1000)
        store.digests(limit: limit)
      end

      def refuse(reason, because) = { ok: false, reason: reason, because: because }
    end
  end
end
