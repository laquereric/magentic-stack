# frozen_string_literal: true

require "spec_helper"
require "json"

RSpec.describe "P11 Meaning CPCP" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    JSON.parse(last_response.body)
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

  before { RailsOsiLevel8::Profile11::Store.reset! }

  it "meaning.profile.describe is on the wire" do
    r = rpc("meaning.profile.describe")
    expect(last_response.status).to eq(200)
    expect(r["ok"]).to be(true)
    expect(r["jsonrpc"]).to eq("2.0")
    expect(r.dig("result", "profile_id")).to eq("osi-level-8/profile-11")
  end

  it "P11.3 seed persists append-only; evaluate via /_cpcp" do
    c = rpc("meaning.concept.put", {
      "cid" => "https://ex/concept/alpha", "@type" => "Concept",
      "label" => "Alpha", "scope" => "https://ex/scope/pod"
    }, opid: "p11-c-#{SecureRandom.hex(3)}")
    expect(c["ok"]).to be(true)
    expect(RailsOsiLevel8::MngConcept.find_by(cid: "https://ex/concept/alpha")).to be_present

    rev = rpc("meaning.revision.put", {
      "cid" => "https://ex/rev/alpha/1", "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha",
      "normativeArtifact" => artifact_for("Alpha"),
      "scope" => "https://ex/scope/pod", "definitionLifecycle" => "candidate",
      "formalization" => "structured"
    }, opid: "p11-r-#{SecureRandom.hex(3)}")
    expect(rev["ok"]).to be(true)
    expect(rev.dig("result", "content")).to be_nil

    held = rpc("meaning.revision.put", {
      "cid" => "https://ex/rev/held", "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha", "content" => "held here",
      "scope" => "https://ex/scope/pod", "definitionLifecycle" => "candidate",
      "formalization" => "structured"
    }, opid: "p11-held-#{SecureRandom.hex(3)}")
    expect(held["ok"]).to be(false)
    expect(held.dig("error", "reason")).to eq("MEANING_UNKNOWN_PREDICATE")
    expect(held.dig("error", "because", "unknown_predicates")).to include("content")

    ev = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "scope" => "https://ex/scope/pod",
      "namedUse" => "explore"
    }, opid: "p11-e-#{SecureRandom.hex(3)}")
    expect(ev["ok"]).to be(true)
    expect(ev.dig("result", "actabilityBand")).to eq("explorable")
    expect(ev.dig("result", "eligibilityExplanation", "@type")).to eq("EligibilityExplanation")
    expect(ev.dig("result", "eligibilityExplanation")).not_to have_key("actabilityBand")
    stored = RailsOsiLevel8::MngReceipt.find_by(cid: ev.dig("result", "cid"))
    expect(stored.envelope_json).not_to have_key("eligibilityExplanation") if stored

    disp = rpc("meaning.dispute.put", {
      "cid" => "https://ex/disp/1", "@type" => "SemanticDispute",
      "target" => "https://ex/rev/alpha/1",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "concept" => "https://ex/concept/alpha",
      "scope" => "https://ex/scope/pod",
      "raiser" => "https://ex/actor/challenger",
      "claim" => "contested",
      "evidenceRef" => "https://ex/p5/1"
    }, opid: "p11-d-#{SecureRandom.hex(3)}")
    expect(disp["ok"]).to be(true)
    expect(RailsOsiLevel8::MngSemanticDispute.find_by(cid: "https://ex/disp/1")).to be_present

    extra = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "style" => "nope"
    }, opid: "p11-bad-#{SecureRandom.hex(3)}")
    expect(extra["ok"]).to be(false)
    expect(extra.dig("error", "reason")).to eq("meaning.policy-indeterminate")

    expect {
      ActiveRecord::Base.connection.execute(
        "UPDATE osi_l8_mng_concepts SET payload_digest='tamper' WHERE cid='https://ex/concept/alpha'"
      )
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "P11.5 StewardshipTranslation requires both anchors; withdrawn grounding refuses" do
    rpc("meaning.concept.put", {
      "cid" => "https://ex/concept/alpha", "@type" => "Concept",
      "label" => "Alpha", "scope" => "https://ex/scope/pod"
    }, opid: "p11-c5-#{SecureRandom.hex(3)}")
    rpc("meaning.revision.put", {
      "cid" => "https://ex/rev/alpha/1", "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha",
      "normativeArtifact" => artifact_for("Alpha"),
      "scope" => "https://ex/scope/pod", "definitionLifecycle" => "active",
      "formalization" => "structured"
    }, opid: "p11-r5-#{SecureRandom.hex(3)}")

    missing = rpc("meaning.translation.put", {
      "@type" => "StewardshipTranslation", "cid" => "https://ex/tr/missing",
      "audience" => "https://ex/aud", "scope" => "https://ex/scope/pod",
      "author" => "https://ex/actor", "rendering" => "x"
    }, opid: "p11-tm-#{SecureRandom.hex(3)}")
    expect(missing["ok"]).to be(false)
    expect(missing.dig("error", "reason")).to eq("MEANING_ENVELOPE_INVALID")
    expect(missing.dig("error", "because", "missing")).to include("refersTo", "groundedIn")

    tr = rpc("meaning.translation.put", {
      "cid" => "https://ex/tr/1", "@type" => "StewardshipTranslation",
      "refersTo" => "https://ex/concept/alpha",
      "groundedIn" => "https://ex/rev/alpha/1",
      "audience" => "https://ex/aud/stewards",
      "scope" => "https://ex/scope/pod",
      "author" => "https://ex/actor/author",
      "rendering" => "Alpha, for stewards"
    }, opid: "p11-t-#{SecureRandom.hex(3)}")
    expect(tr["ok"]).to be(true), tr.inspect
    expect(RailsOsiLevel8::MngStewardshipTranslation.find_by(cid: "https://ex/tr/1")).to be_present

    rv = rpc("meaning.review.put", {
      "cid" => "https://ex/rv/1", "@type" => "TranslationReview",
      "translation" => "https://ex/tr/1",
      "reviewer" => "https://ex/actor/reviewer",
      "scope" => "https://ex/scope/pod",
      "authorityRef" => "https://ex/p6/reviewer",
      "outcome" => "approved"
    }, opid: "p11-rv-#{SecureRandom.hex(3)}")
    expect(rv["ok"]).to be(true)
    expect(RailsOsiLevel8::MngTranslationReview.find_by(cid: "https://ex/rv/1")).to be_present

    rpc("meaning.revision.put", {
      "cid" => "https://ex/rev/alpha/withdrawn", "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha",
      "normativeArtifact" => artifact_for("gone"),
      "scope" => "https://ex/scope/pod", "definitionLifecycle" => "withdrawn",
      "formalization" => "structured"
    }, opid: "p11-rw-#{SecureRandom.hex(3)}")
    withdrawn = rpc("meaning.translation.put", {
      "cid" => "https://ex/tr/w", "@type" => "StewardshipTranslation",
      "refersTo" => "https://ex/concept/alpha",
      "groundedIn" => "https://ex/rev/alpha/withdrawn",
      "audience" => "https://ex/aud/stewards",
      "scope" => "https://ex/scope/pod",
      "author" => "https://ex/actor/author",
      "rendering" => "gone"
    }, opid: "p11-tw-#{SecureRandom.hex(3)}")
    expect(withdrawn["ok"]).to be(false)
    expect(withdrawn.dig("error", "reason")).to eq("meaning.translation-grounding-insufficient")
    expect(withdrawn.dig("error", "because", "concept")).to eq("https://ex/concept/alpha")
    expect(withdrawn.dig("error", "because", "groundedIn")).to eq("https://ex/rev/alpha/withdrawn")
    expect(withdrawn.dig("error", "because", "scope")).to eq("https://ex/scope/pod")

    expect {
      ActiveRecord::Base.connection.execute(
        "UPDATE osi_l8_mng_stewardship_translations SET payload_digest='tamper' WHERE cid='https://ex/tr/1'"
      )
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "P11.7 alignment objects derive agreement; attestation.agreement is ignored" do
    rpc("meaning.concept.put", {
      "cid" => "https://ex/concept/alpha", "@type" => "Concept",
      "label" => "Alpha", "scope" => "https://ex/scope/pod"
    }, opid: "p117-c-#{SecureRandom.hex(3)}")
    rpc("meaning.revision.put", {
      "cid" => "https://ex/rev/alpha/1", "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha",
      "normativeArtifact" => artifact_for("Alpha"),
      "scope" => "https://ex/scope/pod", "definitionLifecycle" => "active",
      "formalization" => "structured"
    }, opid: "p117-r-#{SecureRandom.hex(3)}")
    rpc("meaning.attestation.put", {
      "cid" => "https://ex/att/1", "@type" => "SemanticAttestation",
      "definitionRevision" => "https://ex/rev/alpha/1", "signer" => "https://ex/actor",
      "authorityRef" => "https://ex/p6/1", "evidenceRef" => "https://ex/ev/1",
      "scope" => "https://ex/scope/pod", "agreement" => "federated",
      "attestedAt" => "2026-08-20T00:00:00Z"
    }, opid: "p117-a-#{SecureRandom.hex(3)}")
    none = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "scope" => "https://ex/scope/pod",
      "namedUse" => "explore"
    }, opid: "p117-e0-#{SecureRandom.hex(3)}")
    expect(none["ok"]).to be(true)
    expect(none.dig("result", "dimensions", "agreement")).to eq("none")

    al = rpc("meaning.alignment.put", {
      "cid" => "https://ex/align/1", "@type" => "SemanticAlignmentAssertion",
      "subject" => "https://ex/concept/alpha",
      "alignsWith" => "https://ex/concept/global",
      "participant" => "https://ex/actor",
      "scope" => "https://ex/scope/pod",
      "mappingArtifact" => "https://ex/map/1",
      "evidenceRef" => "https://ex/ev/1",
      "proofCoverage" => ["https://ex/actor"],
      "concept" => "https://ex/concept/alpha"
    }, opid: "p117-al-#{SecureRandom.hex(3)}")
    expect(al["ok"]).to be(true)
    expect(RailsOsiLevel8::MngAlignmentAssertion.find_by(cid: "https://ex/align/1")).to be_present
    local = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "scope" => "https://ex/scope/pod",
      "namedUse" => "explore"
    }, opid: "p117-e1-#{SecureRandom.hex(3)}")
    expect(local.dig("result", "dimensions", "agreement")).to eq("local")

    fed = rpc("meaning.federation.put", {
      "cid" => "https://ex/fed/1", "@type" => "FederationAgreement",
      "subject" => "https://ex/concept/alpha",
      "participant" => "https://ex/actor",
      "scope" => "https://ex/scope/pod",
      "mappingArtifact" => "https://ex/map/fed",
      "evidenceRef" => "https://ex/ev/fed",
      "authorityRef" => "https://ex/p6/fed",
      "proofCoverage" => ["https://ex/actor"]
    }, opid: "p117-f-#{SecureRandom.hex(3)}")
    expect(fed["ok"]).to be(true)
    expect(RailsOsiLevel8::MngFederationAgreement.find_by(cid: "https://ex/fed/1")).to be_present
    federated = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/1",
      "scope" => "https://ex/scope/pod",
      "namedUse" => "explore"
    }, opid: "p117-e2-#{SecureRandom.hex(3)}")
    expect(federated.dig("result", "dimensions", "agreement")).to eq("federated")
  end

  it "P11.8 testable without passing ontology-consistency refuses" do
    rpc("meaning.concept.put", {
      "cid" => "https://ex/concept/alpha", "@type" => "Concept",
      "label" => "Alpha", "scope" => "https://ex/scope/pod"
    }, opid: "p118-c-#{SecureRandom.hex(3)}")
    rpc("meaning.revision.put", {
      "cid" => "https://ex/rev/alpha/t", "@type" => "DefinitionRevision",
      "concept" => "https://ex/concept/alpha",
      "normativeArtifact" => artifact_for("Alpha"),
      "scope" => "https://ex/scope/pod", "definitionLifecycle" => "active",
      "formalization" => "testable"
    }, opid: "p118-r-#{SecureRandom.hex(3)}")
    missing = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/t",
      "scope" => "https://ex/scope/pod",
      "namedUse" => "explore"
    }, opid: "p118-e0-#{SecureRandom.hex(3)}")
    expect(missing["ok"]).to be(false)
    expect(missing.dig("error", "reason")).to eq("meaning.verification-missing")

    ve = rpc("meaning.verification.put", {
      "cid" => "https://ex/ve/1", "@type" => "SemanticVerificationEvidence",
      "targetArtifactRevision" => "https://ex/rev/alpha/t",
      "verificationKind" => "ontology-consistency",
      "verifier" => "https://ex/actor/verifier",
      "importClosureDigest" => "sha256:aa",
      "inputSnapshotDigest" => "sha256:bb",
      "result" => "passing",
      "finding" => "https://ex/finding/1",
      "producedAt" => "2026-08-20T00:00:00Z",
      "signedBy" => "https://ex/actor/signer"
    }, opid: "p118-v-#{SecureRandom.hex(3)}")
    expect(ve["ok"]).to be(true)
    expect(RailsOsiLevel8::MngVerificationEvidence.find_by(cid: "https://ex/ve/1")).to be_present
    ok = rpc("meaning.evaluate", {
      "concept" => "https://ex/concept/alpha",
      "definitionRevision" => "https://ex/rev/alpha/t",
      "scope" => "https://ex/scope/pod",
      "namedUse" => "explore"
    }, opid: "p118-e1-#{SecureRandom.hex(3)}")
    expect(ok["ok"]).to be(true)
    expect(ok.dig("result", "dimensions", "formalization")).to eq("testable")
  end
end
