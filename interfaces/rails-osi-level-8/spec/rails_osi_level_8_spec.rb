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

    it "describes profile-9 methods and 19 component kinds" do
      d = RailsOsiLevel8::Profile9::Contract.describe
      expect(d["profile_id"]).to eq("osi-level-8/profile-9")
      expect(d["component_kinds"].size).to eq(19)
      expect(d["component_kinds"]).to include("ScopeTrail", "ReferentBridge")
      expect(d["component_kinds"]).to eq(RailsOsiLevel8::Profile9::Vocabulary::COMPONENT_KINDS)
      names = d["operations"].map { |o| o["name"] }
      expect(names).to include("ux.profile.describe", "ux.contract.check", "ux.page.get")
      expect(d["shape_bundle"]["digest"]).to start_with("sha256:")
      expect(File).to exist(d["shape_bundle"]["absolute_path"])
    end

    it "P9.8 accepts ScopeTrail and refuses an unknown kind" do
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

    it "P9.9 accepts ReferentBridge and refuses a missing required field" do
      ok = RailsOsiLevel8::Profile9::Contract.check(
        "graph" => {
          "cid" => "cid:rb", "profileId" => "osi-level-8/profile-9",
          "componentKind" => "ReferentBridge",
          "sourceConcept" => "https://ex/c",
          "sourceDefinitionRevision" => "https://ex/r",
          "targetExpression" => "cooling-access-site",
          "mappingArtifact" => "https://ex/map",
          "mappingProof" => "https://ex/proof",
          "sourceToTargetScope" => "https://ex/scope/from-to"
        }
      )
      expect(ok["conforms"]).to be(true)

      doc = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
      expect(doc["componentRegistryVersion"]).to eq("ghis-19@1")
      node = {
        "nodeId" => "bridge-001",
        "componentKind" => "ReferentBridge",
        "slt" => {
          "semanticRole" => "article", "contentRole" => "evidence",
          "layoutKind" => "stack", "layoutArity" => "one", "behaviorKind" => "static",
          "responsiveSignature" => "default",
          "tokenSignature" => { "setRef" => "tokens:ghis@1" }
        },
        "props" => {
          "propsSchemaCid" => "cid:schema:referentbridge",
          "valueJson" => {
            "sourceConcept" => "https://ex/c",
            "sourceDefinitionRevision" => "https://ex/r",
            "targetExpression" => "x",
            "mappingArtifact" => "https://ex/map",
            "mappingProof" => "https://ex/proof"
          }
        },
        "variant" => { "variantName" => "readonly" },
        "children" => []
      }
      r = RailsOsiLevel8::Profile9::Acia.validate(doc.merge("root" => node))
      expect(r.conforms?).to eq(false)
      expect(r.because["missing"]).to include("sourceToTargetScope")
    end

    it "P9.10 accepts a complete RefusalNotice and refuses missing required payload" do
      complete = {
        "cid" => "cid:rn", "profileId" => "osi-level-8/profile-9",
        "componentKind" => "RefusalNotice",
        "operation" => "ux.interaction.record",
        "reason" => "UX_EFFECT_AFFORDANCE_DENIED",
        "failedCriteria" => ["authorization.scope"],
        "evidenceRefs" => ["https://ex/auth/ev-1"],
        "remediation" => "Present in-scope authorization evidence and retry.",
        "overridePolicy" => "none"
      }
      ok = RailsOsiLevel8::Profile9::Contract.check("graph" => complete)
      expect(ok["conforms"]).to be(true)

      expect {
        RailsOsiLevel8::Profile9::Contract.check(
          "graph" => complete.merge("operation" => nil, "failedCriteria" => [], "overridePolicy" => nil)
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_ACIA_CONTRACT_INVALID")
        expect(e.because["componentKind"]).to eq("RefusalNotice")
        expect(e.because["missing"]).to include("operation", "failedCriteria", "overridePolicy")
      }
    end

    it "P9.10 Contract.check validates RefusalNotice inside a plain AciaDocument JSON-LD" do
      slt = {
        "semanticRole" => "alert", "contentRole" => "refusal",
        "layoutKind" => "stack", "layoutArity" => "one", "behaviorKind" => "acknowledge",
        "responsiveSignature" => "default",
        "tokenSignature" => { "setRef" => "tokens:ghis@1" }
      }
      incomplete_doc = {
        "@context" => { "@vocab" => "https://w3id.org/cpcp/osi8/ux#" },
        "@type" => "ux:AciaDocument",
        "profileId" => "osi-level-8/profile-9",
        "document" => {
          "schemaVersion" => "acia/v1",
          "componentRegistryVersion" => "ghis-19@1",
          "rootNode" => {
            "nodeId" => "shell-001",
            "componentKind" => "PageShell",
            "slt" => slt.merge("semanticRole" => "landmark", "contentRole" => "context", "behaviorKind" => "static"),
            "props" => { "propsSchemaCid" => "cid:schema:pageshell", "valueJson" => { "title" => "x" } },
            "children" => [
              {
                "nodeId" => "refusal-001",
                "componentKind" => "RefusalNotice",
                "slt" => slt,
                "props" => {
                  "propsSchemaCid" => "cid:schema:refusalnotice",
                  "valueJson" => {
                    "trigger" => "early attempt",
                    "heading" => "refused",
                    "reason" => "The source definition is active but the effect is not eligible.",
                    "remediation" => "Clarify the dispute.",
                    "override" => "No override is available."
                  }
                }
              }
            ]
          }
        }
      }
      expect {
        RailsOsiLevel8::Profile9::Contract.check("graph" => incomplete_doc)
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_ACIA_CONTRACT_INVALID")
        expect(e.because["missing"]).to include("operation", "failedCriteria", "overridePolicy", "evidenceRefs")
        expect(e.because["invalid"]).to include("reason")
      }

      complete_doc = Marshal.load(Marshal.dump(incomplete_doc))
      complete_doc["document"]["rootNode"]["children"][0]["props"]["valueJson"] = {
        "operation" => "ux.interaction.record",
        "reason" => "UX_EFFECT_AFFORDANCE_DENIED",
        "failedCriteria" => ["actability.effect-eligible"],
        "evidenceRefs" => ["https://ex/dispute/sd-1"],
        "remediation" => "Clarify the disputed condition, then retry.",
        "overridePolicy" => "none"
      }
      ok = RailsOsiLevel8::Profile9::Contract.check("graph" => complete_doc)
      expect(ok["conforms"]).to be(true)
    end

    it "P9.10 evidenceRefs is required except for the closed envelope/shape/token-failure set" do
      envelope = {
        "componentKind" => "RefusalNotice",
        "operation" => "ux.contract.check",
        "reason" => "UX_ENVELOPE_INVALID",
        "failedCriteria" => ["envelope"],
        "remediation" => "Supply a complete request envelope.",
        "overridePolicy" => "none"
      }
      ok = RailsOsiLevel8::Profile9::Contract.check("graph" => envelope)
      expect(ok["conforms"]).to be(true)

      expect {
        RailsOsiLevel8::Profile9::Contract.check(
          "graph" => envelope.merge("reason" => "UX_EFFECT_AFFORDANCE_DENIED")
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.because["missing"]).to include("evidenceRefs")
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

    it "P9.10 refuses a RefusalNotice missing required payload parts" do
      doc = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
      node = {
        "nodeId" => "refusal-001",
        "componentKind" => "RefusalNotice",
        "slt" => {
          "semanticRole" => "alert", "contentRole" => "refusal",
          "layoutKind" => "stack", "layoutArity" => "one", "behaviorKind" => "acknowledge",
          "responsiveSignature" => "default",
          "tokenSignature" => { "setRef" => "tokens:ghis@1" }
        },
        "props" => {
          "propsSchemaCid" => "cid:schema:refusalnotice",
          "valueJson" => {
            "reason" => "UX_EFFECT_AFFORDANCE_DENIED",
            "remediation" => "Retry with authorization evidence."
          }
        },
        "variant" => { "variantName" => "warning" },
        "children" => []
      }
      r = RailsOsiLevel8::Profile9::Acia.validate(doc.merge("root" => node))
      expect(r.conforms?).to eq(false)
      expect(r.because["missing"]).to include("operation", "failedCriteria", "overridePolicy", "evidenceRefs")

      node["props"]["valueJson"] = {
        "operation" => "ux.interaction.record",
        "reason" => "UX_EFFECT_AFFORDANCE_DENIED",
        "failedCriteria" => ["authorization.scope"],
        "evidenceRefs" => ["https://ex/auth/ev-1"],
        "remediation" => "Retry with authorization evidence.",
        "overridePolicy" => "none"
      }
      ok = RailsOsiLevel8::Profile9::Acia.validate(doc.merge("root" => node))
      expect(ok.conforms?).to eq(true)
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
      expect(r["html"]).to include('data-ux-operation="ux.render"')
      expect(r["html"]).to include('data-ux-failed-criteria="tokenSignature.setRef"')
      expect(r["html"]).to include('data-ux-override-policy="none"')
      expect(r["html"]).to include("data-ux-remediation=")
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

    it "P9.11 authorization-review page is the J1 ACIA and a complete RefusalNotice" do
      doc = RailsOsiLevel8::Profile9::Acia.authorization_review_fixture
      r = RailsOsiLevel8::Profile9::Acia.validate(doc)
      expect(r.conforms?).to be(true)
      kinds = []
      walk = ->(n) {
        kinds << n["componentKind"] if n.is_a?(Hash)
        Array(n.is_a?(Hash) ? n["children"] : nil).each { |c| walk.call(c) }
      }
      walk.call(doc["root"])
      expect(kinds).to include(
        "PageShell", "ContextBanner", "EvidencePanel", "Timeline",
        "Disclosure", "DecisionForm", "ActionControl", "RefusalNotice"
      )

      ok = RailsOsiLevel8::Profile9::Contract.check("graph" => doc)
      expect(ok["conforms"]).to be(true)

      bundle = RailsOsiLevel8::Profile9::Pulls.page_get(
        "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
        "correlationId" => "corr-p911",
        "receiptSeed" => "seed-p911"
      )
      expect(bundle.dig("aciaDocument", "root", "nodeId")).to eq("j1-pageshell-1")
      html = RailsOsiLevel8::Profile9::Renderer.render(bundle)["html"]
      expect(html).to include('data-ux-component-kind="DecisionForm"')
      expect(html).to include('data-ux-component-kind="RefusalNotice"')
      expect(html).to include('data-ux-component-kind="EvidencePanel"')
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




