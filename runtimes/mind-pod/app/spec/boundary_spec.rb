require "spec_helper"
require "json"

RSpec.describe "CPCP boundary (BACK /_cpcp seam)" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    JSON.parse(last_response.body)
  end

  it "exposes liveness + declared operations at /_cpcp/up" do
    get "/_cpcp/up"
    expect(last_response.status).to eq(200)
    j = JSON.parse(last_response.body)
    expect(j["ok"]).to be(true)
    expect(j["operations"]).to include(
      "note.create", "note.list", "reconciliation.latest",
      "l8.context.list", "l8.cyborg_channel.list", "l8.reference.list", "l8.routing.list",
      "l8.operation.journal", "l8.execution.receipt.list",
      "l8.biography.get", "l8.provenance.list", "l8.authorization.list",
      "l8.observation.list", "l8.outcome.list", "l8.learning.list", "l8.drift.list",
      "l8.profile_evidence.list",
      "l8.observation.record", "l8.outcome.record", "l8.execution.complete", "l8.learning.record",
      "ux.profile.describe", "ux.contract.check", "ux.acia.validate", "ux.render",
      "ux.journey.list", "ux.journey.get", "ux.flow.get", "ux.page.get",
      "ux.token.get", "ux.token.set", "ux.acia.mutate.propose", "ux.interaction.record"
    )
  end

  it "P9.2 ux.render returns HTML+receipt; unresolved token => RefusalNotice" do
    doc = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
    ok = rpc("ux.render", {
      "bundle" => {
        "aciaDocument" => doc,
        "tokenSet" => RailsOsiLevel8::Profile9::Renderer.default_token_set,
        "correlationId" => "c-test",
        "receiptSeed" => "s-test"
      }
    })
    expect(ok["ok"]).to be(true)
    expect(ok.dig("result", "html")).to include("data-ux-acia-digest=")
    expect(ok.dig("result", "receipt", "receiptKind")).to eq("ux:RenderReceipt")

    broken = Marshal.load(Marshal.dump(doc))
    broken["root"]["slt"]["tokenSignature"] = { "setRef" => "tokens:nope" }
    bad = rpc("ux.render", { "bundle" => { "aciaDocument" => broken, "tokenSet" => RailsOsiLevel8::Profile9::Renderer.default_token_set } })
    expect(bad["ok"]).to be(true) # CPCP envelope ok; render payload ok:false
    expect(bad.dig("result", "ok")).to be(false)
    expect(bad.dig("result", "html")).to include("RefusalNotice")
  end


  it "P9.1 ux.acia.validate accepts 8-panel ACIA and refuses HTML/style props" do
    good = RailsOsiLevel8::Profile9::Acia.eight_panel_fixture
    r = rpc("ux.acia.validate", { "document" => good })
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "conforms")).to be(true)
    expect(r.dig("result", "digest")).to match(/\Asha256:[0-9a-f]{64}\z/)

    bad = Marshal.load(Marshal.dump(good))
    bad["root"]["props"]["valueJson"]["html"] = "<div/>"
    refused = rpc("ux.acia.validate", { "document" => bad })
    expect(refused["ok"]).to be(false)
    expect(refused.dig("error", "because", "forbidden_props")).to include("html")
  end


  it "P9.0 ux.profile.describe returns Profile-9 contract introspection" do
    r = rpc("ux.profile.describe")
    expect(r["ok"]).to be(true)
    d = r["result"]
    expect(d["profile_id"]).to eq("osi-level-8/profile-9")
    expect(d["component_kinds"]).to include("DecisionForm", "RefusalNotice", "ScopeTrail", "ReferentBridge")
    expect(d["component_kinds"].size).to eq(19)
    expect(d["operations"].map { |o| o["name"] }).to include("ux.page.get", "ux.interaction.record")
    expect(d.dig("shape_bundle", "digest")).to match(/\Asha256:[0-9a-f]{64}\z/)
  end

  it "P9.3 page.get feeds ux.render with a stable receipt cid" do
    page = rpc("ux.page.get", {
      "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
      "correlationId" => "corr-p93",
      "receiptSeed" => "seed-p93"
    })
    expect(page["ok"]).to be(true)
    expect(page.dig("result", "@type")).to eq("ux:PageRenderBundle")

    a = rpc("ux.render", { "bundle" => page["result"] })
    b = rpc("ux.render", { "bundle" => page["result"] })
    expect(a["ok"]).to be(true)
    expect(a.dig("result", "ok")).to be(true)
    expect(a.dig("result", "receipt", "cid")).to match(/\Acid:sha256:[0-9a-f]{64}\z/)
    expect(a.dig("result", "receipt", "cid")).to eq(b.dig("result", "receipt", "cid"))
  end

  it "P9.3 unknown journey/page refs refuse; unknown request keys refuse" do
    missing = rpc("ux.journey.get", { "journeyCid" => "cid:journey:missing" })
    expect(missing["ok"]).to be(false)
    expect(missing.dig("error", "reason")).to eq("UX_LINEAGE_UNRESOLVED")

    extra = rpc("ux.flow.get", { "flowCid" => RailsOsiLevel8::Profile9::Graph::FLOW_CID, "innerHTML" => "<x/>" })
    expect(extra["ok"]).to be(false)
    expect(extra.dig("error", "reason")).to eq("UX_UNKNOWN_PREDICATE")
  end

  it "P9.4 token.set contrast fail does not activate; clean successor does" do
    RailsOsiLevel8::Profile9::Graph.reset!
    pred = rpc("ux.token.get")
    expect(pred["ok"]).to be(true)
    cid = pred.dig("result", "cid")
    digest = pred.dig("result", "digest")

    bad = rpc("ux.token.set", {
      "predecessorCid" => cid,
      "predecessorDigest" => digest,
      "tokenDelta" => { "tokens:ghis@1" => { "colors.fg" => "#eee" } }
    }, opid: "p94-token-bad-#{SecureRandom.hex(3)}")
    expect(bad["ok"]).to be(false)
    expect(bad.dig("error", "reason")).to eq("UX_DESIGN_GROUNDING_FAILED")
    expect(rpc("ux.token.get").dig("result", "cid")).to eq(cid)

    ok = rpc("ux.token.set", {
      "predecessorCid" => cid,
      "predecessorDigest" => digest,
      "tokenDelta" => { "tokens:ghis@1" => { "colors.fg" => "#000000" } }
    }, opid: "p94-token-ok-#{SecureRandom.hex(3)}")
    expect(ok["ok"]).to be(true)
    expect(ok.dig("result", "accepted")).to be(true)
    expect(ok.dig("result", "digest")).not_to eq(digest)
  end

  it "P9.6 Graph seed persists to append-only ux tables" do
    RailsOsiLevel8::Profile9::Graph.reset!
    cid = RailsOsiLevel8::Profile9::Graph::JOURNEY_CID
    expect(RailsOsiLevel8::Profile9::Graph.journey(cid)).to be_a(Hash)
    row = RailsOsiLevel8::UxJourney.find_by(cid: cid)
    expect(row).to be_present
    expect(row.envelope_json["cid"]).to eq(cid)
    expect {
      ActiveRecord::Base.connection.execute(
        "UPDATE osi_l8_ux_journeys SET payload_digest='tamper' WHERE cid='#{cid}'"
      )
    }.to raise_error(ActiveRecord::StatementInvalid)
    expect {
      ActiveRecord::Base.connection.execute(
        "DELETE FROM osi_l8_ux_journeys WHERE cid='#{cid}'"
      )
    }.to raise_error(ActiveRecord::StatementInvalid)
  end

  it "P9.4 page.get → render → interaction.record; replay refused" do
    RailsOsiLevel8::Profile9::Graph.reset!
    page = rpc("ux.page.get", {
      "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID,
      "correlationId" => "corr-p94",
      "receiptSeed" => "seed-p94"
    })
    rendered = rpc("ux.render", { "bundle" => page["result"] })
    receipt = rendered.dig("result", "receipt")
    presented = rpc("ux.interaction.record", {
      "eventKind" => "context_presented",
      "receipt" => receipt,
      "receiptCid" => receipt["cid"],
      "aciaDocumentDigest" => receipt["aciaDigest"],
      "tokenSetDigest" => receipt["tokenDigest"],
      "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID
    }, opid: "p94-ix-#{SecureRandom.hex(3)}")
    expect(presented["ok"]).to be(true)
    expect(presented.dig("result", "eventKind")).to eq("context_presented")

    replay = rpc("ux.interaction.record", {
      "eventKind" => "context_presented",
      "receipt" => receipt,
      "receiptCid" => receipt["cid"],
      "aciaDocumentDigest" => receipt["aciaDigest"],
      "tokenSetDigest" => receipt["tokenDigest"],
      "pageCid" => RailsOsiLevel8::Profile9::Graph::PAGE_CID
    }, opid: "p94-ix-replay-#{SecureRandom.hex(3)}")
    expect(replay["ok"]).to be(false)
    expect(replay.dig("error", "because", "replay")).to be(true)
  end

  it "P9.3 ux.journey.list is a collection for the fixture actor" do
    r = rpc("ux.journey.list", { "actorCid" => RailsOsiLevel8::Profile9::Graph::ACTOR_CID })
    expect(r["ok"]).to be(true)
    cids = (r.dig("result", "@graph") || []).map { |j| j["cid"] }
    expect(cids).to include(RailsOsiLevel8::Profile9::Graph::JOURNEY_CID)
  end

  it "P9.0 ux.contract.check refuses unknown predicates (never-raise)" do
    bad = rpc("ux.contract.check", { "graph" => { "cid" => "cid:x", "arbitraryHtml" => "<div/>" } })
    expect(bad["ok"]).to be(false)
    expect(bad.dig("error", "reason")).to eq("UX_UNKNOWN_PREDICATE")
    expect(bad.dig("error", "because", "unknown_predicates")).to include("arbitraryHtml")

    good = rpc("ux.contract.check", {
      "graph" => { "cid" => "cid:ok", "profileId" => "osi-level-8/profile-9", "componentKind" => "ContextBanner" }
    })
    expect(good["ok"]).to be(true)
    expect(good.dig("result", "conforms")).to be(true)
  end


  it "PUSH note.create then PULL note.list (sole-writer seam)" do
    before = Note.count
    r = rpc("note.create", { "title" => "via seam", "body" => "hello" }, opid: "op-#{before}-#{SecureRandom.hex(3)}")
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "title")).to eq("via seam")
    list = rpc("note.list")
    expect(list["ok"]).to be(true)
    titles = list.dig("result", "@graph").map { |n| n["title"] }
    expect(titles).to include("via seam")
    expect(Note.count).to eq(before + 1)
  end

  it "PUSH without operationId is refused (never-raise envelope)" do
    r = rpc("note.create", { "title" => "x", "body" => "y" })
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("operation_id_required")
  end

  it "unknown operation fails cleanly" do
    r = rpc("does.not.exist")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("unknown_operation")
  end

  it "shape-invalid note.create refuses via never-raise (no Note)" do
    before = Note.count
    r = rpc("note.create", { "title" => "", "body" => "x" }, opid: "op-shape-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("grounding_refused")
    expect(Note.count).to eq(before)
  end

  it "P4 idempotent replay makes no second Note and journals replay" do
    key = "idem-#{SecureRandom.hex(4)}"
    r1 = rpc("note.create", { "title" => "once", "body" => "a", "idempotencyKey" => key }, opid: "op-a-#{key}")
    expect(r1["ok"]).to be(true)
    count = Note.count
    r2 = rpc("note.create", { "title" => "once", "body" => "a", "idempotencyKey" => key }, opid: "op-b-#{key}")
    expect(r2["ok"]).to be(true)
    expect(Note.count).to eq(count)
    expect(r2.dig("result", "governance", "replayed") || r2.dig("result", "replayed")).to be_truthy
  end

  it "l8.* PULLs never emit private_local rows" do
    now = Time.now.utc
    RailsOsiLevel8::Context.create!(
      cid: "cid:sha256:private-test-#{SecureRandom.hex(4)}",
      profile_id: "osi-l8/p1/cyborg-channel@1",
      ledger_placement: "private_local",
      provenance_json: {},
      payload_digest: Digest::SHA256.hexdigest("private-#{now.to_f}"),
      recorded_at: now,
      subject_iri: "secret:subject",
      context_kind: "state",
      jsonld: { "secret" => true },
      shape_id: "test",
      shape_digest: "x",
      admitted_at: now
    )
    list = rpc("l8.context.list", { "limit" => 200 })
    expect(list["ok"]).to be(true)
    placements = (list.dig("result", "@graph") || []).map { |r| r["ledger_placement"] }
    expect(placements).not_to include("private_local")
  end

  it "P5 traces Note receipt back to request_cid and acting Cyborg" do
    opid = "op-p5-#{SecureRandom.hex(4)}"
    r = rpc("note.create", { "title" => "p5 trace", "body" => "chain", "callerIri" => "cyborg:front" }, opid: opid)
    expect(r["ok"]).to be(true)
    note_id = r.dig("result", "@id")
    request_cid = r.dig("result", "governance", "request_cid")
    receipt_cid = r.dig("result", "governance", "receipt_cid")

    bio = rpc("l8.biography.get", { "subject_iri" => "cyborg:front" })
    expect(bio["ok"]).to be(true)
    expect((bio.dig("result", "@graph") || []).any? { |e| e["event_kind"] == "declared" }).to be(true)

    edges = rpc("l8.provenance.list", { "limit" => 100 }).dig("result", "@graph") || []
    expect(edges.any? { |e| e["from_cid"] == note_id && e["predicate"] == "prov:wasDerivedFrom" && e["to_cid"] == request_cid }).to be(true)
    expect(edges.any? { |e| e["from_cid"] == receipt_cid && e["predicate"] == "prov:wasGeneratedBy" && e["to_cid"] == note_id }).to be(true)
    expect(edges.any? { |e| e["from_cid"] == note_id && e["predicate"] == "prov:wasAttributedTo" && e["to_iri"] == "cyborg:front" }).to be(true)
  end

  it "P6 deny prevents Note creation; PULL never emits evaluator detail" do
    before = Note.count
    r = rpc("note.create", { "title" => "DENY: secret", "body" => "nope", "callerIri" => "cyborg:front" },
            opid: "op-deny-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("authorization_denied")
    expect(Note.count).to eq(before)

    auth = rpc("l8.authorization.list", { "limit" => 50 })
    expect(auth["ok"]).to be(true)
    items = auth.dig("result", "@graph") || []
    deny = items.find { |i| i["decision"] == "deny" }
    expect(deny).to be_present
    expect(deny["policy_ref"]).to be_present
    expect(deny["evidence_digest"]).to be_present
    expect(deny.keys).not_to include("evaluator_detail_json")
    expect(JSON.generate(items)).not_to include("evaluator")
  end

  it "P2 reference-passing records a public reference without access_descriptor" do
    r = rpc("note.create", { "title" => "ref note", "body" => "x" }, opid: "op-ref-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(true)
    refs = rpc("l8.reference.list", { "limit" => 50 })
    expect(refs["ok"]).to be(true)
    items = refs.dig("result", "@graph") || []
    expect(items.size).to be >= 1
    expect(items.first.keys).not_to include("access_descriptor_json")
    expect(items.any? { |i| i["target_cid"] == r.dig("result", "@id") }).to be(true)
  end

  it "P3 routing records decision and does not overwrite on failed hop" do
    r = rpc("note.create", {
      "title" => "routed", "body" => "x",
      "routeKey" => "sy:demo", "routeHopFailure" => "true"
    }, opid: "op-route-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(true)
    routing = rpc("l8.routing.list", { "limit" => 50 })
    expect(routing["ok"]).to be(true)
    items = routing.dig("result", "@graph") || []
    decisions = items.select { |i| i["kind"] == "decision" && i["route_key"] == "sy:demo" }
    expect(decisions.size).to be >= 1
    decision = decisions.first
    hops = items.select { |i| i["kind"] == "hop" && i["routing_decision_cid"] == decision["cid"] }
    expect(hops.map { |h| h["hop_number"] }).to include(1, 2)
    expect(hops.any? { |h| h["hop_status"] == "failed" }).to be(true)
    # append-only: original decision row is not updated when hop 2 fails
    expect(decision["decision"]).to eq("routed")
  end

  it "P7 execution.complete is idempotent and yields observation+outcome" do
    create = rpc("note.create", { "title" => "p7", "body" => "y" }, opid: "op-p7-#{SecureRandom.hex(4)}")
    expect(create["ok"]).to be(true)
    req = create.dig("result", "governance", "request_cid")
    c1 = rpc("l8.execution.complete", { "operationRequestCid" => req, "idempotencyKey" => "complete:#{req}" },
             opid: "complete-a-#{SecureRandom.hex(3)}")
    expect(c1["ok"]).to be(true)
    c2 = rpc("l8.execution.complete", { "operationRequestCid" => req, "idempotencyKey" => "complete:#{req}" },
             opid: "complete-b-#{SecureRandom.hex(3)}")
    expect(c2["ok"]).to be(true)
    expect(c2.dig("result", "replayed")).to be(true)

    obs = rpc("l8.observation.list", { "limit" => 50 })
    outs = rpc("l8.outcome.list", { "limit" => 50 })
    expect(obs["ok"]).to be(true)
    expect(outs["ok"]).to be(true)
    expect((obs.dig("result", "@graph") || []).size).to be >= 1
    expect((outs.dig("result", "@graph") || []).size).to be >= 1
  end

  it "P8 learning records drift and refuses autonomous shape change" do
    r = rpc("l8.learning.record", {
      "eventKind" => "profile_change_accepted",
      "learningCycleId" => "cycle:test",
      "subjectCid" => "mind:pod",
      "proposal" => { "change" => "auto" },
      "decidedByIri" => "cyborg:operator"
    }, opid: "learn-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "autonomous_shape_change")).to eq(false)
    expect(r.dig("result", "status")).to eq("accepted")
    stored = RailsOsiLevel8::LearningEvent.find_by(cid: r.dig("result", "cid"))
    expect(stored.proposal_json["applied"]).to eq(false)
    expect(stored.proposal_json["reason"]).to eq("no_autonomous_shape_change")

    drift = rpc("l8.learning.record", {
      "eventKind" => "drift_detected",
      "learningCycleId" => "cycle:test",
      "severity" => "medium",
      "baselineRef" => "a",
      "observedRef" => "b",
      "subjectCid" => "mind:pod"
    }, opid: "drift-#{SecureRandom.hex(4)}")
    expect(drift["ok"]).to be(true)
    listed = rpc("l8.drift.list", { "limit" => 20 })
    expect(listed["ok"]).to be(true)
    expect((listed.dig("result", "@graph") || []).any? { |e| e["event_kind"] == "drift_detected" }).to be(true)
  end

  it "M8 fixtures seed learning narrative without new routes" do
    expect(RailsOsiLevel8::Fixtures.seed_demo_narrative!).to be(true)
    learn = rpc("l8.learning.list", { "learning_cycle_id" => "cycle:demo", "limit" => 20 })
    expect(learn["ok"]).to be(true)
    kinds = (learn.dig("result", "@graph") || []).map { |e| e["event_kind"] }
    expect(kinds).to include("drift_detected", "hypothesis_recorded")
  end
end
