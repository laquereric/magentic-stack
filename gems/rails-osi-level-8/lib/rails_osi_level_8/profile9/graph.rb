# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # Journey/Flow/Page + append-only token/ACIA/interaction store.
    # Memory always (gem specs); AR-backed when osi_l8_ux_* tables exist (P9.6).
    module Graph
      ACTOR_CID = "cid:actor:governance-steward"
      JOURNEY_CID = "cid:journey:authorization-review"
      FLOW_CID = "cid:flow:authorization-review"
      PAGE_CID = "cid:page:authorization-review"
      CHANNEL_CID = "cid:channel:cpcp"
      CONTEXT_CID = "cid:context:p6-authorization-demo"
      SNAPSHOT_POLICY_CID = "cid:policy:canonical-only"
      EFFECT_CONTRACT_CID = "cid:effect-contract:approve-deny"
      TOKEN_SET_CID = "cid:tokens:ghis@1"

      module_function

      def reset!
        @catalog = nil
        @seq = 0
      end

      def next_seq
        @seq = (@seq || 0) + 1
      end

      def actors = catalog[:actors]
      def journeys = catalog[:journeys]
      def flows = catalog[:flows]
      def pages = catalog[:pages]
      def token_sets = catalog[:token_sets]
      def acia_docs = catalog[:acia_docs]
      def receipts = catalog[:receipts]
      def interactions = catalog[:interactions]
      def evidences = catalog[:evidences]
      def active = catalog[:active]

      def actor(cid) = actors[cid.to_s]
      def journey(cid) = journeys[cid.to_s]
      def flow(cid) = flows[cid.to_s]
      def page(cid) = pages[cid.to_s]
      def token_set(cid) = token_sets[cid.to_s]
      def acia_doc(cid) = acia_docs[cid.to_s]
      def receipt(cid) = receipts[cid.to_s]

      def j1_ids
        catalog[:j1] || {
          "actorCid" => ACTOR_CID,
          "journeyCid" => JOURNEY_CID,
          "flowCid" => FLOW_CID,
          "pageCid" => PAGE_CID,
          "stepKey" => J1::STEP_KEY,
          "groundingCid" => nil
        }
      end

      def j1_actor_cid = j1_ids["actorCid"]
      def j1_journey_cid = j1_ids["journeyCid"]
      def j1_flow_cid = j1_ids["flowCid"]
      def j1_page_cid = j1_ids["pageCid"]
      def j1_step_key = j1_ids["stepKey"] || J1::STEP_KEY
      def j1_grounding_cid = j1_ids["groundingCid"]

      def vv_base_ready? = J1.ready?

      def active_token_cid = active["tokenSetCid"]
      def active_acia_cid = active["aciaCid"]

      def interaction_for(receipt_cid, event_kind)
        interactions.values.find { |i| i["receiptCid"] == receipt_cid && i["eventKind"] == event_kind }
      end

      def put_token_set!(rec)
        rec = Request.stringify(rec)
        token_sets[rec["cid"]] ||= rec
        persist_record!(:UxTokenSet, rec, "predecessor_cid" => rec["predecessorCid"], "digest" => rec["digest"])
        rec
      end

      def put_acia!(rec)
        rec = Request.stringify(rec)
        acia_docs[rec["cid"]] ||= rec
        persist_record!(:UxAciaDocument, rec, "predecessor_cid" => rec["predecessorCid"], "digest" => rec["digest"])
        rec
      end

      def put_receipt!(rec)
        rec = Request.stringify(rec)
        receipts[rec["cid"]] ||= rec
        persist_record!(:UxReceipt, rec)
        rec
      end

      def put_interaction!(rec)
        rec = Request.stringify(rec)
        raise ArgumentError, "append-only: #{rec['cid']}" if interactions.key?(rec["cid"])

        interactions[rec["cid"]] = rec
        persist_record!(:UxInteractionEvent, rec,
                        "receipt_cid" => rec["receiptCid"],
                        "event_kind" => rec["eventKind"],
                        "machine_effect_cid" => rec["machineEffectCid"])
        rec
      end

      def put_evidence!(rec)
        rec = Request.stringify(rec)
        evidences[rec["cid"]] = rec
        persist_record!(:UxEvidence, rec,
                        "operation_name" => rec["operation"],
                        "gate" => rec["gate"],
                        "passed" => rec["passed"])
        rec
      end

      def put_page!(rec)
        rec = Request.stringify(rec)
        pages[rec["cid"]] = rec
        persist_record!(:UxPage, rec)
        rec
      end

      def bind_page_acia!(page_cid, acia_cid)
        page = pages[page_cid.to_s]
        raise ArgumentError, "unknown page #{page_cid}" unless page
        raise ArgumentError, "unknown acia #{acia_cid}" unless acia_docs[acia_cid.to_s]

        page["aciaCid"] = acia_cid.to_s
        persist_record!(:UxPage, page)
        page
      end

      def activate_token!(cid)
        raise ArgumentError, "unknown token set #{cid}" unless token_sets[cid.to_s]

        active["tokenSetCid"] = cid.to_s
        pages.each_value { |p| p["tokenSetCid"] = cid.to_s }
        persist_activation!("token", cid)
        cid.to_s
      end

      def activate_acia!(cid, page_cid: nil)
        raise ArgumentError, "unknown acia #{cid}" unless acia_docs[cid.to_s]

        active["aciaCid"] = cid.to_s
        bind_page_acia!(page_cid, cid) if page_cid
        persist_activation!("acia", cid)
        cid.to_s
      end

      def catalog
        @catalog ||= load_from_ar || persist_seed!(build_catalog)
      end

      def ar_enabled?
        return false unless defined?(::ActiveRecord::Base)
        return false unless defined?(::RailsOsiLevel8::UxJourney)

        ::RailsOsiLevel8::UxJourney.table_exists?
      rescue StandardError
        false
      end
      private_class_method :ar_enabled?

      def persist_seed!(cat)
        return cat unless ar_enabled?

        cat[:actors].each_value { |r| persist_record!(:UxActor, r) }
        cat[:journeys].each_value { |r| persist_record!(:UxJourney, r) }
        cat[:flows].each_value { |r| persist_record!(:UxFlow, r) }
        cat[:pages].each_value { |r| persist_record!(:UxPage, r) }
        cat[:token_sets].each_value { |r|
          persist_record!(:UxTokenSet, r, "predecessor_cid" => r["predecessorCid"], "digest" => r["digest"])
        }
        cat[:acia_docs].each_value { |r|
          persist_record!(:UxAciaDocument, r, "predecessor_cid" => r["predecessorCid"], "digest" => r["digest"])
        }
        persist_activation!("token", cat[:active]["tokenSetCid"])
        persist_activation!("acia", cat[:active]["aciaCid"])
        cat
      end
      private_class_method :persist_seed!

      def persist_record!(const_name, rec, extra = {})
        return unless ar_enabled?

        klass = ::RailsOsiLevel8.const_get(const_name)
        cid = rec["cid"].to_s
        return if cid.empty? || klass.exists?(cid: cid)

        attrs = {
          cid: cid,
          profile_id: rec["profileId"] || Vocabulary::PROFILE_ID,
          ledger_placement: rec["ledgerPlacement"] || "canonical",
          provenance_json: {},
          payload_digest: Request.digest(rec),
          recorded_at: Time.now.utc,
          envelope_json: rec
        }
        extra.each { |k, v| attrs[k.to_sym] = v unless v.nil? }
        klass.create!(attrs)
      end
      private_class_method :persist_record!

      def persist_activation!(kind, target_cid)
        return unless ar_enabled?

        rec = {
          "cid" => "cid:activation:#{kind}:#{next_seq}:#{target_cid}",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "headKind" => kind,
          "targetCid" => target_cid.to_s
        }
        persist_record!(:UxActivation, rec, "head_kind" => kind, "target_cid" => target_cid.to_s)
      end
      private_class_method :persist_activation!

      def load_from_ar
        return nil unless ar_enabled?
        return nil unless ::RailsOsiLevel8::UxJourney.exists?

        cat = {
          actors: envelopes(::RailsOsiLevel8::UxActor),
          journeys: envelopes(::RailsOsiLevel8::UxJourney),
          flows: envelopes(::RailsOsiLevel8::UxFlow),
          pages: envelopes(::RailsOsiLevel8::UxPage),
          token_sets: envelopes(::RailsOsiLevel8::UxTokenSet),
          acia_docs: envelopes(::RailsOsiLevel8::UxAciaDocument),
          receipts: envelopes(::RailsOsiLevel8::UxReceipt),
          interactions: envelopes(::RailsOsiLevel8::UxInteractionEvent),
          evidences: envelopes(::RailsOsiLevel8::UxEvidence),
          active: { "tokenSetCid" => TOKEN_SET_CID, "aciaCid" => nil }
        }
        tok = latest_activation("token")
        acia = latest_activation("acia")
        cat[:active]["tokenSetCid"] = tok if tok
        cat[:active]["aciaCid"] = acia if acia
        cat[:active]["aciaCid"] ||= cat[:acia_docs].keys.first
        attach_j1!(cat)
        cat
      end
      private_class_method :load_from_ar

      def attach_j1!(cat)
        page = cat[:pages].values.find { |p| p["pagePurpose"] == J1::ROUTE_KEY } ||
               cat[:pages].values.first
        flow = page && cat[:flows][page["flowCid"] || page["flow"]]
        flow ||= cat[:flows].values.first
        journey = flow && cat[:journeys][flow["journey"]]
        journey ||= cat[:journeys].values.first
        actor = journey && cat[:actors][journey["primaryActor"]]
        actor ||= cat[:actors].values.first
        cat[:j1] = {
          "actorCid" => actor && actor["cid"],
          "journeyCid" => journey && journey["cid"],
          "flowCid" => flow && flow["cid"],
          "pageCid" => page && page["cid"],
          "stepKey" => (page && page["stepKey"]) || J1::STEP_KEY,
          "groundingCid" => journey && journey["intentGroundingCid"],
          "informationModelCid" => page && page["informationModelCid"]
        }
        cat
      end
      private_class_method :attach_j1!

      def envelopes(klass)
        klass.find_each.each_with_object({}) do |row, h|
          rec = stringify_envelope(row.envelope_json)
          cid = rec["cid"] || row.cid
          h[cid] = rec.merge("cid" => cid)
        end
      end
      private_class_method :envelopes

      def stringify_envelope(obj)
        case obj
        when Hash then obj.each_with_object({}) { |(k, v), h| h[k.to_s] = stringify_envelope(v) }
        when Array then obj.map { |v| stringify_envelope(v) }
        else obj
        end
      end
      private_class_method :stringify_envelope

      def latest_activation(kind)
        return nil unless ar_enabled?

        row = ::RailsOsiLevel8::UxActivation.where(head_kind: kind).order(:recorded_at, :id).last
        row&.target_cid
      end
      private_class_method :latest_activation

      def build_catalog
        fields = Compile::J1_FIELDS
        seeded_early = nil
        if J1.ready?
          seeded_early = J1.seed!
          fields = Compile.fields_from(seeded_early[:model]) if seeded_early && seeded_early[:model]
        end
        compiled = Compile.j1_document(fields: fields)
        unless compiled["ok"]
          raise KnownRefusal.new(compiled["reason"], compiled["because"] || {})
        end
        acia = compiled["document"]
        tokens = Renderer.default_token_set
        acia_digest = compiled["digest"]
        acia_cid = compiled["aciaCid"]
        token_digest = Request.digest(tokens["tokens"])
        token_rec = {
          "cid" => TOKEN_SET_CID,
          "@type" => "ux:DesignTokenSet",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "tokens" => tokens["tokens"],
          "digest" => token_digest,
          "predecessorCid" => nil,
          "designMdProjection" => { "tokenSchemaVersion" => "ghis@1", "source" => "fixture" }
        }
        acia_rec = {
          "cid" => acia_cid,
          "@type" => "ux:AciaDocument",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "document" => acia,
          "digest" => acia_digest,
          "predecessorCid" => nil,
          "tokenSetCid" => TOKEN_SET_CID
        }
        seeded = defined?(seeded_early) ? seeded_early : nil
        ids = seeded_ids(seeded, acia_cid)
        cat = {
          actors: {
            ids["actorCid"] => actor_envelope(ids)
          },
          journeys: {
            ids["journeyCid"] => journey_envelope(ids)
          },
          flows: {
            ids["flowCid"] => flow_envelope(ids)
          },
          pages: {
            ids["pageCid"] => page_envelope(ids, acia_cid)
          },
          token_sets: { TOKEN_SET_CID => token_rec },
          acia_docs: { acia_cid => acia_rec },
          receipts: {},
          interactions: {},
          evidences: {},
          active: { "tokenSetCid" => TOKEN_SET_CID, "aciaCid" => acia_cid },
          j1: ids
        }
        cat
      end
      private_class_method :build_catalog

      def seeded_ids(seeded, acia_cid)
        if seeded
          {
            "actorCid" => seeded[:actor_cid],
            "journeyCid" => seeded[:journey_cid],
            "flowCid" => seeded[:flow_cid],
            "pageCid" => PAGE_CID,
            "stepKey" => J1::STEP_KEY,
            "groundingCid" => seeded[:grounding_cid],
            "informationModelCid" => "cid:im:#{J1::MODEL_KEY}",
            "sourceActorId" => seeded[:actor].id,
            "sourceJourneyId" => seeded[:journey].id,
            "sourceFlowId" => seeded[:flow].id,
            "intentGroundingStatus" => "bound"
          }
        else
          {
            "actorCid" => ACTOR_CID,
            "journeyCid" => JOURNEY_CID,
            "flowCid" => FLOW_CID,
            "pageCid" => PAGE_CID,
            "stepKey" => J1::STEP_KEY,
            "groundingCid" => nil,
            "informationModelCid" => nil,
            "intentGroundingStatus" => "absent"
          }
        end.merge("aciaCid" => acia_cid)
      end
      private_class_method :seeded_ids

      def actor_envelope(ids)
        rec = {
          "cid" => ids["actorCid"],
          "@type" => "ux:Actor",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "role" => J1::ROLE_KEY,
          "label" => "Governance steward"
        }
        if ids["sourceActorId"]
          rec["sourceClass"] = "Actor"
          rec["sourceId"] = ids["sourceActorId"]
        end
        rec
      end
      private_class_method :actor_envelope

      def journey_envelope(ids)
        rec = {
          "cid" => ids["journeyCid"],
          "@type" => "c4:Journey",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "primaryActor" => ids["actorCid"],
          "goal" => "Review and authorize a proposed effect",
          "scenario" => "Steward inspects Profile-6 evidence and commits approve or deny",
          "channel" => CHANNEL_CID,
          "status" => "active",
          "phase" => [
            { "ordinal" => 1, "name" => "inspect", "goal" => "See authorization evidence" },
            { "ordinal" => 2, "name" => "decide", "goal" => "Commit approve or deny" }
          ],
          "hasFlow" => [ids["flowCid"]],
          "touchpoint" => [
            {
              "cid" => "cid:touchpoint:authorization-review",
              "@type" => "c4:Touchpoint",
              "channel" => CHANNEL_CID,
              "page" => ids["pageCid"]
            }
          ],
          "intentGroundingStatus" => ids["intentGroundingStatus"]
        }
        rec["intentGroundingCid"] = ids["groundingCid"] if ids["groundingCid"]
        if ids["sourceJourneyId"]
          rec["sourceClass"] = "Journey"
          rec["sourceId"] = ids["sourceJourneyId"]
        end
        rec
      end
      private_class_method :journey_envelope

      def flow_envelope(ids)
        rec = {
          "cid" => ids["flowCid"],
          "@type" => "ux:Flow",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "journey" => ids["journeyCid"],
          "taskGoal" => "Authorize or refuse the proposed effect on one page",
          "status" => "active",
          "step" => [
            {
              "ordinal" => 1,
              "stepKey" => ids["stepKey"],
              "kind" => "decide",
              "title" => "Authorization review",
              "page" => ids["pageCid"]
            }
          ],
          "touchpoint" => [
            {
              "cid" => "cid:touchpoint:authorization-review",
              "@type" => "c4:Touchpoint",
              "channel" => CHANNEL_CID,
              "page" => ids["pageCid"]
            }
          ]
        }
        if ids["sourceFlowId"]
          rec["sourceClass"] = "Flow"
          rec["sourceId"] = ids["sourceFlowId"]
        end
        rec
      end
      private_class_method :flow_envelope

      def page_envelope(ids, acia_cid)
        rec = {
          "cid" => ids["pageCid"],
          "@type" => "view:Page",
          "profileId" => Vocabulary::PROFILE_ID,
          "ledgerPlacement" => "canonical",
          "flow" => ids["flowCid"],
          "flowCid" => ids["flowCid"],
          "stepKey" => ids["stepKey"],
          "pagePurpose" => J1::ROUTE_KEY,
          "contextSelector" => "p6:authorization-evidence",
          "effectContract" => [EFFECT_CONTRACT_CID],
          "effectContracts" => [
            {
              "cid" => EFFECT_CONTRACT_CID,
              "behaviorKind" => "confirm",
              "componentKind" => "DecisionForm",
              "targetShape" => "P6::AuthorizationDecisionEffectShape"
            }
          ],
          "aciaCid" => acia_cid,
          "tokenSetCid" => TOKEN_SET_CID,
          "intentGroundingStatus" => ids["intentGroundingStatus"]
        }
        rec["intentGroundingCid"] = ids["groundingCid"] if ids["groundingCid"]
        rec["informationModelCid"] = ids["informationModelCid"] if ids["informationModelCid"]
        rec
      end
      private_class_method :page_envelope
    end
  end
end
