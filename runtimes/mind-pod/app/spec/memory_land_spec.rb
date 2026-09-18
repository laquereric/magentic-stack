# frozen_string_literal: true

require "spec_helper"
require "json"
require "base64"
require "securerandom"
require "tmpdir"

# S1: memory.land on BACK over POST /_cpcp/rpc.
#
# Happy path + typed refusals. HTTP 200 always (never-raise). BACK specs
# run under docker (bin/spec-all excludes this app on the host); the
# seams are stubbed nowhere here except oxigraph, which no spec process
# runs -- the fake asserts the Bronze INSERT the land would have posted.
RSpec.describe "S1 memory.land (POST /_cpcp/rpc)" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(200)
    JSON.parse(last_response.body)
  end

  def land_params(**over)
    {
      "bytes" => Base64.strict_encode64("session transcript, turn 12"),
      "session" => "s1", "actor" => "user:1",
      "observed_at" => "2026-09-18T00:00:00Z",
      "modality" => "text", "source_system" => "transcript",
      "kind" => "observed"
    }.merge(over.transform_keys(&:to_s))
  end

  # Oxigraph runs in compose, not in any spec process: the land posts its
  # Bronze INSERT through Mmg::Graph::Execute, which is stubbed here so the
  # spec asserts the INSERT rather than performing it.
  before do
    allow(Mmg::Graph::Execute).to receive(:update).and_return({ ok: true })
  end

  # First blob user on BACK: isolate the sqlite file per example. reset!
  # only clears the handle, so the ENV value is saved and restored too.
  around do |ex|
    Dir.mktmpdir do |dir|
      old = ENV["MMG_BLOB_PATH"]
      ENV["MMG_BLOB_PATH"] = File.join(dir, "blobs.sqlite3")
      Mmg::Blob::Operations.reset!
      ex.run
      Mmg::Blob::Operations.reset!
      ENV["MMG_BLOB_PATH"] = old
    end
  end

  it "lands bytes to blob and the episode to the Bronze graph" do
    r = rpc("memory.land", land_params, opid: "op-land-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(true)
    result = r["result"]
    expect(result["episode_iri"]).to start_with("urn:mm:episode:sha256:")
    expect(result["digest"]).to start_with("sha256:")
    expect(result["stored"]).to be(true)
    expect(result["journal_ref"]).to start_with("op-land-")
    expect(result["graph"]).to eq("urn:mm:medallion/memory.episode/bronze/1")

    expect(Mmg::Graph::Execute).to have_received(:update) do |sparql|
      expect(sparql).to include("INSERT DATA")
      expect(sparql).to include(result["episode_iri"])
      expect(sparql).to include(result["digest"])
    end
  end

  it "same bytes twice file once: stored false the second time" do
    params = land_params
    first = rpc("memory.land", params, opid: "op-once-#{SecureRandom.hex(4)}")
    second = rpc("memory.land", params, opid: "op-twice-#{SecureRandom.hex(4)}")
    expect(first.dig("result", "digest")).to eq(second.dig("result", "digest"))
    expect(first.dig("result", "stored")).to be(true)
    expect(second.dig("result", "stored")).to be(false)
    entries = Mmg::Blob::Operations.entries("digest" => first.dig("result", "digest"))
    expect(entries[:entries].size).to eq(2)
  end

  it "same operationId replays the episode instead of landing twice" do
    params = land_params
    opid = "op-replay-#{SecureRandom.hex(4)}"
    first = rpc("memory.land", params, opid: opid)
    expect(first["ok"]).to be(true)
    digest = first.dig("result", "digest")
    second = rpc("memory.land", params, opid: opid)
    expect(second["ok"]).to be(true)
    expect(second.dig("result", "governance", "replayed") ||
           second.dig("result", "replayed")).to be_truthy
    # The replay never reaches the handler: one filing, not two.
    entries = Mmg::Blob::Operations.entries("digest" => digest)
    expect(entries[:entries].size).to eq(1)
  end

  it "a summary stamped observed is bronze_mutated, and files nothing" do
    before = Mmg::Blob::Operations.list({})
    r = rpc("memory.land",
            land_params(kind: "observed", derived_from: "urn:mm:episode/1"),
            opid: "op-mut-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("bronze_mutated")
    expect(Mmg::Blob::Operations.list({})).to eq(before)
    expect(Mmg::Graph::Execute).not_to have_received(:update)
  end

  it "missing bytes is grounding_refused before anything is filed" do
    r = rpc("memory.land", land_params.reject { |k, _| k == "bytes" },
            opid: "op-nobytes-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("grounding_refused")
    expect(Mmg::Graph::Execute).not_to have_received(:update)
  end

  it "missing operationId is refused" do
    r = rpc("memory.land", land_params)
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("operation_id_required")
  end

  it "a dead graph fails the land closed, retryably" do
    allow(Mmg::Graph::Execute).to receive(:update)
      .and_return({ ok: false, reason: :update_error, because: "connection refused" })
    r = rpc("memory.land", land_params, opid: "op-deadgraph-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("graph_write_failed")
  end
end
