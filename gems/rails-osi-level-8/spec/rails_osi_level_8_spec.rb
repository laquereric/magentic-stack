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
      expect(names).to include("ux.profile.describe", "ux.contract.check", "ux.page.get", "ux.inspect")
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

    it "L8-R05 operation is a declared CPCP name or kebab-case surface-action id" do
      base = {
        "componentKind" => "RefusalNotice",
        "reason" => "UX_EFFECT_AFFORDANCE_DENIED",
        "failedCriteria" => ["authorization.scope", "actability.effect-eligible"],
        "evidenceRefs" => ["https://ex/auth/ev-1"],
        "remediation" => "Present in-scope evidence and retry.",
        "overridePolicy" => "none"
      }
      ok = RailsOsiLevel8::Profile9::Contract.check(
        "graph" => base.merge("operation" => "ux.interaction.record")
      )
      expect(ok["conforms"]).to be(true)

      ok2 = RailsOsiLevel8::Profile9::Contract.check(
        "graph" => {
          "componentKind" => "PageShell",
          "children" => [
            { "componentKind" => "ActionControl", "props" => { "valueJson" => { "action" => "activate-heat-alert-map" } } },
            base.merge("operation" => "activate-heat-alert-map")
          ]
        }
      )
      expect(ok2["conforms"]).to be(true)

      # Q8: kebab without a same-document publisher is a valid productive refusal.
      ok3 = RailsOsiLevel8::Profile9::Contract.check(
        "graph" => base.merge("operation" => "activate-heat-alert-map")
      )
      expect(ok3["conforms"]).to be(true)

      expect {
        RailsOsiLevel8::Profile9::Contract.check(
          "graph" => base.merge("operation" => "ux.not.a.method")
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.because["invalid"]).to include("operation")
      }

      expect {
        RailsOsiLevel8::Profile9::Contract.check(
          "graph" => base.merge("operation" => "ActivateHeatAlertMap")
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.because["invalid"]).to include("operation")
      }
    end

    it "Q8 productive refusal: RN kebab may differ from the remediation control" do
      ok = RailsOsiLevel8::Profile9::Contract.check(
        "graph" => {
          "componentKind" => "PageShell",
          "children" => [
            {
              "componentKind" => "ActionControl",
              "props" => { "valueJson" => { "label" => "Begin meaning clarification", "action" => "begin-meaning-clarification" } }
            },
            {
              "componentKind" => "RefusalNotice",
              "operation" => "activate-heat-alert-map",
              "reason" => "meaning.actability-insufficient",
              "failedCriteria" => ["dispute-open"],
              "evidenceRefs" => ["cid:page:a3-orientation-activation-refused"],
              "remediation" => "Begin meaning clarification, then retry activation.",
              "overridePolicy" => "none"
            }
          ]
        }
      )
      expect(ok["conforms"]).to be(true)
    end

    it "Q8 ActionControl action, when present, must be a kebab identifier not prose" do
      expect {
        RailsOsiLevel8::Profile9::Contract.check(
          "graph" => {
            "componentKind" => "ActionControl",
            "props" => { "valueJson" => { "action" => "Evaluate whether Heat Alert Map Activation may be effected" } }
          }
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_ACIA_CONTRACT_INVALID")
        expect(e.because["invalid"]).to include("action")
      }
    end

    it "L8-R05 reason is singular; failedCriteria lists every independent blocker" do
      ok = RailsOsiLevel8::Profile9::Contract.check(
        "graph" => {
          "componentKind" => "PageShell",
          "children" => [
            { "componentKind" => "ActionControl", "props" => { "valueJson" => { "action" => "activate-heat-alert-map" } } },
            {
              "componentKind" => "RefusalNotice",
              "operation" => "activate-heat-alert-map",
              "reason" => "meaning.actability-insufficient",
              "failedCriteria" => %w[dispute-open authorization-reference-missing semantic-activation-missing],
              "evidenceRefs" => ["cid:page:a3-orientation-activation-refused"],
              "remediation" => "Clarify the dispute, then retry.",
              "overridePolicy" => "none"
            }
          ]
        }
      )
      expect(ok["conforms"]).to be(true)

      expect {
        RailsOsiLevel8::Profile9::Contract.check(
          "graph" => {
            "componentKind" => "PageShell",
            "children" => [
              { "componentKind" => "ActionControl", "props" => { "valueJson" => { "action" => "activate-heat-alert-map" } } },
              {
                "componentKind" => "RefusalNotice",
                "operation" => "activate-heat-alert-map",
                "reason" => "meaning.actability-insufficient,meaning.verification-failed",
                "failedCriteria" => ["dispute-open"],
                "evidenceRefs" => ["cid:page:x"],
                "remediation" => "x",
                "overridePolicy" => "none"
              }
            ]
          }
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.because["invalid"]).to include("reason")
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
      expect(shape_names.size).to eq(26)
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
    before do
      root = Pathname(File.expand_path("../data/osi-level-8", __dir__))
      RailsOsiLevel8.configure do |c|
        c.shape_root = root
        c.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(root)
      end
    end

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

    it "Q9 translation board ACIA validates and exercises the Q8 rule" do
      doc = RailsOsiLevel8::Profile9::Acia.translation_board_document
      r = RailsOsiLevel8::Profile9::Acia.validate(doc)
      expect(r.conforms?).to eq(true)
      ok = RailsOsiLevel8::Profile9::Contract.check("graph" => doc)
      expect(ok["conforms"]).to be(true)

      kinds = []
      actions = []
      walk = lambda { |n|
        next unless n.is_a?(Hash)
        kinds << n["componentKind"]
        if n["componentKind"] == "ActionControl"
          actions << n.dig("props", "valueJson", "action")
        end
        Array(n["children"]).each { |c| walk.call(c) }
      }
      walk.call(doc["root"])
      expect(kinds).to include(
        "PageShell", "PanelFrame", "DataList", "DrillDownCard",
        "ActionControl", "RefusalNotice", "ReferentBridge", "EvidencePanel",
        "ScopeTrail", "FilterBar", "StatusBadge"
      )
      # ContextBanner is gone from this board. Its one sentence was explanation
      # ABOUT the board rather than content OF it, and it now lives behind the ?
      # on the title. The kind is still in the vocabulary; this board has no use
      # for a strip that says the same thing to every reader on every visit.
      expect(kinds).not_to include("ContextBanner")
      expect(kinds).not_to include("Board", "Column", "Card")
      expect(actions).to all(match(/\A[a-z][a-z0-9-]*\z/))
      expect(actions).to include(
        "explore", "inspect-eligibility", "continue-clarification",
        "enter-productive-refusal-wall", "select-frame", "apply-frame-edits"
      )

      # EXPLORE IS THE ONLY THING A CARD OFFERS. The distinction -- which act is
      # available here, and why -- is made in the modal, after the grounds are
      # on screen. A card advertising "Continue clarification" asked the reader
      # to choose before they had been shown anything to choose on.
      cards = []
      find_cards = lambda { |n|
        next unless n.is_a?(Hash)
        cards << n if n["componentKind"] == "DrillDownCard"
        Array(n["children"]).each { |c| find_cards.call(c) }
      }
      find_cards.call(doc["root"])
      expect(cards.length).to be >= 10
      cards.each do |c|
        offered = Array(c["children"])
                  .select { |k| k["componentKind"] == "ActionControl" }
                  .map { |k| k.dig("props", "valueJson", "action") }
        # THE RAIL IS ALWAYS THE SAME THREE MARKS, IN THE SAME ORDER: assert,
        # ask, remove. The two that only look come first and the one that
        # destroys comes last, so the destructive control is never the thing a
        # hand lands on by momentum.
        expect(offered.length).to eq(3), "card #{c['nodeId']} offers #{offered.inspect}"
        expect(offered[0]).to start_with("trace-"), "card #{c['nodeId']} offers #{offered.inspect}"
        expect(offered[1]).to eq("explore"), "card #{c['nodeId']} offers #{offered.inspect}"
        expect(offered[2]).to start_with("remove-"), "card #{c['nodeId']} offers #{offered.inspect}"

        # The nouns agree: what you trace and what you remove are the same kind
        # of thing, and both are derived from the canonical id rather than
        # written per call site.
        expect(offered[0].sub("trace-", "")).to eq(offered[2].sub("remove-", ""))
        expect(c.dig("props", "valueJson", "canonicalId")).to match(/\A[XY]\d/)
      end

      # + AND - ARE ONE CONVENTION. A plus beside every heading that holds
      # cards, a minus on every card, and the nouns agree: what a plus adds is
      # what the matching minus takes away.
      nouns = actions.grep(/\Aadd-/).map { |a| a.sub("add-", "") }.uniq.sort
      expect(nouns).to eq(%w[carry clarification frame input meaning reference])
      nouns.each do |noun|
        expect(actions).to include("remove-#{noun}"), "no remove for #{noun}"
      end

      # Adding is composing: the plus opens the editor with nothing written in
      # it yet, which is why there is no second "Write in prose" button.
      adds = []
      find_adds = lambda { |n|
        next unless n.is_a?(Hash)
        v = n.dig("props", "valueJson")
        adds << v if v.is_a?(Hash) && v["action"].to_s.start_with?("add-")
        Array(n["children"]).each { |c| find_adds.call(c) }
      }
      find_adds.call(doc["root"])
      expect(adds.length).to eq(nouns.length)
      expect(adds.map { |v| v["navigatesTo"] }).to all(include("compose="))

      # Navigation is a link, so it has somewhere to go.
      explores = []
      find_explore = lambda { |n|
        next unless n.is_a?(Hash)
        v = n.dig("props", "valueJson")
        explores << v if v.is_a?(Hash) && v["action"] == "explore"
        Array(n["children"]).each { |c| find_explore.call(c) }
      }
      find_explore.call(doc["root"])
      expect(explores).not_to be_empty
      expect(explores.map { |v| v["navigatesTo"] }).to all(include("explore="))
      expect(actions).not_to include("drag-card-to-column")

      notices = []
      find_rn = lambda { |n|
        next unless n.is_a?(Hash)
        notices << n.dig("props", "valueJson") if n["componentKind"] == "RefusalNotice"
        Array(n["children"]).each { |c| find_rn.call(c) }
      }
      find_rn.call(doc["root"])
      ops = notices.map { |v| v["operation"] }
      expect(ops).to include("issue-unverified-action-language", "claim-plan-eligible", "drag-card-to-column")
      expect(ops - actions).to include("issue-unverified-action-language", "drag-card-to-column", "claim-plan-eligible")

      suggest = nil
      find_s = lambda { |n|
        next unless n.is_a?(Hash)
        if n["nodeId"] == "brd-mn-suggest"
          suggest = n
        end
        Array(n["children"]).each { |c| find_s.call(c) }
      }
      find_s.call(doc["root"])
      expect(suggest.dig("props", "valueJson", "displayBandLabel")).to be_nil
      expect(suggest.dig("props", "valueJson", "presentationState")).to be_nil
      lists = {}
      find_list = lambda { |n|
        next unless n.is_a?(Hash)
        if n["componentKind"] == "DataList"
          lists[n.dig("props", "valueJson", "listKey")] = Array(n["children"]).map { |c| c["nodeId"] }
        end
        Array(n["children"]).each { |c| find_list.call(c) }
      }
      find_list.call(doc["root"])
      expect(lists["meaning-accepted"]).to include("brd-mn-evac", "brd-mn-protective")
      expect(lists["meaning-accepted"]).not_to include("brd-mn-suggest")
      expect(lists["meaning-suggestions"]).to eq(["brd-mn-suggest"])
    end

    it "R2 presentationState is inspect-only text and is not persistable" do
      base = RailsOsiLevel8::Profile9::Acia.translation_board_document
      expect(RailsOsiLevel8::Profile9::Acia.validate(base).conforms?).to eq(true)

      tainted = Marshal.load(Marshal.dump(base))
      planted = false
      plant = lambda { |n|
        next if planted || !n.is_a?(Hash)
        if n["componentKind"] == "DrillDownCard"
          n["props"]["valueJson"]["presentationState"] = "selected"
          planted = true
        end
        Array(n["children"]).each { |c| plant.call(c) }
      }
      plant.call(tainted["root"])
      bad = RailsOsiLevel8::Profile9::Acia.validate(tainted)
      expect(bad.conforms?).to eq(false)
      expect(bad.because["invalid"]).to include("presentationState")

      expect {
        RailsOsiLevel8::Profile9::Contract.check("graph" => tainted)
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.because["invalid"]).to include("presentationState")
      }

      proj = RailsOsiLevel8::Profile9::Acia.translation_board_inspect_document
      r = RailsOsiLevel8::Profile9::Acia.validate(proj)
      expect(r.conforms?).to eq(true)
      ok = RailsOsiLevel8::Profile9::Contract.check("graph" => proj)
      expect(ok["conforms"]).to be(true)

      states = {}
      walk = lambda { |n|
        next unless n.is_a?(Hash)
        if n["componentKind"] == "DrillDownCard" && n.dig("props", "valueJson", "presentationState")
          states[n["nodeId"]] = n.dig("props", "valueJson", "presentationState")
        end
        Array(n["children"]).each { |c| walk.call(c) }
      }
      walk.call(proj["root"])
      expect(states).to include(
        "brd-or-evacuate" => "selected",
        "brd-mn-evac" => "likely-hit",
        "brd-mn-protective" => "related",
        "brd-mn-suggest" => "suggested",
        "brd-or-volunteers" => "out-of-scope"
      )

      html = RailsOsiLevel8::Profile9::Renderer.render(
        "aciaDocument" => proj,
        "tokenSet" => RailsOsiLevel8::Profile9::Renderer.default_token_set,
        "correlationId" => "corr-r2",
        "receiptSeed" => "seed-r2"
      )
      expect(html["ok"]).to be(true)
      expect(html["html"]).to include('data-ux-presentation-state="selected"')
      expect(html["html"]).to include('data-ux-explore-trace')
      expect(html["html"]).to include("Explore: selected")
      expect(html["html"]).to include("Explore: likely hit")
      expect(html["html"]).to include("Explore: out of scope")
      expect(html["html"]).not_to include("data-ux-presentation-state=\"green\"")
    end

    it "R3 host layout recipes; renderer emits no layout attributes" do
      doc = RailsOsiLevel8::Profile9::Acia.translation_board_document
      slt = RailsOsiLevel8::Profile9::HostLayout.board_container_slt(doc)
      expect(slt["layoutKind"]).to eq("grid")
      expect(slt["layoutArity"]).to eq("three")
      expect(slt["responsiveSignature"]).to eq("p9.r1.grid.board-3")
      board = nil
      find = lambda { |n|
        next unless n.is_a?(Hash)
        board = n if n["nodeId"] == "brd-board-1"
        Array(n["children"]).each { |c| find.call(c) }
      }
      find.call(doc["root"])
      expect(board["children"].size).to eq(3)

      three = RailsOsiLevel8::Profile9::HostLayout.decide(
        layout_kind: "grid", layout_arity: "three",
        responsive_signature: "p9.r1.grid.board-3", participating_child_count: 3
      )
      expect(three["apply"]).to be(true)
      expect(three.dig("recipe", "tracksWide")).to eq(3)

      five = RailsOsiLevel8::Profile9::HostLayout.decide(
        layout_kind: "grid", layout_arity: "many",
        responsive_signature: "p9.r1.grid.board-5", participating_child_count: 5
      )
      expect(five["apply"]).to be(true)
      expect(five.dig("recipe", "tracksWide")).to eq(5)
      expect(five.dig("recipe", "compact")).to eq("stack")

      squeezed = RailsOsiLevel8::Profile9::HostLayout.decide(
        layout_kind: "grid", layout_arity: "many",
        responsive_signature: "p9.r1.grid.board-5", participating_child_count: 3
      )
      expect(squeezed["apply"]).to be(false)

      generic = RailsOsiLevel8::Profile9::HostLayout.decide(
        layout_kind: "grid", layout_arity: "many",
        responsive_signature: "default", participating_child_count: 5
      )
      expect(generic["apply"]).to be(false)
      expect(generic["fallback"]).to eq("flow")

      html = RailsOsiLevel8::Profile9::Renderer.render(
        "aciaDocument" => doc,
        "tokenSet" => RailsOsiLevel8::Profile9::Renderer.default_token_set,
        "correlationId" => "corr-r3",
        "receiptSeed" => "seed-r3"
      )
      expect(html["ok"]).to be(true)
      expect(html["html"]).not_to include("data-ux-layout-kind")
      expect(html["html"]).not_to include("data-ux-layout-arity")
      expect(html["html"]).not_to include("data-ux-responsive-signature")
      expect(html["html"]).to include('data-ux-node-id="brd-board-1"')
      expect(File).to exist(File.expand_path("../data/osi-level-8/ux-host-layout.js", __dir__))
    end

    it "Q5 conformant RefusalNotice is the copyable L8-R05 example" do
      doc = RailsOsiLevel8::Profile9::Acia.conformant_refusal_document
      r = RailsOsiLevel8::Profile9::Acia.validate(doc)
      expect(r.conforms?).to eq(true)
      ok = RailsOsiLevel8::Profile9::Contract.check("graph" => doc)
      expect(ok["conforms"]).to be(true)
      notice = doc.dig("root", "children").find { |n| n["componentKind"] == "RefusalNotice" }
      vj = notice.dig("props", "valueJson")
      expect(vj["operation"]).to eq("request-effect")
      expect(vj["failedCriteria"].size).to be > 1
      expect(vj["overridePolicy"]).to eq("none")
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
      %w[ux.journey.list ux.journey.get ux.flow.get ux.page.get ux.inspect].each do |name|
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

    it "P9-BRD-02 ux.inspect returns a new attested ACIA and refuses client-side reuse" do
      page = RailsOsiLevel8::Profile9::Pulls.page_get(
        "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
        "correlationId" => "corr-pred-inspect",
        "receiptSeed" => "seed-pred-inspect"
      )
      pred_digest = RailsOsiLevel8::Profile9::Acia.validate(page["aciaDocument"]).digest
      origin = "j1-actioncontrol-1"

      proj = RailsOsiLevel8::Profile9::Pulls.inspect(
        "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
        "originNodeId" => origin,
        "predecessorDigest" => pred_digest,
        "predecessorCorrelation" => "corr-pred-inspect",
        "correlationId" => "corr-succ-inspect",
        "receiptSeed" => "seed-succ-inspect"
      )
      expect(proj["@type"]).to eq("ux:InspectProjectionBundle")
      expect(proj["correlationId"]).to eq("corr-succ-inspect")
      expect(proj["correlationId"]).not_to eq("corr-pred-inspect")
      expect(proj["predecessorDigest"]).to eq(pred_digest)
      expect(proj["predecessorCorrelation"]).to eq("corr-pred-inspect")
      expect(proj["inspectOriginNodeId"]).to eq(origin)
      expect(proj["aciaDigest"]).to eq(RailsOsiLevel8::Profile9::Acia.validate(proj["aciaDocument"]).digest)
      expect(proj["aciaDigest"]).not_to eq(pred_digest)
      expect(proj.dig("aciaDocument", "projectionKind")).to eq("inspect")
      expect(proj.dig("shownContext", "aciaDocumentDigest")).to eq(proj["aciaDigest"])

      rendered = RailsOsiLevel8::Profile9::Renderer.render(proj)
      expect(rendered["ok"]).to be(true)
      expect(rendered["html"]).to include("data-ux-correlation=\"corr-succ-inspect\"")
      expect(rendered["html"]).to include("data-ux-acia-digest=\"#{proj["aciaDigest"]}\"")
      expect(rendered["html"]).not_to include("data-ux-correlation=\"corr-pred-inspect\"")

      expect {
        RailsOsiLevel8::Profile9::Pulls.inspect(
          "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
          "originNodeId" => origin,
          "predecessorDigest" => pred_digest,
          "predecessorCorrelation" => "corr-pred-inspect",
          "correlationId" => "corr-pred-inspect"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_ENVELOPE_INVALID")
        expect(e.because["invalid"]).to include("correlationId")
      }

      expect {
        RailsOsiLevel8::Profile9::Pulls.inspect(
          "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
          "originNodeId" => origin,
          "predecessorDigest" => "sha256:deadbeef",
          "predecessorCorrelation" => "corr-pred-inspect",
          "correlationId" => "corr-other"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_LINEAGE_UNRESOLVED")
        expect(e.because["resource"]).to eq("predecessorDigest")
      }

      expect {
        RailsOsiLevel8::Profile9::Pulls.inspect(
          "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
          "originNodeId" => "no-such-node",
          "predecessorDigest" => pred_digest,
          "predecessorCorrelation" => "corr-pred-inspect",
          "correlationId" => "corr-other"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_LINEAGE_UNRESOLVED")
        expect(e.because["resource"]).to eq("originNodeId")
      }
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

      inspect_tree = Marshal.load(Marshal.dump(good))
      inspect_tree["projectionKind"] = "inspect"
      expect {
        mut.acia_mutate_propose(
          "predecessorCid" => ok["cid"],
          "predecessorDigest" => ok["digest"],
          "successor" => inspect_tree
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("UX_ACIA_CONTRACT_INVALID")
        expect(e.because["invalid"]).to include("projectionKind")
      }

      marked = RailsOsiLevel8::Profile9::Acia.translation_board_inspect_document
      marked.delete("projectionKind")
      expect {
        mut.acia_mutate_propose(
          "predecessorCid" => ok["cid"],
          "predecessorDigest" => ok["digest"],
          "successor" => marked
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.because["invalid"]).to include("presentationState")
      }
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




