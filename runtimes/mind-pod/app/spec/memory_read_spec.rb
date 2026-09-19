# frozen_string_literal: true

require "spec_helper"
require "json"
require "securerandom"

# S4: memory.read on BACK over POST /_cpcp/rpc (a PULL: no receipt, no
# journal rows, admission attempts only).
#
# BACK specs run under docker (bin/spec-all excludes this app on the
# host). Mmg::Graph is stubbed to FakeReadGraph: Silver facts, labels,
# and Gold profiles in memory, graph-scoped like the seam.
class FakeReadGraph
  SILVER = "urn:mm:medallion/memory.conform/silver/1"
  GOLD = "urn:mm:medallion/memory.promote/gold/1"

  def initialize(silver: [], gold: [])
    @silver = silver
    @gold = gold
  end

  def update(_sparql)
    { ok: false, reason: :read_only, because: "memory.read never writes" }
  end

  def query(sparql)
    sql = sparql.to_s
    store = sql.include?(GOLD) ? @gold : @silver
    if sql.include?("# s4:labels")
      rows = store.select { |_, _, p, _| p == "mm:label" }
      return { ok: true, rows: rows.map { |_, s, _, o| { "s" => s, "o" => o } } }
    end
    { ok: true, rows: store.map { |_, s, p, o| { "f" => s, "p" => p, "o" => o } } }
  end
end

RSpec.describe "S4 memory.read (POST /_cpcp/rpc)" do
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
  F_CLOSED = "urn:mm:fact:bbbb00000002"
  EP = "urn:mm:episode:sha256:aaa"

  def silver_triples
    [
      [F_ROLE, "mm:subject", E],
      [F_ROLE, "mm:predicate", "mm:role"],
      [F_ROLE, "mm:object", "manager"],
      [F_ROLE, "mm:validFrom", "2026-01-01T00:00:00Z"],
      [F_ROLE, "mm:sourceEpisode", EP],
      [F_CLOSED, "mm:subject", E],
      [F_CLOSED, "mm:predicate", "mm:role"],
      [F_CLOSED, "mm:object", "intern"],
      [F_CLOSED, "mm:validFrom", "2025-01-01T00:00:00Z"],
      [F_CLOSED, "mm:validTo", "2025-06-01T00:00:00Z"],
      [F_CLOSED, "mm:sourceEpisode", EP],
      [E, "mm:label", "Priya Raman"],
      [E, "mm:sourceEpisode", EP]
    ]
  end

  def gold_triples
    p = "urn:mm:gold:persona:priya-raman-5f1bf447"
    [
      [p, "mm:subject", E],
      [p, "mm:model", "urn:mm:model/persona-profile"],
      [p, "mm:role", "manager"],
      [p, "mm:label", "Priya Raman"],
      [p, "mm:asOf", "2026-01-01T00:00:00Z"],
      [p, "mm:sourceEpisode", EP]
    ]
  end

  def seed_frame!
    frame = ContextFrame.create!(canonical_id: "frame:read-#{SecureRandom.hex(3)}", title: "Standup")
    m1 = Meaning.create!(title: "Priya owns deploy", excerpt: "Priya Raman owns the deploy pipeline")
    m2 = Meaning.create!(title: "Staging lags", excerpt: "staging is two releases behind")
    m3 = Meaning.create!(title: "Retired alert", excerpt: "old pagerduty noise")
    ContextFrameMeaningWeight.create!(context_frame: frame, meaning: m1, weight: 0.8)
    ContextFrameMeaningWeight.create!(context_frame: frame, meaning: m2, weight: 0.3)
    ContextFrameMeaningWeight.create!(context_frame: frame, meaning: m3, weight: 0.0)
    c1 = Clarification.create!(title: "Deploy owner", excerpt: "confirmed in handoff notes")
    c0 = Clarification.create!(title: "Stale note", excerpt: "superseded")
    MeaningClarificationWeight.create!(meaning: m1, clarification: c1, weight: 0.9)
    MeaningClarificationWeight.create!(meaning: m1, clarification: c0, weight: 0.0)
    frame
  end

  let(:graph) { FakeReadGraph.new(silver: silver_triples, gold: gold_triples) }

  before do
    allow(Mmg::Graph::Execute).to receive(:query) { |sparql| graph.query(sparql) }
    allow(Mmg::Graph::Execute).to receive(:update) { |sparql| graph.update(sparql) }
  end

  it "serves the frame walk within budget, zeros inspectable" do
    frame = seed_frame!
    r = rpc("memory.read", { "frame" => frame.canonical_id, "budget_tokens" => 1000 })
    expect(r["ok"]).to be(true)
    result = r["result"]
    expect(result["frame"]).to eq(frame.canonical_id)
    kinds = result["injected"].map { |i| [i["kind"], i["title"]] }
    expect(kinds).to include(["meaning", "Priya owns deploy"], ["meaning", "Staging lags"],
                             ["clarification", "Deploy owner"])
    expect(kinds).not_to include(["meaning", "Retired alert"], ["clarification", "Stale note"])
    inspectable = result["inspectable"].map { |i| i["title"] }
    expect(inspectable).to include("Retired alert", "Stale note")
    expect(result["tokens"]).to be <= 1000
    expect(result["truncated"]).to be(false)
  end

  it "a tight budget truncates and says so" do
    frame = seed_frame!
    r = rpc("memory.read", { "frame" => frame.canonical_id, "budget_tokens" => 4 })
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "truncated")).to be(true)
    expect(r.dig("result", "tokens")).to be <= 4
    expect(r.dig("result", "injected").size).to be >= 1
  end

  it "a cue recalls Gold profiles, Silver facts, and blob refs" do
    frame = seed_frame!
    r = rpc("memory.read",
            { "frame" => frame.canonical_id, "budget_tokens" => 1000, "cue" => "manager platform" })
    expect(r["ok"]).to be(true)
    result = r["result"]
    kinds = result["injected"].map { |i| i["kind"] }.uniq
    expect(kinds).to include("gold_profile", "silver_fact")
    expect(result["injected"].select { |i| i["kind"] == "gold_profile" }.first["subject_iri"]).to eq(E)
    expect(result["blob_refs"]).to include("sha256:aaa")
  end

  it "as_of filters world time" do
    frame = seed_frame!
    r = rpc("memory.read",
            { "frame" => frame.canonical_id, "budget_tokens" => 1000,
              "cue" => "manager", "as_of" => "2026-09-01" })
    expect(r["ok"]).to be(true)
    objects = r.dig("result", "injected").select { |i| i["kind"] == "silver_fact" }
               .map { |i| i["object"] }
    expect(objects).to include("manager")
    expect(objects).not_to include("intern")
  end

  it "an unknown frame refuses without reading anything" do
    r = rpc("memory.read", { "frame" => "frame:nope", "budget_tokens" => 100 })
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("frame_not_found")
  end

  it "a missing budget is grounding_refused" do
    frame = seed_frame!
    r = rpc("memory.read", { "frame" => frame.canonical_id })
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("grounding_refused")
  end
end
