# frozen_string_literal: true

require "spec_helper"
require "json"
require "securerandom"

# memory.lookup + memory.stat on BACK over POST /_cpcp/rpc (both PULLs:
# no receipts, no journal rows).
#
# BACK specs run under docker (bin/spec-all excludes this app on the
# host). Mmg::Graph is stubbed to FakeProductGraph, which answers counts
# and the named query shapes over seeded triples. Journal history for
# stat runs against the real tables (transactional rollback).
class FakeProductGraph
  SILVER = "urn:mm:medallion/memory.conform/silver/1"
  GOLD = "urn:mm:medallion/memory.promote/gold/1"
  BRONZE = "urn:mm:medallion/memory.episode/bronze/1"

  def initialize(silver: [], gold: [], bronze: [])
    @silver = silver
    @gold = gold
    @bronze = bronze
  end

  def update(_sparql)
    { ok: false, reason: :read_only, because: "lookup and stat never write" }
  end

  def store_for(graph)
    return @gold if graph == GOLD
    return @bronze if graph == BRONZE

    @silver
  end

  def query(sparql)
    sql = sparql.to_s
    store = store_for(sql[/GRAPH <([^>]+)>/, 1])
    if sql.include?("COUNT(")
      if sql.include?("DISTINCT")
        return { ok: true, rows: [{ "n" => store.map(&:first).uniq.size.to_s }] }
      end

      return { ok: true, rows: [{ "n" => store.size.to_s }] }
    end
    # role_at projects aliases (object + validity), like the SPARQL does.
    if sql.include?("# lookup:role_at")
      by_fact = {}
      store.each { |s, p, o| (by_fact[s] ||= {})[p] = o }
      return { ok: true, rows: by_fact.filter_map { |_, cols|
        next if cols["mm:object"].nil?

        { "s" => cols["mm:subject"], "o" => cols["mm:object"],
          "vf" => cols["mm:validFrom"], "vt" => cols["mm:validTo"] }
      } }
    end
    rows = store.map { |s, p, o| { "f" => s, "p" => p, "o" => o, "s" => s } }
    { ok: true, rows: rows }
  end
end

RSpec.describe "memory.lookup + memory.stat (POST /_cpcp/rpc)" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(200)
    JSON.parse(last_response.body)
  end

  E = "urn:mm:entity:priya-raman-5f1bf447"
  F_ROLE = "urn:mm:fact:aaaa00000001"
  EP = "urn:mm:episode:sha256:aaa"
  PROFILE = "urn:mm:gold:persona:priya-raman-5f1bf447"

  def silver_seed
    [
      [F_ROLE, "mm:subject", E],
      [F_ROLE, "mm:predicate", "mm:role"],
      [F_ROLE, "mm:object", "manager"],
      [F_ROLE, "mm:validFrom", "2026-01-01T00:00:00Z"],
      [F_ROLE, "mm:sourceEpisode", EP],
      [E, "mm:label", "Priya Raman"]
    ]
  end

  def gold_seed
    [
      [PROFILE, "mm:subject", E],
      [PROFILE, "mm:role", "manager"]
    ]
  end

  let(:graph) { FakeProductGraph.new(silver: silver_seed, gold: gold_seed) }

  before do
    allow(Mmg::Graph::Execute).to receive(:query) { |sparql| graph.query(sparql) }
    allow(Mmg::Graph::Execute).to receive(:update) { |sparql| graph.update(sparql) }
  end

  it "role_at answers then-believed values" do
    r = rpc("memory.lookup", { "name" => "role_at", "subject_iri" => E })
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "query")).to eq("role_at")
    expect(r.dig("result", "rows")).to eq(
      [{ "object" => "manager", "valid_from" => "2026-01-01T00:00:00Z" }]
    )
  end

  it "entity_facts returns the subject's Silver rows" do
    r = rpc("memory.lookup", { "name" => "entity_facts", "subject_iri" => E })
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "count")).to eq(1)
    expect(r.dig("result", "rows", 0, "object")).to eq("manager")
  end

  it "episode_facts returns the episode's Silver rows" do
    r = rpc("memory.lookup", { "name" => "episode_facts", "episode_iri" => EP })
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "count")).to eq(1)
  end

  it "profile_for returns Gold rows" do
    r = rpc("memory.lookup", { "name" => "profile_for", "subject_iri" => E })
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "rows").size).to eq(2)
  end

  # The catalog is closed at BOTH layers, and the outer one wins on the
  # wire: the grounding twin knows the four names, so an unknown name
  # never reaches the service. The service keeps its own check for
  # direct callers (BACKJOB, console) -- asserted below by calling it,
  # so the branch is proven rather than merely present.
  it "an unknown query is grounding_refused on the wire, naming the catalog" do
    r = rpc("memory.lookup", { "name" => "sparql" })
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("grounding_refused")
    expect(r.dig("error", "because").to_s).to include("role_at")
  end

  it "an unknown query called directly is audit_rejected, untouched graph" do
    expect { MemoryLookup.call({ "name" => "sparql" }, graph_client: graph) }
      .to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
        expect(e.reason.to_s).to eq("audit_rejected")
      }
  end

  # name is a DECLARED param: absent is refused by the dispatcher before
  # grounding runs, empty by the grounding twin.
  it "name absent is missing_params, empty is grounding_refused" do
    absent = rpc("memory.lookup", {})
    expect(absent["ok"]).to be(false)
    expect(absent.dig("error", "reason")).to eq("missing_params")

    empty = rpc("memory.lookup", { "name" => "" })
    expect(empty["ok"]).to be(false)
    expect(empty.dig("error", "reason")).to eq("grounding_refused")
  end

  it "stat reports counts, no promotion yet, and unindexed rag" do
    r = rpc("memory.stat", {})
    expect(r["ok"]).to be(true)
    result = r["result"]
    expect(result.dig("counts", "silver_triples")).to eq(6)
    expect(result.dig("counts", "gold_triples")).to eq(2)
    expect(result.dig("counts", "bronze_triples")).to eq(0)
    expect(result.dig("counts", "silver_subjects")).to eq(2)
    expect(result["last_promotion"]).to be_nil
    expect(result["shacl_reports"]).to eq([])
    expect(result.dig("rag", "status")).to eq("unindexed")
    expect(result.dig("rag", "reason")).to include("rag_write_undecided")
  end
end
