# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # P9.3/P9.4 PULL handlers over the in-memory fixture graph.
    # Closed request keys; unknown refs refuse (never empty-success).
    module Pulls
      LIST_KEYS = %w[actorCid status channel].freeze
      JOURNEY_GET_KEYS = %w[journeyCid].freeze
      FLOW_GET_KEYS = %w[flowCid].freeze
      PAGE_GET_KEYS = %w[pageCid actorCid actorCapability correlationId receiptSeed].freeze
      TOKEN_GET_KEYS = %w[tokenSetCid active].freeze

      module_function

      def journey_list(params)
        params = Request.closed!(params, LIST_KEYS)
        actor_cid = Request.require_cid!(params, "actorCid")
        Request.unresolved!("actor", actor_cid) unless Graph.actor(actor_cid)

        items = Graph.journeys.values.select { |j| j["primaryActor"] == actor_cid }
        items = items.select { |j| j["status"] == params["status"] } if Request.present?(params["status"])
        items = items.select { |j| j["channel"] == params["channel"] } if Request.present?(params["channel"])
        items.map { |j| journey_summary(j) }
      end

      def journey_get(params)
        params = Request.closed!(params, JOURNEY_GET_KEYS)
        cid = Request.require_cid!(params, "journeyCid")
        j = Graph.journey(cid)
        Request.unresolved!("journey", cid) unless j
        journey_detail(j)
      end

      def flow_get(params)
        params = Request.closed!(params, FLOW_GET_KEYS)
        cid = Request.require_cid!(params, "flowCid")
        f = Graph.flow(cid)
        Request.unresolved!("flow", cid) unless f
        flow_detail(f)
      end

      def page_get(params)
        params = Request.closed!(params, PAGE_GET_KEYS)
        cid = Request.require_cid!(params, "pageCid")
        page = Graph.page(cid)
        Request.unresolved!("page", cid) unless page

        if Request.present?(params["actorCid"]) && !Graph.actor(params["actorCid"])
          Request.unresolved!("actor", params["actorCid"])
        end

        acia_rec = Graph.acia_doc(page["aciaCid"])
        token_rec = Graph.token_set(page["tokenSetCid"])
        Request.unresolved!("acia", page["aciaCid"]) unless acia_rec
        Request.unresolved!("tokenSet", page["tokenSetCid"]) unless token_rec

        acia = acia_rec["document"]
        tokens = { "cid" => token_rec["cid"], "tokens" => token_rec["tokens"] }
        validation = Acia.validate(acia)
        unless validation.conforms?
          raise KnownRefusal.new(validation.reason, (validation.because || {}).merge("gate" => "acia"))
        end

        correlation = params["correlationId"].to_s
        correlation = "corr:#{cid}" if correlation.empty?
        receipt_seed = params["receiptSeed"].to_s
        receipt_seed = Request.digest("#{cid}:#{correlation}").delete_prefix("sha256:")[0, 16] if receipt_seed.empty?

        {
          "cid" => "cid:bundle:#{cid}",
          "@type" => "ux:PageRenderBundle",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "page" => page_record(page),
          "aciaDocument" => acia,
          "tokenSet" => tokens,
          "shownContext" => shown_snapshot(cid, validation.digest, tokens, receipt_seed),
          "capability" => {
            "actorCid" => Request.present?(params["actorCid"]) ? params["actorCid"] : Graph::ACTOR_CID,
            "canCommitEffect" => true
          },
          "effectContracts" => Array(page["effectContracts"]),
          "correlationId" => correlation,
          "receiptSeed" => receipt_seed
        }
      end

      def token_get(params)
        params = Request.closed!(params, TOKEN_GET_KEYS)
        cid = params["tokenSetCid"].to_s
        cid = Graph.active_token_cid if cid.empty? || params["active"] == true || params["active"] == "true"
        rec = Graph.token_set(cid)
        Request.unresolved!("tokenSet", cid) unless rec
        rec.slice("cid", "@type", "profileId", "ledgerPlacement", "tokens", "digest",
                  "predecessorCid", "designMdProjection")
      end

      def journey_summary(j)
        j.slice("cid", "@type", "profileId", "ledgerPlacement", "primaryActor",
                "goal", "scenario", "channel", "status", "hasFlow")
      end
      private_class_method :journey_summary

      def journey_detail(j)
        j.slice("cid", "@type", "profileId", "ledgerPlacement", "primaryActor",
                "goal", "scenario", "channel", "status", "phase", "hasFlow", "touchpoint")
      end
      private_class_method :journey_detail

      def flow_detail(f)
        f.slice("cid", "@type", "profileId", "ledgerPlacement", "journey",
                "taskGoal", "status", "step", "touchpoint")
      end
      private_class_method :flow_detail

      def page_record(page)
        page.slice("cid", "@type", "profileId", "ledgerPlacement", "flow",
                   "pagePurpose", "contextSelector", "effectContract")
      end
      private_class_method :page_record

      def shown_snapshot(page_cid, acia_digest, tokens, receipt_seed)
        {
          "cid" => "cid:snapshot:#{page_cid}:#{receipt_seed}",
          "@type" => "ux:ShownContextSnapshot",
          "pageCid" => page_cid,
          "aciaDocumentDigest" => acia_digest,
          "tokenSetDigest" => token_digest(tokens),
          "sourceContextCids" => [Graph::CONTEXT_CID],
          "disclosurePolicyCid" => Graph::SNAPSHOT_POLICY_CID,
          "receiptNonce" => receipt_seed,
          "ledgerPlacement" => "canonical"
        }
      end
      private_class_method :shown_snapshot

      def token_digest(tokens)
        Request.digest(tokens)
      end
      private_class_method :token_digest
    end
  end
end
