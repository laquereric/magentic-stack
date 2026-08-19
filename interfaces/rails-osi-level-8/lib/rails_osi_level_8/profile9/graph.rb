# frozen_string_literal: true

module RailsOsiLevel8
  module Profile9
    # In-memory Journey/Flow/Page + append-only token/ACIA/interaction store.
    # No tables, no migrations. One authorization-review fixture.
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

      def active_token_cid = active["tokenSetCid"]
      def active_acia_cid = active["aciaCid"]

      def interaction_for(receipt_cid, event_kind)
        interactions.values.find { |i| i["receiptCid"] == receipt_cid && i["eventKind"] == event_kind }
      end

      def put_token_set!(rec)
        rec = Request.stringify(rec)
        token_sets[rec["cid"]] ||= rec
      end

      def put_acia!(rec)
        rec = Request.stringify(rec)
        acia_docs[rec["cid"]] ||= rec
      end

      def put_receipt!(rec)
        rec = Request.stringify(rec)
        receipts[rec["cid"]] ||= rec
      end

      def put_interaction!(rec)
        rec = Request.stringify(rec)
        raise ArgumentError, "append-only: #{rec['cid']}" if interactions.key?(rec["cid"])

        interactions[rec["cid"]] = rec
      end

      def put_evidence!(rec)
        rec = Request.stringify(rec)
        evidences[rec["cid"]] = rec
      end

      def activate_token!(cid)
        raise ArgumentError, "unknown token set #{cid}" unless token_sets[cid.to_s]

        active["tokenSetCid"] = cid.to_s
        pages.each_value { |p| p["tokenSetCid"] = cid.to_s }
        cid.to_s
      end

      def activate_acia!(cid)
        raise ArgumentError, "unknown acia #{cid}" unless acia_docs[cid.to_s]

        active["aciaCid"] = cid.to_s
        pages.each_value { |p| p["aciaCid"] = cid.to_s }
        cid.to_s
      end

      def catalog
        @catalog ||= build_catalog
      end

      def build_catalog
        acia = Acia.eight_panel_fixture
        tokens = Renderer.default_token_set
        acia_digest = Acia.validate(acia).digest
        acia_cid = "cid:acia:#{acia_digest.delete_prefix('sha256:')}"
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
        {
          actors: {
            ACTOR_CID => {
              "cid" => ACTOR_CID,
              "@type" => "ux:Actor",
              "profileId" => Vocabulary::PROFILE_ID,
              "ledgerPlacement" => "canonical",
              "role" => "governance-steward",
              "label" => "Governance steward"
            }
          },
          journeys: {
            JOURNEY_CID => {
              "cid" => JOURNEY_CID,
              "@type" => "c4:Journey",
              "profileId" => Vocabulary::PROFILE_ID,
              "ledgerPlacement" => "canonical",
              "primaryActor" => ACTOR_CID,
              "goal" => "Review and authorize a proposed effect",
              "scenario" => "Steward inspects Profile-6 evidence and commits approve or deny",
              "channel" => CHANNEL_CID,
              "status" => "active",
              "phase" => [
                { "ordinal" => 1, "name" => "inspect", "goal" => "See authorization evidence" },
                { "ordinal" => 2, "name" => "decide", "goal" => "Commit approve or deny" }
              ],
              "hasFlow" => [FLOW_CID],
              "touchpoint" => [
                {
                  "cid" => "cid:touchpoint:authorization-review",
                  "@type" => "c4:Touchpoint",
                  "channel" => CHANNEL_CID,
                  "page" => PAGE_CID
                }
              ]
            }
          },
          flows: {
            FLOW_CID => {
              "cid" => FLOW_CID,
              "@type" => "ux:Flow",
              "profileId" => Vocabulary::PROFILE_ID,
              "ledgerPlacement" => "canonical",
              "journey" => JOURNEY_CID,
              "taskGoal" => "Authorize or refuse the proposed effect on one page",
              "status" => "active",
              "step" => [
                {
                  "ordinal" => 1,
                  "title" => "Authorization review",
                  "page" => PAGE_CID
                }
              ],
              "touchpoint" => [
                {
                  "cid" => "cid:touchpoint:authorization-review",
                  "@type" => "c4:Touchpoint",
                  "channel" => CHANNEL_CID,
                  "page" => PAGE_CID
                }
              ]
            }
          },
          pages: {
            PAGE_CID => {
              "cid" => PAGE_CID,
              "@type" => "view:Page",
              "profileId" => Vocabulary::PROFILE_ID,
              "ledgerPlacement" => "canonical",
              "flow" => FLOW_CID,
              "pagePurpose" => "authorization-review",
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
              "tokenSetCid" => TOKEN_SET_CID
            }
          },
          token_sets: { TOKEN_SET_CID => token_rec },
          acia_docs: { acia_cid => acia_rec },
          receipts: {},
          interactions: {},
          evidences: {},
          active: { "tokenSetCid" => TOKEN_SET_CID, "aciaCid" => acia_cid }
        }
      end
      private_class_method :build_catalog
    end
  end
end
