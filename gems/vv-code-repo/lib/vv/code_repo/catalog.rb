# frozen_string_literal: true

module Vv
  module CodeRepo
    # Pure contract for a revision. No AR, no blob IO. The store is BACK.
    module Catalog
      LANGUAGES = %w[ruby python].freeze
      FRONT_LANGUAGES = %w[ruby].freeze
      TIERS = %w[bronze silver gold].freeze
      FIRST_SLUGS = %w[
        shape.render.ghis-19
        shape.render.ghis-20
        shape.render.ghis-21
        shape.emit.a2ui-0.9.1
      ].freeze
      TABLES = %w[
        procedures procedure_revisions procedure_bindings
        procedure_linkmls procedure_transitions procedure_rejections
      ].freeze
      EDGE_ATTRS = %w[condition guidance pitfalls].freeze

      module_function

      def stringify(params)
        params.is_a?(Hash) ? params.transform_keys(&:to_s) : {}
      end

      def land(params)
        p = stringify(params)
        minted = Refusal.graph_keys_present(p)
        unless minted.empty?
          return Refusal.build(Refusal::GRAPH_IRI_REFUSED,
                               "canvas-style: digest is the name; refused keys=#{minted.join(',')}")
        end
        if p["html_as_source"].to_s == "true" || p["htmlAsSource"].to_s == "true"
          return Refusal.build(Refusal::HTML_AS_SOURCE_REFUSED,
                               "HTML is a projection; a Gold binding must not treat it as source")
        end
        digest = (p["digest"] || p["revision_digest"]).to_s
        unless Refusal.digest?(digest)
          return Refusal.build(Refusal::BLOB_DIGEST_REQUIRED,
                               "want sha256:<64 hex>, got #{digest.inspect}")
        end
        tier = (p["tier"] || "bronze").to_s
        if tier == "platinum"
          return Refusal.build(Refusal::PLATINUM_NOT_A_TIER, Refusal::WHEN[Refusal::PLATINUM_NOT_A_TIER])
        end
        unless TIERS.include?(tier)
          return Refusal.build(Refusal::AUDIT_REJECTED, "unknown tier #{tier.inspect}")
        end
        if p["write_gold"] && !Grant.may_write_gold?(p)
          return Refusal.build(Refusal::PROD_WRITE_REFUSED, Refusal::WHEN[Refusal::PROD_WRITE_REFUSED])
        end

        Refusal.ok(
          slug: p["slug"].to_s,
          digest: digest,
          tier: tier,
          provenance: p["provenance"].to_s.empty? ? "observed" : p["provenance"].to_s
        )
      end

      def bind(params)
        p = stringify(params)
        lang = p["language"].to_s
        unless LANGUAGES.include?(lang)
          return Refusal.build(Refusal::UNKNOWN_LANGUAGE, "language #{lang.inspect} is not ruby|python")
        end
        digest = p["digest"].to_s
        unless Refusal.digest?(digest)
          return Refusal.build(Refusal::BLOB_DIGEST_REQUIRED, "binding digest missing")
        end
        role = p["role"].to_s
        if role == "front" && !FRONT_LANGUAGES.include?(lang)
          return Refusal.build(Refusal::BINDING_NOT_FOR_ROLE,
                               "FRONT role cannot consume language=#{lang}")
        end
        Refusal.ok(language: lang, digest: digest, entrypoint: p["entrypoint"].to_s)
      end

      def serve(params)
        p = stringify(params)
        tier = (p["tier"] || "gold").to_s
        unless tier == "gold"
          return Refusal.build(Refusal::GOLD_ONLY, "procedure.serve is Gold; got #{tier}")
        end
        digest = p["gold_digest"].to_s
        unless Refusal.digest?(digest)
          return Refusal.build(Refusal::BLOB_DIGEST_REQUIRED, "Gold pointer is not a digest")
        end
        Refusal.ok(slug: p["slug"].to_s, digest: digest, tier: "gold")
      end

      def promote(params)
        p = stringify(params)
        unless Grant.may_write_gold?(p)
          return Refusal.build(Refusal::PROD_WRITE_REFUSED, Refusal::WHEN[Refusal::PROD_WRITE_REFUSED])
        end
        if p["contract"].to_s.empty? && p["contract_digest"].to_s.empty?
          return Refusal.build(Refusal::CONTRACT_REQUIRED, Refusal::WHEN[Refusal::CONTRACT_REQUIRED])
        end
        unless p["recommend"] == true || p["recommend"].to_s == "true"
          return Refusal.build(Refusal::VALIDATION_FAILED,
                               "promote requires learn.recommend recommend:true")
        end
        silver = p["silver_digest"].to_s
        unless Refusal.digest?(silver)
          return Refusal.build(Refusal::BLOB_DIGEST_REQUIRED, "Silver digest required to promote")
        end
        if (p["linkml_in"].to_s.empty? || p["linkml_out"].to_s.empty?) &&
           (p["linkml_in_digest"].to_s.empty? || p["linkml_out_digest"].to_s.empty?)
          return Refusal.build(Refusal::LINKML_REQUIRED, Refusal::WHEN[Refusal::LINKML_REQUIRED])
        end
        Refusal.ok(slug: p["slug"].to_s, gold_digest: silver, from: "silver")
      end
    end
  end
end
