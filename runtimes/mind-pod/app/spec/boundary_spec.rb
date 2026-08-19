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
      "l8.observation.record", "l8.outcome.record", "l8.execution.complete", "l8.learning.record"
    )
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
