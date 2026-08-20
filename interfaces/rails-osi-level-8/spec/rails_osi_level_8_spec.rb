# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

RSpec.describe RailsOsiLevel8 do
  it "exposes VERSION" do
    expect(RailsOsiLevel8::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "aliases OsiLevel8" do
    expect(OsiLevel8).to equal(RailsOsiLevel8)
  end

  it "Ledger.crosses_boundary? denies private_local" do
    expect(RailsOsiLevel8::Ledger.crosses_boundary?(:canonical)).to be(true)
    expect(RailsOsiLevel8::Ledger.crosses_boundary?(:private_local)).to be(false)
  end

  it "LedgerPolicy places note.create request on sync_intent" do
    expect(
      RailsOsiLevel8::LedgerPolicy.placement_for!(operation: "note.create", evidence: :request)
    ).to eq("sync_intent")
  end

  describe "Grounding minimal closed-shape" do
    before do
      root = Pathname(File.expand_path("../data/osi-level-8", __dir__))
      RailsOsiLevel8.configure do |c|
        c.shape_root = root
        c.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(root)
      end
    end

    it "refuses note.create without idempotency key / title" do
      r = RailsOsiLevel8::Grounding.validate({}, profile: "P1::NoteCreateEffectShape")
      expect(r.conforms?).to be(false)
      expect(r.safe_report["violations"]).not_to be_empty
    end

    it "accepts a shaped note.create effect" do
      r = RailsOsiLevel8::Grounding.validate(
        { "title" => "hi", "operationId" => "op-1", "idempotencyKey" => "op-1" },
        profile: "P1::NoteCreateEffectShape"
      )
      expect(r.conforms?).to be(true)
    end
  end

  describe "Profile9 GHIS contract (M0)" do
    before do
      root = Pathname(File.expand_path("../data/osi-level-8", __dir__))
      RailsOsiLevel8.configure do |c|
        c.shape_root = root
        c.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(root)
      end
    end

    it "describes profile-9 methods and 18 component kinds" do
      d = RailsOsiLevel8::Profile9::Contract.describe
      expect(d["profile_id"]).to eq("osi-level-8/profile-9")
      expect(d["component_kinds"].size).to eq(18)
      expect(d["component_kinds"]).to include("ScopeTrail")
      expect(d["component_kinds"]).to eq(RailsOsiLevel8::Profile9::Vocabulary::COMPONENT_KINDS)
      names = d["operations"].map { |o| o["name"] }
      expect(names).to include("ux.profile.describe", "ux.contract.check", "ux.page.get")
      expect(d["shape_bundle"]["digest"]).to start_with("sha256:")
      expect(File).to exist(d["shape_bundle"]["absolute_path"])
    end

    it "P9.8 accepts ScopeTrail and refuses a nineteenth kind" do
      ok = RailsOsiLevel8::Profile9::Contract.check(
        "graph" => {
          "cid" => "cid:trail", "profileId" => "osi-level-8/profile-9",
          "componentKind" => "ScopeTrail",
          "effectiveScope" => "https://ex/scope/pod",
          "segment" => [{ "scope" => "https://ex/scope/root", "relation" => "contains" }]
        }
      )
      expect(ok["conforms"]).to be(true)

      expect {
        RailsOsiLevel8::Profile9::Contract.check(
          "graph" => { "cid" => "cid:x", "profileId" => "osi-level-8/profile-9", "componentKind" => "ScopeMap" }
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_UNKNOWN_COMPONENT_KIND")
        expect(e.because["unknown_component_kinds"]).to include("ScopeMap")
      }
    end

    it "accepts a closed graph and refuses unknown predicates" do
      ok = RailsOsiLevel8::Profile9::Contract.check(
        "graph" => { "cid" => "cid:abc", "profileId" => "osi-level-8/profile-9", "componentKind" => "PageShell" }
      )
      expect(ok["conforms"]).to be(true)

      expect {
        RailsOsiLevel8::Profile9::Contract.check(
          "graph" => { "cid" => "cid:abc", "style" => "color:red", "innerHTML" => "<b>x</b>" }
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_UNKNOWN_PREDICATE")
        expect(e.because["unknown_predicates"]).to include("style", "innerHTML")
      }
    end
  end

  describe "Profile9.5 shape catalog drift guard" do
    let(:root) { Pathname(File.expand_path("../data/osi-level-8", __dir__)) }
    let(:catalog) { RailsOsiLevel8::ProfileCatalog.default(root) }
    let(:ttl) { File.read(root.join("profile-9-ghis.ttl")) }
    let(:shape_names) do
      RailsOsiLevel8::Profile9::Vocabulary::OPERATIONS.flat_map { |op|
        [op[:request_shape], op[:response_shape]]
      }.uniq
    end

    it "every OPERATIONS request/response shape resolves in the catalog and is a NodeShape in TTL" do
      expect(shape_names.size).to eq(24)
      shape_names.each do |name|
        entry = catalog[name]
        expect(entry).not_to be_nil, "#{name} missing from ProfileCatalog"
        local = name.to_s.sub(/\AP9::/, "")
        expect(entry.shape_iri).to eq("#{RailsOsiLevel8::Profile9::Vocabulary::VOCAB_IRI}#{local}")
        expect(entry.path.basename.to_s).to eq("profile-9-ghis.ttl")
        expect(ttl).to match(/ux:#{Regexp.escape(local)}\s+a\s+sh:NodeShape/),
                       "#{name} (ux:#{local} / #{entry.shape_iri}) missing from profile-9-ghis.ttl"
      end
    end
  end

  it "Intent::Projection TYPE_MAP covers Mission/Persona/Journey" do
    expect(RailsOsiLevel8::Intent::Projection::TYPE_MAP.keys).to include("Mission", "Persona", "Journey")
    expect(RailsOsiLevel8::Intent::Projection::PROFILE_ID).to eq("osi-level-8/profile-10")
  end

  describe "Profile9.1 ACIA" do
    it "validates the eight-panel fixture and digests it" do
      doc = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
      r = RailsOsiLevel8::Profile9::Acia.validate(doc)
      expect(r.conforms?).to be(true)
      expect(r.digest).to match(/\Asha256:[0-9a-f]{64}\z/)
      expect(doc.dig("root", "children").size).to eq(8)
    end

    it "refuses raw HTML/style props" do
      doc = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
      doc["root"]["props"]["valueJson"]["style"] = "color:red"
      doc["root"]["props"]["valueJson"]["innerHTML"] = "<b>x</b>"
      r = RailsOsiLevel8::Profile9::Acia.validate(doc)
      expect(r.conforms?).to be(false)
      expect(r.because["forbidden_props"]).to include("style", "innerHTML")
    end
  end

  describe "Profile9.2 Renderer" do
    it "renders deterministic HTML with audit attrs and a receipt" do
      doc = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
      a = RailsOsiLevel8::Profile9::Renderer.render(
        "aciaDocument" => doc,
        "tokenSet" => RailsOsiLevel8::Profile9::Renderer.default_token_set,
        "correlationId" => "corr-1",
        "receiptSeed" => "seed-1"
      )
      b = RailsOsiLevel8::Profile9::Renderer.render(
        "aciaDocument" => doc,
        "tokenSet" => RailsOsiLevel8::Profile9::Renderer.default_token_set,
        "correlationId" => "corr-1",
        "receiptSeed" => "seed-1"
      )
      expect(a["ok"]).to be(true)
      expect(a["html"]).to include('data-ux-acia-digest=')
      expect(a["html"]).to include('data-ux-token-digest=')
      expect(a["html"]).to include('data-ux-node-cid=')
      expect(a["html"]).to eq(b["html"])
      expect(a["receipt"]["cid"]).to eq(b["receipt"]["cid"])
      expect(a["receipt"]["receiptKind"]).to eq("ux:RenderReceipt")
    end

    it "emits RefusalNotice (not HTML fallback) on unresolved token" do
      doc = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
      doc["root"]["slt"]["tokenSignature"] = { "setRef" => "tokens:missing@9" }
      r = RailsOsiLevel8::Profile9::Renderer.render(
        "aciaDocument" => doc,
        "tokenSet" => RailsOsiLevel8::Profile9::Renderer.default_token_set
      )
      expect(r["ok"]).to be(false)
      expect(r["html"]).to include("RefusalNotice")
      expect(r["html"]).to include("UX_TOKEN_REF_BROKEN")
      expect(r["html"]).not_to include("data-ux-label") # no successful tree fallback
      expect(r["receipt"]["ok"]).to be(false)
    end
  end

  describe "Profile9.3 Journey/Flow/Page PULLs" do
    before { RailsOsiLevel8::Profile9::Graph.reset! }

    it "marks journey/flow/page read ops available" do
      ops = RailsOsiLevel8::Profile9::Contract.describe["operations"].to_h { |o| [o["name"], o["status"]] }
      %w[ux.journey.list ux.journey.get ux.flow.get ux.page.get].each do |name|
        expect(ops[name]).to eq("available")
      end
    end

    it "lists actor-authorized journeys and gets flow/page lineage" do
      list = RailsOsiLevel8::Profile9::Pulls.journey_list("actorCid" => RailsOsiLevel8::Profile9::Graph::ACTOR_CID)
      expect(list.size).to eq(1)
      expect(list.first["cid"]).to eq(RailsOsiLevel8::Profile9::Graph::JOURNEY_CID)
      expect(list.first["hasFlow"]).to eq([RailsOsiLevel8::Profile9::Graph::FLOW_CID])

      journey = RailsOsiLevel8::Profile9::Pulls.journey_get("journeyCid" => RailsOsiLevel8::Profile9::Graph::JOURNEY_CID)
      expect(journey["phase"].map { |p| p["name"] }).to eq(%w[inspect decide])
      expect(journey["touchpoint"]).not_to be_empty

      flow = RailsOsiLevel8::Profile9::Pulls.flow_get("flowCid" => RailsOsiLevel8::Profile9::Graph::FLOW_CID)
      expect(flow["step"].first["page"]).to eq(RailsOsiLevel8::Profile9::Graph::PAGE_CID)
    end

    it "pipes ux.page.get into the P9.2 renderer for a stable receipt cid" do
      bundle = RailsOsiLevel8::Profile9::Pulls.page_get(
        "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
        "correlationId" => "corr-p93",
        "receiptSeed" => "seed-p93"
      )
      expect(bundle["@type"]).to eq("ux:PageRenderBundle")
      expect(bundle["aciaDocument"]).to be_a(Hash)
      expect(bundle["tokenSet"]).to be_a(Hash)

      a = RailsOsiLevel8::Profile9::Renderer.render(bundle)
      b = RailsOsiLevel8::Profile9::Renderer.render(bundle)
      expect(a["ok"]).to be(true)
      expect(a["receipt"]["receiptKind"]).to eq("ux:RenderReceipt")
      expect(a["receipt"]["cid"]).to match(/\Acid:sha256:[0-9a-f]{64}\z/)
      expect(a["receipt"]["cid"]).to eq(b["receipt"]["cid"])
      expect(a["html"]).to include("data-ux-acia-digest=")
    end

    it "refuses unknown refs and unknown request keys" do
      expect {
        RailsOsiLevel8::Profile9::Pulls.journey_get("journeyCid" => "cid:journey:missing")
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_LINEAGE_UNRESOLVED")
        expect(e.because["resource"]).to eq("journey")
      }

      expect {
        RailsOsiLevel8::Profile9::Pulls.page_get("pageCid" => "cid:page:nope")
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_LINEAGE_UNRESOLVED")
        expect(e.because["resource"]).to eq("page")
      }

      expect {
        RailsOsiLevel8::Profile9::Pulls.journey_list(
          "actorCid" => RailsOsiLevel8::Profile9::Graph::ACTOR_CID,
          "style" => "color:red"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_UNKNOWN_PREDICATE")
        expect(e.because["unknown_predicates"]).to include("style")
      }
    end
  end

  describe "Profile9.4 token/ACIA mutations + interaction" do
    before { RailsOsiLevel8::Profile9::Graph.reset! }

    def g = RailsOsiLevel8::Profile9::Graph
    def pulls = RailsOsiLevel8::Profile9::Pulls
    def mut = RailsOsiLevel8::Profile9::Mutations

    it "marks token.get and the three push ops available" do
      ops = RailsOsiLevel8::Profile9::Contract.describe["operations"].to_h { |o| [o["name"], o["status"]] }
      %w[ux.token.get ux.token.set ux.acia.mutate.propose ux.interaction.record].each do |name|
        expect(ops[name]).to eq("available")
      end
    end

    it "returns the accepted token set and refuses unknown cid/keys" do
      rec = pulls.token_get({})
      expect(rec["cid"]).to eq(g::TOKEN_SET_CID)
      expect(rec["digest"]).to match(/\Asha256:[0-9a-f]{64}\z/)
      expect(rec.dig("tokens", "tokens:ghis@1", "colors.fg")).to eq("#111")

      expect {
        pulls.token_get("tokenSetCid" => "cid:tokens:missing")
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_LINEAGE_UNRESOLVED")
      }

      expect {
        pulls.token_get("style" => "color:red")
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_UNKNOWN_PREDICATE")
      }
    end

    it "refuses a contrast-failing token successor and does not activate it" do
      pred = pulls.token_get({})
      expect {
        mut.token_set(
          "predecessorCid" => pred["cid"],
          "predecessorDigest" => pred["digest"],
          "tokenDelta" => { "tokens:ghis@1" => { "colors.fg" => "#eee" } }
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_DESIGN_GROUNDING_FAILED")
        expect(e.because["activated"]).to be(false)
      }
      expect(pulls.token_get({})["cid"]).to eq(pred["cid"])
      expect(g.evidences.values.any? { |ev| ev["passed"] == false }).to be(true)
    end

    it "refuses a broken token ref and activates a clean successor" do
      pred = pulls.token_get({})
      expect {
        mut.token_set(
          "predecessorCid" => pred["cid"],
          "predecessorDigest" => pred["digest"],
          "tokenDelta" => { "tokens:ghis@1" => { "colors.fg" => "{colors.missing}" } }
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_TOKEN_REF_BROKEN")
      }

      ok = mut.token_set(
        "predecessorCid" => pred["cid"],
        "predecessorDigest" => pred["digest"],
        "tokenDelta" => { "tokens:ghis@1" => { "colors.fg" => "#000000" } }
      )
      expect(ok["accepted"]).to be(true)
      expect(ok["digest"]).not_to eq(pred["digest"])
      expect(pulls.token_get({})["cid"]).to eq(ok["cid"])
      expect(pulls.token_get({})["digest"]).to eq(ok["digest"])
    end

    it "refuses an HTML ACIA successor and activates a closed one" do
      page = pulls.page_get("pageCid" => g::PAGE_CID, "correlationId" => "c", "receiptSeed" => "s")
      pred_cid = g.active_acia_cid
      pred = g.acia_doc(pred_cid)

      bad = Marshal.load(Marshal.dump(page["aciaDocument"]))
      bad["root"]["props"]["valueJson"]["html"] = "<div/>"
      expect {
        mut.acia_mutate_propose(
          "predecessorCid" => pred_cid,
          "predecessorDigest" => pred["digest"],
          "successor" => bad
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.because["activated"]).to be(false)
      }
      expect(g.active_acia_cid).to eq(pred_cid)

      good = Marshal.load(Marshal.dump(page["aciaDocument"]))
      good["root"]["props"]["valueJson"]["title"] = "Governance (revised)"
      ok = mut.acia_mutate_propose(
        "predecessorCid" => pred_cid,
        "predecessorDigest" => pred["digest"],
        "successor" => good
      )
      expect(ok["accepted"]).to be(true)
      expect(g.active_acia_cid).to eq(ok["cid"])
      expect(ok["digest"]).not_to eq(pred["digest"])
    end

    it "records context_presented, refuses replay, and commits a closed effect" do
      bundle = pulls.page_get(
        "pageCid" => g::PAGE_CID,
        "correlationId" => "corr-p94",
        "receiptSeed" => "seed-p94"
      )
      rendered = RailsOsiLevel8::Profile9::Renderer.render(bundle)
      expect(rendered["ok"]).to be(true)
      receipt = rendered["receipt"]

      presented = mut.interaction_record(
        "eventKind" => "context_presented",
        "receipt" => receipt,
        "receiptCid" => receipt["cid"],
        "aciaDocumentDigest" => receipt["aciaDigest"],
        "tokenSetDigest" => receipt["tokenDigest"],
        "pageCid" => g::PAGE_CID
      )
      expect(presented["eventKind"]).to eq("context_presented")
      expect(presented["journeyCid"]).to eq(g::JOURNEY_CID)

      expect {
        mut.interaction_record(
          "eventKind" => "context_presented",
          "receipt" => receipt,
          "receiptCid" => receipt["cid"],
          "aciaDocumentDigest" => receipt["aciaDigest"],
          "tokenSetDigest" => receipt["tokenDigest"],
          "pageCid" => g::PAGE_CID
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.because["replay"]).to be(true)
      }

      expect {
        mut.interaction_record(
          "eventKind" => "effect_committed",
          "receipt" => receipt,
          "receiptCid" => receipt["cid"],
          "aciaDocumentDigest" => receipt["aciaDigest"],
          "tokenSetDigest" => receipt["tokenDigest"],
          "pageCid" => g::PAGE_CID
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_EFFECT_AFFORDANCE_DENIED")
      }

      committed = mut.interaction_record(
        "eventKind" => "effect_committed",
        "receipt" => receipt,
        "receiptCid" => receipt["cid"],
        "aciaDocumentDigest" => receipt["aciaDigest"],
        "tokenSetDigest" => receipt["tokenDigest"],
        "pageCid" => g::PAGE_CID,
        "collectedEffect" => {
          "decision" => "permit",
          "effectContract" => g::EFFECT_CONTRACT_CID
        }
      )
      expect(committed["machineEffectCid"]).to match(/\Acid:effect:/)
      expect(committed["pageCid"]).to eq(g::PAGE_CID)
      expect(committed["receiptCid"]).to eq(receipt["cid"])
    end
  end

  describe "Profile9.6 durable store" do
    it "keeps the in-memory fixture seedable without ActiveRecord" do
      RailsOsiLevel8::Profile9::Graph.reset!
      expect(defined?(::ActiveRecord::Base) && defined?(::RailsOsiLevel8::UxJourney) &&
             RailsOsiLevel8::UxJourney.respond_to?(:table_exists?) &&
             RailsOsiLevel8::UxJourney.table_exists?).to be_falsey
      expect(RailsOsiLevel8::Profile9::Graph.journey(RailsOsiLevel8::Profile9::Graph::JOURNEY_CID)).to be_a(Hash)
    end
  end
end




