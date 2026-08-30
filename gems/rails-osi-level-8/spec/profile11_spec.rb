# frozen_string_literal: true

require "spec_helper"
require "pathname"
require "digest"

RSpec.describe RailsOsiLevel8::Profile11 do
  V = RailsOsiLevel8::Profile11::Vocabulary
  C = RailsOsiLevel8::Profile11::Contract
  S = RailsOsiLevel8::Profile11::Store
  E = RailsOsiLevel8::Profile11::Evaluator

  before do
    RailsOsiLevel8.configure do |c|
      c.profile_catalog = RailsOsiLevel8::ProfileCatalog.default
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

  def artifact_for(text)
    value = Digest::SHA256.hexdigest(text)
    {
      "artifactIri" => "https://ex/artifact/#{value[0, 12]}",
      "artifactKind" => "definition",
      "contentDigest" => { "algorithm" => "sha256", "value" => value },
      "mediaType" => "text/plain"
    }
  end

  def align_local!(concept: "https://ex/concept/alpha", revision: "https://ex/rev/alpha/1")
    S.put_alignment!(
      "cid" => "https://ex/align/#{revision.split('/').last}",
      "@type" => "SemanticAlignmentAssertion",
      "subject" => concept,
      "alignsWith" => concept,
      "participant" => "https://ex/actor",
      "scope" => "https://ex/scope/pod",
      "mappingArtifact" => "https://ex/map/1",
      "evidenceRef" => "https://ex/ev/1",
      "proofCoverage" => ["https://ex/actor"],
      "concept" => concept,
      "definitionRevision" => revision
    )
  end

  def revision!(lifecycle:, formalization: "structured", cid: "https://ex/rev/alpha/1", text: "Alpha is a thing")
    S.put_revision!(
      "cid" => cid,
      "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha",
      "normativeArtifact" => artifact_for(text),
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
        "StewardshipTranslation", "TranslationReview",
        "SemanticAlignmentAssertion", "FederationAgreement",
        "SemanticVerificationEvidence"
      )
      expect(d["record_types"]).to eq(V::RECORD_TYPES)
      expect(d["derived_bands"]).to eq(V::BANDS)
      expect(File).to exist(d.dig("shape_bundle", "absolute_path"))
    end

    it "validates each of the six record types and refuses unknown keys" do
      samples = {
        "Concept" => { "cid" => "https://ex/c", "label" => "L", "scope" => "https://ex/s" },
        "DefinitionRevision" => {
          "cid" => "https://ex/r", "concept" => "https://ex/c",
          "normativeArtifact" => {
            "artifactIri" => "https://ex/art/1",
            "contentDigest" => { "algorithm" => "sha256", "value" => "aa" * 32 }
          },
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
        },
        "SemanticAlignmentAssertion" => {
          "cid" => "https://ex/al", "subject" => "https://ex/c", "alignsWith" => "https://ex/c2",
          "participant" => "https://ex/actor", "scope" => "https://ex/s",
          "mappingArtifact" => "https://ex/map", "evidenceRef" => "https://ex/ev",
          "proofCoverage" => ["https://ex/actor"]
        },
        "FederationAgreement" => {
          "cid" => "https://ex/fed", "subject" => "https://ex/c", "participant" => "https://ex/actor",
          "scope" => "https://ex/s", "mappingArtifact" => "https://ex/map",
          "evidenceRef" => "https://ex/ev", "authorityRef" => "https://ex/p6",
          "proofCoverage" => ["https://ex/actor"]
        },
        "SemanticVerificationEvidence" => {
          "cid" => "https://ex/ve", "targetArtifactRevision" => "https://ex/r",
          "verificationKind" => "ontology-consistency", "verifier" => "https://ex/actor",
          "importClosureDigest" => "sha256:aa", "inputSnapshotDigest" => "sha256:bb",
          "result" => "passing", "finding" => "https://ex/finding/1",
          "producedAt" => "2026-08-20T00:00:00Z", "signedBy" => "https://ex/actor"
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
        "normativeArtifact" => {
          "artifactIri" => "https://ex/art/1",
          "contentDigest" => { "algorithm" => "sha256", "value" => "aa" * 32 }
        },
        "scope" => "https://ex/s", "definitionLifecycle" => "published",
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
      align_local!
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
      align_local!
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
      align_local!
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
      align_local!
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
      align_local!
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

  describe "P11.6 content by reference" do
    it "refuses embedded content (unknown predicate names content)" do
      r = C.validate(
        "@type" => "DefinitionRevision", "cid" => "https://ex/r",
        "concept" => "https://ex/c", "content" => "held here",
        "scope" => "https://ex/s", "definitionLifecycle" => "candidate",
        "formalization" => "structured", "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      )
      expect(r.ok).to eq(false)
      expect(r.reason).to eq("MEANING_UNKNOWN_PREDICATE")
      expect(r.because["unknown_predicates"]).to include("content")
    end

    it "refuses a revision without normativeArtifact" do
      r = C.validate(
        "@type" => "DefinitionRevision", "cid" => "https://ex/r",
        "concept" => "https://ex/c", "scope" => "https://ex/s",
        "definitionLifecycle" => "candidate", "formalization" => "structured",
        "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      )
      expect(r.ok).to eq(false)
      expect(r.reason).to eq("MEANING_ENVELOPE_INVALID")
      expect(r.because["missing"]).to include("normativeArtifact")
    end

    it "pins a digest and evaluates without holding content" do
      concept!
      rec = revision!(lifecycle: "candidate")
      expect(rec).not_to have_key("content")
      expect(rec.dig("normativeArtifact", "contentDigest", "algorithm")).to eq("sha256")
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expect(rcpt["actabilityBand"]).to eq("explorable")
    end

    it "P11.7 derives agreement from objects, not attestation.agreement" do
      concept!
      revision!(lifecycle: "active")
      S.put_attestation!(
        "cid" => "https://ex/att/1", "@type" => "SemanticAttestation",
        "definitionRevision" => "https://ex/rev/alpha/1", "signer" => "https://ex/actor",
        "authorityRef" => "https://ex/p6/1", "evidenceRef" => "https://ex/ev/1",
        "scope" => "https://ex/scope/pod", "agreement" => "federated",
        "attestedAt" => "2026-08-20T00:00:00Z"
      )
      none = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expect(none["dimensions"]["agreement"]).to eq("none")

      al = S.put_alignment!(
        "cid" => "https://ex/align/1", "@type" => "SemanticAlignmentAssertion",
        "subject" => "https://ex/concept/alpha",
        "alignsWith" => "https://ex/concept/global-revenue",
        "participant" => "https://ex/actor/finance",
        "scope" => "https://ex/scope/pod",
        "mappingArtifact" => "https://ex/map/1",
        "evidenceRef" => "https://ex/p5/1",
        "proofCoverage" => ["https://ex/actor/finance"],
        "concept" => "https://ex/concept/alpha"
      )
      expect(al["mappingArtifact"]).to eq("https://ex/map/1")
      local = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expect(local["dimensions"]["agreement"]).to eq("local")

      fed = S.put_federation!(
        "cid" => "https://ex/fed/1", "@type" => "FederationAgreement",
        "subject" => "https://ex/concept/alpha",
        "participant" => "https://ex/actor/finance",
        "scope" => "https://ex/scope/pod",
        "mappingArtifact" => "https://ex/map/fed",
        "evidenceRef" => "https://ex/p5/fed",
        "authorityRef" => "https://ex/p6/fed",
        "proofCoverage" => ["https://ex/actor/finance"],
        "alignmentRef" => al["cid"]
      )
      expect(fed["authorityRef"]).to eq("https://ex/p6/fed")
      federated = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expect(federated["dimensions"]["agreement"]).to eq("federated")

      missing = C.validate(
        "@type" => "FederationAgreement", "cid" => "https://ex/fed/x",
        "subject" => "https://ex/c", "participant" => "https://ex/actor",
        "scope" => "https://ex/s", "mappingArtifact" => "https://ex/map",
        "evidenceRef" => "https://ex/ev", "proofCoverage" => ["https://ex/actor"],
        "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      )
      expect(missing.ok).to eq(false)
      expect(missing.reason).to eq("MEANING_ENVELOPE_INVALID")
      expect(missing.because["missing"]).to include("authorityRef")
    end

    it "P11.11 EligibilityExplanation is request-time only and is not persisted" do
      d = C.describe
      expect(d["projections"]).to include("EligibilityExplanation")
      expect(d["record_types"]).not_to include("EligibilityExplanation")

      concept!
      revision!(lifecycle: "candidate")
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expl = rcpt["eligibilityExplanation"]
      expect(expl["@type"]).to eq("EligibilityExplanation")
      expect(expl).not_to have_key("actabilityBand")
      expl["criteria"].each do |c|
        expect(c.keys - %w[criterion result ref]).to eq([])
        expect(%w[passing failing]).to include(c["result"])
      end
      stored = S.receipt(rcpt["cid"])
      expect(stored).not_to have_key("eligibilityExplanation")
      expect(stored["actabilityBand"]).to eq("explorable")

      banded = C.validate(
        "@type" => "EligibilityExplanation", "cid" => "https://ex/ex/1",
        "actabilityBand" => "effect-eligible",
        "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      )
      expect(banded.ok).to eq(false)
      expect(banded.reason).to eq("MEANING_BAND_FORBIDDEN")

      expect {
        S.put_receipt!(
          "@type" => "EligibilityExplanation",
          "criteria" => [{ "criterion" => "x", "result" => "passing" }]
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.projection-not-persistable")
      }
    end

    it "P11.10 bilateral mapping without complete proofCoverage is not federated" do
      concept!
      revision!(lifecycle: "active")
      align_local!
      nocov = C.validate(
        "@type" => "FederationAgreement", "cid" => "https://ex/fed/x",
        "subject" => "https://ex/c", "participant" => "https://ex/actor",
        "scope" => "https://ex/s", "mappingArtifact" => "https://ex/map",
        "evidenceRef" => "https://ex/ev", "authorityRef" => "https://ex/p6",
        "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      )
      expect(nocov.ok).to eq(false)
      expect(nocov.reason).to eq("MEANING_ENVELOPE_INVALID")
      expect(nocov.because["missing"]).to include("proofCoverage")

      S.put_federation!(
        "cid" => "https://ex/fed/bilateral", "@type" => "FederationAgreement",
        "subject" => "https://ex/concept/alpha",
        "participant" => ["https://ex/actor/finance", "https://ex/actor/marketing"],
        "scope" => "https://ex/scope/pod",
        "mappingArtifact" => "https://ex/map/bilateral",
        "evidenceRef" => "https://ex/ev/bilateral",
        "authorityRef" => "https://ex/p6/bilateral",
        "proofCoverage" => ["https://ex/actor/finance"]
      )
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expect(rcpt["dimensions"]["agreement"]).to eq("local")
    end

    it "P11.8 testable requires passing ontology-consistency evidence" do
      concept!
      revision!(lifecycle: "active", formalization: "testable")
      expect {
        E.evaluate(
          "concept" => "https://ex/concept/alpha",
          "definitionRevision" => "https://ex/rev/alpha/1",
          "scope" => "https://ex/scope/pod",
          "namedUse" => "explore"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.verification-missing")
        expect(e.because["revision"]).to eq("https://ex/rev/alpha/1")
        expect(e.because["verificationKind"]).to eq("ontology-consistency")
        expect(e.because["scope"]).to eq("https://ex/scope/pod")
      }

      S.put_verification!(
        "cid" => "https://ex/ve/fail", "@type" => "SemanticVerificationEvidence",
        "targetArtifactRevision" => "https://ex/rev/alpha/1",
        "verificationKind" => "ontology-consistency",
        "verifier" => "https://ex/actor/verifier",
        "importClosureDigest" => "sha256:aa",
        "inputSnapshotDigest" => "sha256:bb",
        "result" => "failing",
        "finding" => "https://ex/finding/fail",
        "producedAt" => "2026-08-20T00:00:00Z",
        "signedBy" => "https://ex/actor/signer",
        "scope" => "https://ex/scope/pod"
      )
      expect {
        E.evaluate(
          "concept" => "https://ex/concept/alpha",
          "definitionRevision" => "https://ex/rev/alpha/1",
          "scope" => "https://ex/scope/pod",
          "namedUse" => "explore"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.verification-failed")
        expect(e.because["result"]).to eq("failing")
        expect(e.because["finding"]).to eq("https://ex/finding/fail")
        expect(e.because["revision"]).to eq("https://ex/rev/alpha/1")
      }

      S.put_verification!(
        "cid" => "https://ex/ve/pass", "@type" => "SemanticVerificationEvidence",
        "targetArtifactRevision" => "https://ex/rev/alpha/1",
        "verificationKind" => "ontology-consistency",
        "verifier" => "https://ex/actor/verifier",
        "importClosureDigest" => "sha256:aa",
        "inputSnapshotDigest" => "sha256:bb",
        "result" => "passing",
        "finding" => "https://ex/finding/pass",
        "producedAt" => "2026-08-20T00:01:00Z",
        "signedBy" => "https://ex/actor/signer",
        "scope" => "https://ex/scope/pod"
      )
      rcpt = E.evaluate(
        "concept" => "https://ex/concept/alpha",
        "definitionRevision" => "https://ex/rev/alpha/1",
        "scope" => "https://ex/scope/pod",
        "namedUse" => "explore"
      )
      expect(rcpt["dimensions"]["formalization"]).to eq("testable")
    end

    it "P11.9 rejects an invalid result value and requires finding" do
      rec = {
        "@type" => "SemanticVerificationEvidence", "cid" => "https://ex/ve/bad-result",
        "targetArtifactRevision" => "https://ex/r",
        "verificationKind" => "ontology-consistency", "verifier" => "https://ex/actor",
        "importClosureDigest" => "sha256:aa", "inputSnapshotDigest" => "sha256:bb",
        "result" => "pass", "finding" => "https://ex/finding/1",
        "producedAt" => "2026-08-20T00:00:00Z", "signedBy" => "https://ex/actor",
        "profileId" => V::PROFILE_ID, "ledgerPlacement" => "canonical"
      }
      r = C.validate(rec)
      expect(r.ok).to eq(false)
      expect(r.reason).to eq("MEANING_ENUM_INVALID")
      expect(r.because["value"]).to eq("pass")
      expect(r.because["allowed"]).to eq(%w[passing failing])

      missing = C.validate(rec.merge("result" => "passing").reject { |k, _| k == "finding" })
      expect(missing.ok).to eq(false)
      expect(missing.reason).to eq("MEANING_ENVELOPE_INVALID")
      expect(missing.because["missing"]).to include("finding")
    end

    it "retrievalPolicy=local without stored bytes refuses meaning.artifact-missing" do
      concept!
      expect {
        S.put_revision!(
          "cid" => "https://ex/rev/missing",
          "@type" => "DefinitionRevision",
          "concept" => "https://ex/concept/alpha",
          "normativeArtifact" => {
            "artifactIri" => "https://ex/art/gone",
            "contentDigest" => { "algorithm" => "sha256", "value" => "ab" * 32 },
            "retrievalPolicy" => "local"
          },
          "scope" => "https://ex/scope/pod",
          "definitionLifecycle" => "candidate",
          "formalization" => "structured"
        )
      }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason).to eq("meaning.artifact-missing")
        expect(e.because["revision"]).to eq("https://ex/rev/missing")
        expect(e.because["artifactIri"]).to eq("https://ex/art/gone")
        expect(e.because["digest"]).to eq("ab" * 32)
        expect(e.because["scope"]).to eq("https://ex/scope/pod")
      }
    end
  end
end
