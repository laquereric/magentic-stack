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

    it "describes profile-9 methods and 17 component kinds" do
      d = RailsOsiLevel8::Profile9::Contract.describe
      expect(d["profile_id"]).to eq("osi-level-8/profile-9")
      expect(d["component_kinds"].size).to eq(17)
      names = d["operations"].map { |o| o["name"] }
      expect(names).to include("ux.profile.describe", "ux.contract.check", "ux.page.get")
      expect(d["shape_bundle"]["digest"]).to start_with("sha256:")
      expect(File).to exist(d["shape_bundle"]["absolute_path"])
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
end




