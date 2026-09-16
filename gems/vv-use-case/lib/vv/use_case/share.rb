# frozen_string_literal: true

require "json"

module Vv
  module UseCase
    # blob digest → model → vv-miro Share.push. Token stays on BACK.
    module Share
      DIGEST = /\Asha256:[0-9a-f]{64}\z/
      GRAPH_KEYS = %w[graph_iri spec_iri graphIri specIri].freeze

      module_function

      def call(params)
        p = stringify(params)
        minted = GRAPH_KEYS.select { |k| !p[k].to_s.empty? }
        unless minted.empty?
          return refuse("graph_iri_refused", "canvas does not mint graph IRIs; digest is the name")
        end

        digest = (p["blobDigest"] || p["blob_digest"] || p["digest"]).to_s
        gate = digest_refusal(digest)
        return gate if gate

        blob = fetch_blob(digest)
        return blob unless ok?(blob)

        json = decode_json(blob)
        return json unless ok?(json)

        title = p["title"].to_s
        title = "Untitled" if title.empty?
        model = Model.extract(json["fabric"], title: title, digest: digest)
        return model unless ok?(model)

        miro = load_miro
        return miro unless ok?(miro)

        token = ENV["MIRO_ACCESS_TOKEN"].to_s
        token = ENV["MIRO_TOKEN"].to_s if token.empty?
        if token.empty? && !UseCase.miro_client
          return refuse("token_required", "MIRO_ACCESS_TOKEN is not set on BACK")
        end

        client = UseCase.miro_client
        client = client.call if client.respond_to?(:call)
        if client.nil?
          begin
            client = Vv::Miro::Client.new(access_token: token)
          rescue StandardError => e
            return refuse("miro_unavailable", e.message.to_s[0, 200])
          end
        end

        name = "#{title} (#{digest[0, 19]})"
        pushed = Vv::Miro::Share.push(client, name: name, effects: Map.effects(model))
        overlay(pushed, digest, p)
      end

      def extract(params)
        p = stringify(params)
        digest = (p["blobDigest"] || p["blob_digest"] || p["digest"]).to_s
        fabric = p["json"] || p["fabric"]
        if fabric.nil? && !digest.empty?
          gate = digest_refusal(digest)
          return gate if gate

          blob = fetch_blob(digest)
          return blob unless ok?(blob)

          json = decode_json(blob)
          return json unless ok?(json)

          fabric = json["fabric"]
        end
        return refuse("empty_use_case", "extract needs blobDigest or json") if fabric.nil?

        Model.extract(fabric, title: p["title"], digest: digest)
      end

      def fetch_blob(digest)
        getter = UseCase.blob_get
        unless getter
          return refuse("blob_store_unavailable", "Vv::UseCase.blob_get is not wired")
        end

        rec = getter.respond_to?(:call) ? getter.call(digest) : getter
        rec = stringify(rec)
        return rec unless ok?(rec)

        rec
      end

      def decode_json(blob)
        raw = blob["bytes"] || blob[:bytes]
        if raw.to_s.empty?
          return refuse("blob_digest_required", "blob.get returned no bytes")
        end

        text = begin
          raw.to_s.unpack1("m0")
        rescue ArgumentError
          raw.to_s
        end
        fabric = JSON.parse(text)
        { "ok" => true, "fabric" => fabric }
      rescue JSON::ParserError => e
        refuse("empty_use_case", "blob is not Fabric JSON: #{e.message}")
      end

      def load_miro
        return { "ok" => true } if defined?(::Vv::Miro::Share)

        begin
          require "vv-miro"
        rescue LoadError
          return refuse("miro_unavailable", "vv-miro is not on this FLOOR; share needs MAGENTIC_STACK_ROOT/gems/vv-miro and MIRO_ACCESS_TOKEN on BACK")
        end
        return { "ok" => true } if defined?(::Vv::Miro::Share)

        refuse("miro_unavailable", "vv-miro loaded without Share")
      end

      def digest_refusal(digest)
        if defined?(::Vv::Canvas::BlobGate)
          rec = Vv::Canvas::BlobGate.digest_refusal(digest)
          return stringify(rec) if rec
          return nil
        end
        return nil if digest.match?(DIGEST)

        refuse("blob_digest_required", "want sha256:<64 hex>")
      end

      def overlay(env, digest, params = {})
        env = stringify(env)
        p = stringify(params)
        cite = { "slice_key" => "S3" }
        uc = (p["uc_id"] || p["ucId"]).to_s
        cite["uc_id"] = uc unless uc.empty?
        if ok?(env)
          data = env["data"].is_a?(Hash) ? stringify(env["data"]) : {}
          {
            "ok" => true,
            "boardId" => data["board_id"] || data["boardId"],
            "viewLink" => data["view_link"] || data["viewLink"],
            "digest" => digest
          }.merge(cite)
        else
          {
            "ok" => false,
            "reason" => env["reason"].to_s,
            "because" => env["because"].to_s
          }.merge(cite)
        end
      end

      def ok?(env)
        env.is_a?(Hash) && (env["ok"] == true || env[:ok] == true)
      end

      def stringify(value)
        Model.stringify(value)
      end

      def refuse(reason, because)
        { "ok" => false, "reason" => reason.to_s, "because" => because.to_s }
      end
    end
  end
end
