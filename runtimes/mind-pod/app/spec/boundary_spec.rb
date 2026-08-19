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
      "l8.context.list", "l8.cyborg_channel.list",
      "l8.operation.journal", "l8.execution.receipt.list",
      "l8.biography.get", "l8.provenance.list"
    )
  end

  it "PUSH note.create then PULL note.list (sole-writer seam)" do
    before = Note.count
    r = rpc("note.create", { "title" => "via seam", "body" => "hello" }, opid: "op-#{before}")
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
    r = rpc("note.create", { "title" => "", "body" => "x" }, opid: "op-shape-#{before}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("grounding_refused")
    expect(Note.count).to eq(before)
    expect(RailsOsiLevel8::AdmissionAttempt.where(conforms: false).count).to be >= 1
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

    journal = rpc("l8.operation.journal", { "limit" => 50 })
    expect(journal["ok"]).to be(true)
    events = journal.dig("result", "@graph") || []
    expect(events.any? { |e| e.dig("detail_json", "replay") }).to be(true)

    receipts = rpc("l8.execution.receipt.list", { "limit" => 50 })
    expect(receipts["ok"]).to be(true)
    expect((receipts.dig("result", "@graph") || []).size).to be >= 1
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
    expect(note_id).to be_present
    expect(request_cid).to be_present
    expect(receipt_cid).to be_present

    bio = rpc("l8.biography.get", { "subject_iri" => "cyborg:front" })
    expect(bio["ok"]).to be(true)
    events = bio.dig("result", "@graph") || []
    expect(events.any? { |e| e["event_kind"] == "declared" && e["subject_iri"] == "cyborg:front" }).to be(true)

    # declare-once: second create must not add another declared biography for same actor
    before_bio = RailsOsiLevel8::BiographyEvent.where(subject_iri: "cyborg:front", event_kind: "declared").count
    rpc("note.create", { "title" => "p5 again", "body" => "x", "callerIri" => "cyborg:front" }, opid: "#{opid}-2")
    expect(RailsOsiLevel8::BiographyEvent.where(subject_iri: "cyborg:front", event_kind: "declared").count).to eq(before_bio)

    prov = rpc("l8.provenance.list", { "limit" => 100 })
    expect(prov["ok"]).to be(true)
    edges = prov.dig("result", "@graph") || []

    derived = edges.find { |e| e["from_cid"] == note_id && e["predicate"] == "prov:wasDerivedFrom" }
    expect(derived).to be_present
    expect(derived["to_cid"]).to eq(request_cid)

    generated = edges.find { |e| e["from_cid"] == receipt_cid && e["predicate"] == "prov:wasGeneratedBy" }
    expect(generated).to be_present
    expect(generated["to_cid"]).to eq(note_id)

    attributed = edges.find { |e| e["from_cid"] == note_id && e["predicate"] == "prov:wasAttributedTo" }
    expect(attributed).to be_present
    expect(attributed["to_iri"]).to eq("cyborg:front")
    expect(attributed["agent_iri"]).to eq("cyborg:front")
  end
end
