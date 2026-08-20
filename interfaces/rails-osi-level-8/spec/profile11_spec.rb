# frozen_string_literal: true

require "spec_helper"
require "pathname"

RSpec.describe RailsOsiLevel8::Profile11 do
  V = RailsOsiLevel8::Profile11::Vocabulary
  C = RailsOsiLevel8::Profile11::Contract
  S = RailsOsiLevel8::Profile11::Store
  E = RailsOsiLevel8::Profile11::Evaluator

  before do
    root = Pathname(File.expand_path("../data/osi-level-8", __dir__))
    RailsOsiLevel8.configure do |c|
      c.shape_root = root
      c.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(root)
    end
    S.reset!
  end

  def concept!
    S.put_concept!(
      "cid" => "https://ex/concept/alpha",
      "@type" => "Concept",
      "label" => "Alpha",
      "scope" => "https://ex/scope/pod"
    )
  end

  def revision!(lifecycle:, formalization: "structured", cid: "https://ex/rev/alpha/1")
    S.put_revision!(
      "cid" => cid,
      "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha",
      "content" => "Alpha is a thing",
      "scope" => "https://ex/scope/pod",
      "definitionLifecycle" => lifecycle,
      "formalization" => formalization
    )
  end

  describe "P11.1 closed records" do
    it "describes profile-11 record types and derived bands" do
      d = C.describe
      expect(d["profile_id"]).to eq("osi-level-8/profile-11")
      expect(d["record_types"]).to include(
        "Concept", "SemanticDispute", "DisputeResolution",
        "StewardshipTranslation", "TranslationReview"
      )
      expect(d["record_types"]).to eq(V::RECORD_TYPES)
      expect(d["derived_bands"]).to eq(V::BANDS)
      expect(File).to exist(d.dig("shape_bundle", "absolute_path"))
    end

    it "validates each of the six record types and refuses unknown keys" do
      samples = {
        "Concept" => { "cid" => "https://ex/c", "label" => "L", "scope" => "https://ex/s" },
        "DefinitionRevision" => {
          "cid" => "https://ex/r", "concept" => "https://ex/c", "content" => "x",
          "scope" => "https://ex/s", "definitionLifecycle" => "candidate", "formalization" => "narrative"
        },
        "SemanticAttestation" => {
          "cid" => "https://ex/a", "definitionRevision" => "https://ex/r", "signer" => "https://ex/actor",
          "authorityRef" => "https://ex/p6", "evidenceRef" => "https://ex/ev", "scope" => "https://ex/s",
          "agreement" => "local", "attestedAt" => "2026-08-20T00:00:00Z"
        },
        "OperationBinding" => {
          "cid" => "https://ex/b", "definitionRevision" => "https://ex/r",
          "operationRevision" => "https://ex/op/1", "contractDigest" => "sha256:aa",
          "shapeDigest" => "sha256:bb", "binding" => "declared"
        },
        "SemanticActivation" => {
          "cid" => "https://ex/act", "concept" => "https://ex/c", "definitionRevision" => "https://ex/r",
          "scope" => "https://ex/s", "policyRevision" => "https://ex/pol/1", "baseSequence" => 1
        },
        "ActabilityReceipt" => {
          "cid" => "https://ex/rcpt", "definitionRevision" => "https://ex/r",
          "policyRevision" => "https://ex/pol/1", "scope" => "https://ex/s",
          "namedUse" => "explore", "actabilityBand" => "explorable",
          "asOfSequence" => 1, "dispute" => "none", "digest" => "sha256:cc"
        },
        "SemanticDispute" => {
          "cid" => "https://ex/d", "target" => "https://ex/r", "scope" => "https://ex/s",
          "raiser" => "https://ex/actor", "claim" => "no", "evidenceRef" => "https://ex/ev"
        },
        "DisputeResolution" => {
          "cid" => "https://ex/res", "dispute" => "https://ex/d", "resolver" => "https://ex/actor",
          "scope" => "https://ex/s", "authorityRef" => "https://ex/p6", "disposition" => "dismiss"
        },
        "StewardshipTranslation" => {
          "cid" => "https://ex/tr", "refersTo" => "https://ex/c", "groundedIn" => "https://ex/r",
          "audience" => "https://ex/aud", "scope" => "https://ex/s", "author" => "https://ex/actor",
          "rendering" => "Alpha, in other words"
        },
        "TranslationReview" => {
          "cid" => "https://ex/rv", "translation" => "https://ex/tr", "reviewer" => "https://ex/actor",
          "scope" => "https://ex/s", "authorityRef" => "https://ex/p6", "outcome" => "approved"
        }
      }
      samples.each do |type, fields|
        rec = fields.merge("@type" => type, "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical")
        r = C.validate(rec)
        expect(r.ok).to eq(true), "#{type} should conform: #{r.to_h}"
        bad = C.validate(rec.merge("style" => "color:red"))
        expect(bad.ok).to eq(false)
        expect(bad.reason).to eq("MEANING_UNKNOWN_PREDICATE")
        expect(bad.because["unknown_predicates"]).to include("style")
      end
    end

    it "rejects values outside each of the five dimension enumerations" do
      rec = {
        "@type" => "DefinitionRevision", "cid" => "https://ex/r", "concept" => "https://ex/c",
        "content" => "x", "scope" => "https://ex/s", "definitionLifecycle" => "published",
        "formalization" => "structured", "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      }
      r = C.validate(rec)
      expect(r.ok).to eq(false)
      expect(r.reason).to eq("MEANING_ENUM_INVALID")
      expect(r.because["dimension"]).to eq("definitionLifecycle")
      expect(r.because["allowed"]).to eq(V::LIFECYCLES)
    end

    it "refuses actabilityBand on every non-receipt record (no set-band path)" do
      V::RECORD_TYPES.each do |type|
        next if type == "ActabilityReceipt"

        rec = { "@type" => type, "cid" => "https://ex/x", "actabilityBand" => "effect-eligible",
                "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical" }
        r = C.validate(rec)
        expect(r.ok).to eq(false)
        expect(r.reason).to eq("MEANING_BAND_FORBIDDEN")
        expect(r.because["forbidden"]).to include("actabilityBand")
      end
      expect(S.methods.grep(/band=/)).to be_empty
      expect(defined?(E.set_band)).to be_nil
    end
  end

  describe "P11.2 actability evaluator (conformance)" do
    it "1. candidate+structured is explorable and not plan-eligible" do
      concept!
      revision!(lifecycle: "candidate", formalization: "structured")
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expect(rcpt["actabilityBand"]).to eq("explorable")
      expect(rcpt["dimensions"]["definitionLifecycle"]).to eq("candidate")
      expect {
        E.evaluate(
          "concept" => "https://ex/concept/alpha",
          "definitionRevision" => "https://ex/rev/alpha/1",
          "scope" => "https://ex/scope/pod",
          "namedUse" => "plan"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.definition-inactive").or eq("meaning.actability-insufficient")
      }
    end

    it "2. declared binding without verified evidence refuses actability-insufficient" do
      concept!
      revision!(lifecycle: "active")
      S.put_attestation!(
        "cid" => "https://ex/att/1", "@type" => "SemanticAttestation",
        "definitionRevision" => "https://ex/rev/alpha/1", "signer" => "https://ex/actor",
        "authorityRef" => "https://ex/p6/1", "evidenceRef" => "https://ex/ev/1",
        "scope" => "https://ex/scope/pod", "agreement" => "local",
        "attestedAt" => "2026-08-20T00:00:00Z"
      )
      S.put_binding!(
        "cid" => "https://ex/bind/1", "@type" => "OperationBinding",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "operationRevision" => "https://ex/op/1",
        "contractDigest" => "sha256:contract1",
        "shapeDigest" => "sha256:shape1",
        "binding" => "declared"
      )
      expect {
        E.evaluate(
          "concept" => "https://ex/concept/alpha",
          "definitionRevision" => "https://ex/rev/alpha/1",
          "scope" => "https://ex/scope/pod",
          "namedUse" => "effect",
          "operationRevision" => "https://ex/op/1",
          "contractDigest" => "sha256:contract1",
          "policyRevision" => "https://ex/pol/1"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.actability-insufficient")
        expect(e.because["haveBand"]).to eq("plan-eligible")
        expect(e.because["requiredBand"]).to eq("effect-eligible")
      }
    end

    it "3. attested verified tuple yields effect-eligible receipt" do
      concept!
      revision!(lifecycle: "active")
      S.put_attestation!(
        "cid" => "https://ex/att/1", "@type" => "SemanticAttestation",
        "definitionRevision" => "https://ex/rev/alpha/1", "signer" => "https://ex/actor",
        "authorityRef" => "https://ex/p6/1", "evidenceRef" => "https://ex/ev/1",
        "scope" => "https://ex/scope/pod", "agreement" => "local",
        "attestedAt" => "2026-08-20T00:00:00Z"
      )
      S.put_binding!(
        "cid" => "https://ex/bind/1", "@type" => "OperationBinding",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "operationRevision" => "https://ex/op/1",
        "contractDigest" => "sha256:contract1",
        "shapeDigest" => "sha256:shape1",
        "implementationDigest" => "sha256:shape1",
        "binding" => "verified"
      )
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "effect",
        "operationRevision" => "https://ex/op/1",
        "contractDigest" => "sha256:contract1",
        "policyRevision" => "https://ex/pol/1"
      )
      expect(rcpt["actabilityBand"]).to eq("effect-eligible")
      expect(rcpt["digest"]).to match(/\Asha256:[0-9a-f]{64}\z/)
      @receipt = rcpt
    end

    it "4. changing only contractDigest refuses binding-stale" do
      concept!
      revision!(lifecycle: "active")
      S.put_attestation!(
        "cid" => "https://ex/att/1", "@type" => "SemanticAttestation",
        "definitionRevision" => "https://ex/rev/alpha/1", "signer" => "https://ex/actor",
        "authorityRef" => "https://ex/p6/1", "evidenceRef" => "https://ex/ev/1",
        "scope" => "https://ex/scope/pod", "agreement" => "local",
        "attestedAt" => "2026-08-20T00:00:00Z"
      )
      S.put_binding!(
        "cid" => "https://ex/bind/1", "@type" => "OperationBinding",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "operationRevision" => "https://ex/op/1",
        "contractDigest" => "sha256:contract1",
        "shapeDigest" => "sha256:shape1",
        "binding" => "verified"
      )
      expect {
        E.evaluate(
          "concept" => "https://ex/concept/alpha",
          "definitionRevision" => "https://ex/rev/alpha/1",
          "scope" => "https://ex/scope/pod",
          "namedUse" => "effect",
          "operationRevision" => "https://ex/op/1",
          "contractDigest" => "sha256:contract-CHANGED",
          "policyRevision" => "https://ex/pol/1"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.binding-stale")
        expect(e.because["pinned"]).to eq("sha256:contract1")
        expect(e.because["requested"]).to eq("sha256:contract-CHANGED")
      }
    end

    it "5. open challenge: old receipt reproduces; new eval is contested" do
      concept!
      revision!(lifecycle: "active")
      S.put_attestation!(
        "cid" => "https://ex/att/1", "@type" => "SemanticAttestation",
        "definitionRevision" => "https://ex/rev/alpha/1", "signer" => "https://ex/actor",
        "authorityRef" => "https://ex/p6/1", "evidenceRef" => "https://ex/ev/1",
        "scope" => "https://ex/scope/pod", "agreement" => "local",
        "attestedAt" => "2026-08-20T00:00:00Z"
      )
      S.put_binding!(
        "cid" => "https://ex/bind/1", "@type" => "OperationBinding",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "operationRevision" => "https://ex/op/1",
        "contractDigest" => "sha256:contract1",
        "shapeDigest" => "sha256:shape1",
        "binding" => "verified"
      )
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "effect",
        "operationRevision" => "https://ex/op/1",
        "contractDigest" => "sha256:contract1",
        "policyRevision" => "https://ex/pol/1"
      )
      S.put_dispute!(
        "cid" => "https://ex/disp/1", "@type" => "SemanticDispute",
        "target" => "https://ex/rev/alpha/1",
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "raiser" => "https://ex/actor/challenger",
        "claim" => "The tuple is contested",
        "evidenceRef" => "https://ex/p5/1"
      )
      replay = E.reproduce("receiptCid" => rcpt["cid"])
      expect(replay["matches"]).to be(true)
      expect(replay.dig("recomputed", "actabilityBand")).to eq("effect-eligible")
      expect {
        E.evaluate(
          "concept" => "https://ex/concept/alpha",
          "definitionRevision" => "https://ex/rev/alpha/1",
          "scope" => "https://ex/scope/pod",
          "namedUse" => "effect",
          "operationRevision" => "https://ex/op/1",
          "contractDigest" => "sha256:contract1",
          "policyRevision" => "https://ex/pol/1"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.definition-contested")
      }
    end

    it "P11.4 SemanticDispute opens the dimension; DisputeResolution resolves it" do
      concept!
      revision!(lifecycle: "active")
      S.put_attestation!(
        "cid" => "https://ex/att/1", "@type" => "SemanticAttestation",
        "definitionRevision" => "https://ex/rev/alpha/1", "signer" => "https://ex/actor",
        "authorityRef" => "https://ex/p6/1", "evidenceRef" => "https://ex/ev/1",
        "scope" => "https://ex/scope/pod", "agreement" => "local",
        "attestedAt" => "2026-08-20T00:00:00Z"
      )
      S.put_binding!(
        "cid" => "https://ex/bind/1", "@type" => "OperationBinding",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "operationRevision" => "https://ex/op/1",
        "contractDigest" => "sha256:contract1",
        "shapeDigest" => "sha256:shape1",
        "binding" => "verified"
      )
      disp = S.put_dispute!(
        "cid" => "https://ex/disp/1", "@type" => "SemanticDispute",
        "target" => "https://ex/rev/alpha/1",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "concept" => "https://ex/concept/alpha",
        "scope" => "https://ex/scope/pod",
        "raiser" => "https://ex/actor/challenger",
        "claim" => "contested",
        "evidenceRef" => "https://ex/p7/1"
      )
      expect(S.latest_dispute("https://ex/concept/alpha", "https://ex/rev/alpha/1", seq: S.sequence)).to eq("open")
      expect {
        E.evaluate(
          "concept" => "https://ex/concept/alpha",
          "definitionRevision" => "https://ex/rev/alpha/1",
          "scope" => "https://ex/scope/pod",
          "namedUse" => "effect",
          "operationRevision" => "https://ex/op/1",
          "contractDigest" => "sha256:contract1",
          "policyRevision" => "https://ex/pol/1"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.definition-contested")
      }

      res = S.put_resolution!(
        "cid" => "https://ex/res/1", "@type" => "DisputeResolution",
        "dispute" => disp["cid"],
        "resolver" => "https://ex/actor/resolver",
        "scope" => "https://ex/scope/pod",
        "authorityRef" => "https://ex/p6/resolver",
        "disposition" => "dismiss"
      )
      expect(res["resolver"]).to eq("https://ex/actor/resolver")
      expect(res["authorityRef"]).to eq("https://ex/p6/resolver")
      expect(S.latest_dispute("https://ex/concept/alpha", "https://ex/rev/alpha/1", seq: S.sequence)).to eq("resolved")
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "effect",
        "operationRevision" => "https://ex/op/1",
        "contractDigest" => "sha256:contract1",
        "policyRevision" => "https://ex/pol/1"
      )
      expect(rcpt["actabilityBand"]).to eq("effect-eligible")
      expect(rcpt["dispute"]).to eq("resolved")

      unknown = C.validate(disp.except("sequence").merge("style" => "x"))
      expect(unknown.ok).to eq(false)
      expect(unknown.reason).to eq("MEANING_UNKNOWN_PREDICATE")
      expect(unknown.because["unknown_predicates"]).to include("style")
    end

    it "6. unknown property refuses policy-indeterminate" do
      expect {
        E.evaluate("concept" => "https://ex/c", "definitionRevision" => "https://ex/r", "extra" => true)
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.policy-indeterminate")
        expect(e.because["unknown_predicates"]).to include("extra")
      }
    end
  end

  describe "P11.5 StewardshipTranslation / TranslationReview" do
    def translation!(overrides = {})
      S.put_translation!({
        "cid" => "https://ex/tr/1", "@type" => "StewardshipTranslation",
        "refersTo" => "https://ex/concept/alpha",
        "groundedIn" => "https://ex/rev/alpha/1",
        "audience" => "https://ex/aud/stewards",
        "scope" => "https://ex/scope/pod",
        "author" => "https://ex/actor/author",
        "rendering" => "Alpha is a thing, for stewards"
      }.merge(overrides))
    end

    it "refuses a translation missing refersTo or groundedIn" do
      rec = {
        "@type" => "StewardshipTranslation", "cid" => "https://ex/tr/x",
        "audience" => "https://ex/aud", "scope" => "https://ex/s",
        "author" => "https://ex/actor", "rendering" => "x",
        "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      }
      r = C.validate(rec)
      expect(r.ok).to eq(false)
      expect(r.reason).to eq("MEANING_ENVELOPE_INVALID")
      expect(r.because["missing"]).to include("refersTo", "groundedIn")
    end

    it "appends a translation that does not move any stored dimension or band" do
      concept!
      revision!(lifecycle: "active")
      tr = translation!
      expect(tr["refersTo"]).to eq("https://ex/concept/alpha")
      expect(tr["groundedIn"]).to eq("https://ex/rev/alpha/1")
      expect(tr).not_to have_key("actabilityBand")
      expect(tr).not_to have_key("definitionLifecycle")
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expect(rcpt["actabilityBand"]).to eq("explorable")
    end

    it "review is attributable (reviewer + P6 authorityRef) and closed" do
      concept!
      revision!(lifecycle: "active")
      translation!
      rv = S.put_review!(
        "cid" => "https://ex/rv/1", "@type" => "TranslationReview",
        "translation" => "https://ex/tr/1",
        "reviewer" => "https://ex/actor/reviewer",
        "scope" => "https://ex/scope/pod",
        "authorityRef" => "https://ex/p6/reviewer",
        "outcome" => "approved"
      )
      expect(rv["reviewer"]).to eq("https://ex/actor/reviewer")
      expect(rv["authorityRef"]).to eq("https://ex/p6/reviewer")
      expect(rv["outcome"]).to eq("approved")

      missing = C.validate(
        "@type" => "TranslationReview", "cid" => "https://ex/rv/x",
        "translation" => "https://ex/tr/1", "scope" => "https://ex/s",
        "outcome" => "approved", "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      )
      expect(missing.ok).to eq(false)
      expect(missing.reason).to eq("MEANING_ENVELOPE_INVALID")
      expect(missing.because["missing"]).to include("reviewer", "authorityRef")

      bad_out = C.validate(
        "@type" => "TranslationReview", "cid" => "https://ex/rv/x",
        "translation" => "https://ex/tr/1", "reviewer" => "https://ex/actor",
        "scope" => "https://ex/s", "authorityRef" => "https://ex/p6",
        "outcome" => "lgtm", "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      )
      expect(bad_out.ok).to eq(false)
      expect(bad_out.reason).to eq("MEANING_ENUM_INVALID")
      expect(bad_out.because["allowed"]).to eq(V::REVIEW_OUTCOMES)
    end

    it "withdrawn grounding refuses meaning.translation-grounding-insufficient" do
      concept!
      revision!(lifecycle: "withdrawn")
      expect {
        translation!
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.translation-grounding-insufficient")
        expect(e.because["translation"]).to eq("https://ex/tr/1")
        expect(e.because["concept"]).to eq("https://ex/concept/alpha")
        expect(e.because["groundedIn"]).to eq("https://ex/rev/alpha/1")
        expect(e.because["scope"]).to eq("https://ex/scope/pod")
        expect(e.because["definitionLifecycle"]).to eq("withdrawn")
      }
    end

    it "superseded grounding refuses on create and on review" do
      concept!
      revision!(lifecycle: "active")
      tr = translation!
      revision!(lifecycle: "active", cid: "https://ex/rev/alpha/2")
      expect {
        S.put_translation!(
          "cid" => "https://ex/tr/stale", "@type" => "StewardshipTranslation",
          "refersTo" => "https://ex/concept/alpha",
          "groundedIn" => "https://ex/rev/alpha/1",
          "audience" => "https://ex/aud/stewards",
          "scope" => "https://ex/scope/pod",
          "author" => "https://ex/actor/author",
          "rendering" => "stale"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.translation-grounding-insufficient")
        expect(e.because["supersededBy"]).to eq("https://ex/rev/alpha/2")
        expect(e.because["concept"]).to eq("https://ex/concept/alpha")
        expect(e.because["groundedIn"]).to eq("https://ex/rev/alpha/1")
        expect(e.because["scope"]).to eq("https://ex/scope/pod")
      }
      expect {
        S.put_review!(
          "cid" => "https://ex/rv/stale", "@type" => "TranslationReview",
          "translation" => tr["cid"],
          "reviewer" => "https://ex/actor/reviewer",
          "scope" => "https://ex/scope/pod",
          "authorityRef" => "https://ex/p6/reviewer",
          "outcome" => "approved"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.translation-grounding-insufficient")
        expect(e.because["translation"]).to eq(tr["cid"])
        expect(e.because["concept"]).to eq("https://ex/concept/alpha")
        expect(e.because["groundedIn"]).to eq("https://ex/rev/alpha/1")
        expect(e.because["scope"]).to eq("https://ex/scope/pod")
      }
    end
  end
end
