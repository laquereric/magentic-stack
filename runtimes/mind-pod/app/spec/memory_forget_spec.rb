# frozen_string_literal: true

require "spec_helper"
require "json"
require "securerandom"

# S5: memory.forget on BACK over POST /_cpcp/rpc.
#
# BACK specs run under docker (bin/spec-all excludes this app on the
# host). Mmg::Graph is stubbed to FakeForgetGraph, which holds Bronze,
# Silver, and Gold triples and applies the DELETE WHERE closes the seam
# posts. Tombstones accumulate like the real graph set.
class FakeForgetGraph
  BRONZE = "urn:mm:medallion/memory.episode/bronze/1"
  SILVER = "urn:mm:medallion/memory.conform/silver/1"
  GOLD = "urn:mm:medallion/memory.promote/gold/1"

  def initialize
    @graphs = Hash.new { |h, k| h[k] = [] }
  end

  def seed(graph, triples)
    @graphs[graph].concat(triples)
  end

  def triples_for(graph, subject: nil)
    @graphs[graph].select { |s, _, _| subject.nil? || s == subject }
  end

  def update(sparql)
    sql = sparql.to_s
    if sql.include?("# s5:drop")
      iri = sql[/\{ <(urn:[^>]+)> \?p/, 1]
      graph = sql[/GRAPH <([^>]+)>/, 1]
      @graphs[graph].reject! { |s, _, _| s == iri }
      return { ok: true }
    end
    graph = sql[/GRAPH <([^>]+)>/, 1]
    sql.split("\n").grep(/\A<[^>]+> <[^>]+> .+ \.\s*\z/).each do |line|
      m = line.match(/\A<([^>]+)> <([^>]+)> (.+?) \.\s*\z/)
      o = m[3].sub(/\A"(.*)"\z/m, '\1').sub(/\A<([^>]*)>\z/, '\1')
      @graphs[graph] << [m[1], m[2], o] unless @graphs[graph].include?([m[1], m[2], o])
    end
    { ok: true }
  end

  def query(sparql)
    sql = sparql.to_s
    graph = sql[/GRAPH <([^>]+)>/, 1]
    rows = @graphs[graph]
    if sql.include?("# s5:bronze")
      ep = sql[/<(urn:mm:episode:[^>]+)>/, 1]
      ep_rows = rows.select { |s, _, _| s == ep }
      return { ok: true, rows: ep_rows.map { |_, p, o| { "p" => p, "o" => o } } }
    end
    # s5:silver + s5:gold: rows of nodes the episode sourced.
    ep = sql[/<(urn:mm:episode:[^>]+)>/, 1]
    owners = rows.select { |_, p, o| p == "mm:sourceEpisode" && o == ep }.map(&:first).uniq
    out = []
    rows.each do |s, p, o|
      next unless owners.include?(s)

      out << { "f" => s, "p" => p, "o" => o, "s" => s }
    end
    { ok: true, rows: out }
  end
end

RSpec.describe "S5 memory.forget (POST /_cpcp/rpc)" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(200)
    JSON.parse(last_response.body)
  end

  EP = "urn:mm:episode:sha256:aaa"
  E = "urn:mm:entity:priya-raman-5f1bf447"
  F_ROLE = "urn:mm:fact:aaaa00000001"
  PROFILE = "urn:mm:gold:persona:priya-raman-5f1bf447"

  def seed!
    graph.seed(FakeForgetGraph::BRONZE, [
      [EP, "mm:blob", "sha256:aaa"],
      [EP, "mm:session", "s1"],
      [EP, "mm:kind", "observed"]
    ])
    graph.seed(FakeForgetGraph::SILVER, [
      [F_ROLE, "mm:subject", E],
      [F_ROLE, "mm:predicate", "mm:role"],
      [F_ROLE, "mm:object", "manager"],
      [F_ROLE, "mm:validFrom", "2026-01-01T00:00:00Z"],
      [F_ROLE, "mm:sourceEpisode", EP]
    ])
    graph.seed(FakeForgetGraph::GOLD, [
      [PROFILE, "mm:subject", E],
      [PROFILE, "mm:role", "manager"],
      [PROFILE, "mm:sourceEpisode", EP]
    ])
  end

  def forget_params(**over)
    {
      "episode_iri" => EP,
      "retention_basis" => "steward_request",
      "decided_by" => "user:1"
    }.merge(over.transform_keys(&:to_s))
  end

  let(:graph) { FakeForgetGraph.new }

  before do
    seed!
    allow(Mmg::Graph::Execute).to receive(:query) { |sparql| graph.query(sparql) }
    allow(Mmg::Graph::Execute).to receive(:update) { |sparql| graph.update(sparql) }
  end

  it "tombstones Bronze and cascades Silver facts and the Gold profile" do
    r = rpc("memory.forget", forget_params, opid: "op-forget-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(true)
    result = r["result"]
    expect(result["episode_iri"]).to eq(EP)
    expect(result["tombstoned"]).to be(true)
    expect(result["subjects"]).to eq([E])
    expect(result["silver_facts_removed"]).to eq(1)
    expect(result["gold_profiles_removed"]).to eq(1)

    expect(graph.triples_for(FakeForgetGraph::SILVER)).to be_empty
    expect(graph.triples_for(FakeForgetGraph::GOLD)).to be_empty
    tombstone = graph.triples_for(FakeForgetGraph::BRONZE).select { |_, p, _| p == "mm:tombstonedAt" }
    expect(tombstone.size).to eq(1)
  end

  it "a forgotten fact is not served afterwards" do
    rpc("memory.forget", forget_params, opid: "op-forget-#{SecureRandom.hex(4)}")
    remaining = graph.triples_for(FakeForgetGraph::SILVER).select { |_, p, _| p == "mm:object" }
    expect(remaining).to be_empty
  end

  it "reruns converge" do
    first = rpc("memory.forget", forget_params, opid: "op-forget-#{SecureRandom.hex(4)}")
    expect(first["ok"]).to be(true)
    second = rpc("memory.forget", forget_params, opid: "op-forget-#{SecureRandom.hex(4)}")
    expect(second["ok"]).to be(true)
    expect(second.dig("result", "silver_facts_removed")).to eq(0)
    expect(second.dig("result", "tombstoned")).to be(true)
  end

  it "an unknown episode refuses with nothing written" do
    before = graph.triples_for(FakeForgetGraph::SILVER).size
    r = rpc("memory.forget", forget_params.merge("episode_iri" => "urn:mm:episode:sha256:nope"),
            opid: "op-forget-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("episode_not_landed")
    expect(graph.triples_for(FakeForgetGraph::SILVER).size).to eq(before)
  end

  it "missing retention evidence is grounding_refused" do
    r = rpc("memory.forget", forget_params.reject { |k, _| k == "retention_basis" },
            opid: "op-forget-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("grounding_refused")
  end

  it "missing operationId is refused" do
    r = rpc("memory.forget", forget_params)
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("operation_id_required")
  end
end
