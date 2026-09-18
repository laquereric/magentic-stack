# frozen_string_literal: true

require "spec_helper"
require "json"
require "securerandom"

# S3: memory.promote on BACK over POST /_cpcp/rpc, explicitly invoked.
#
# BACK specs run under docker (bin/spec-all excludes this app on the
# host). Mmg::Graph is stubbed to FakeGold, which answers the two Silver
# reads and captures the Gold INSERT the armed engine posts.
class FakeGold
  def initialize(silver: [])
    @silver = silver
    @updates = []
  end

  attr_reader :updates

  def update(sparql)
    @updates << sparql.to_s
    { ok: true }
  end

  def query(sparql)
    sql = sparql.to_s
    if sql.include?("# s3:labels")
      rows = @silver.select { |_, _, p, _| p == "mm:label" }
      return { ok: true, rows: rows.map { |_, s, _, o| { "s" => s, "o" => o } } }
    end
    out = @silver.map { |_, s, p, o| { "f" => s, "p" => p, "o" => o } }
    { ok: true, rows: out }
  end
end

RSpec.describe "S3 memory.promote (POST /_cpcp/rpc)" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(200)
    JSON.parse(last_response.body)
  end

  def silver_triples(entity: "urn:mm:entity:priya-raman-5f1bf447", role: "manager")
    fact = "urn:mm:fact:aaaa00000001"
    [
      [fact, "mm:subject", entity],
      [fact, "mm:predicate", "mm:role"],
      [fact, "mm:object", role],
      [fact, "mm:validFrom", "2026-01-01T00:00:00Z"],
      [fact, "mm:sourceEpisode", "urn:mm:episode:sha256:aaa"],
      [entity, "mm:label", "Priya Raman"],
      [entity, "mm:sourceEpisode", "urn:mm:episode:sha256:aaa"]
    ]
  end

  let(:gold) { FakeGold.new(silver: silver_triples) }

  before do
    allow(Mmg::Graph::Execute).to receive(:query) { |sparql| gold.query(sparql) }
    allow(Mmg::Graph::Execute).to receive(:update) { |sparql| gold.update(sparql) }
  end

  it "promotes a Silver subject to the Gold persona profile" do
    r = rpc("memory.promote", { "subject_iri" => "urn:mm:entity:priya-raman-5f1bf447" },
            opid: "op-promote-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(true)
    result = r["result"]
    expect(result["profile_iri"]).to eq("urn:mm:gold:persona:priya-raman-5f1bf447")
    expect(result["subject_iri"]).to eq("urn:mm:entity:priya-raman-5f1bf447")
    expect(result["model_iri"]).to eq("urn:mm:model/persona-profile")
    expect(result["contract_iri"]).to eq("urn:mm:contract/persona-profile")
    expect(result["gold_graph"]).to eq("urn:mm:medallion/memory.promote/gold/1")
    expect(result["triples_written"]).to be > 0
    expect(result["shacl_engine"]).to eq("mmg_shacl_v1")

    posted = gold.updates.join("\n")
    expect(posted).to include("urn:mm:gold:persona:priya-raman-5f1bf447")
    expect(posted).to include("urn:mm:medallion/memory.promote/gold/1")
    expect(posted).to include("manager")
  end

  it "an unknown subject refuses with nothing written" do
    r = rpc("memory.promote", { "subject_iri" => "urn:mm:entity:nobody-here" },
            opid: "op-promote-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("audit_rejected")
    expect(gold.updates).to be_empty
  end

  it "missing subject_iri is grounding_refused" do
    r = rpc("memory.promote", {}, opid: "op-promote-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("grounding_refused")
  end

  it "missing operationId is refused" do
    r = rpc("memory.promote", { "subject_iri" => "urn:mm:entity:priya-raman-5f1bf447" })
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("operation_id_required")
  end

  it "re-promotion rewrites the same profile iri" do
    first = rpc("memory.promote", { "subject_iri" => "urn:mm:entity:priya-raman-5f1bf447" },
                opid: "op-promote-#{SecureRandom.hex(4)}")
    second = rpc("memory.promote", { "subject_iri" => "urn:mm:entity:priya-raman-5f1bf447" },
                 opid: "op-promote-#{SecureRandom.hex(4)}")
    expect(second["ok"]).to be(true)
    expect(second.dig("result", "profile_iri")).to eq(first.dig("result", "profile_iri"))
  end
end
