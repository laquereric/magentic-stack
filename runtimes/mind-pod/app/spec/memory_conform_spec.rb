# frozen_string_literal: true

require "spec_helper"
require "json"
require "base64"
require "securerandom"
require "tmpdir"

# S2: memory.conform on BACK over POST /_cpcp/rpc, triggered in prod by
# BACKJOB polling completed memory.land operations (bin/backjob).
#
# BACK specs run under docker (bin/spec-all excludes this app on the
# host). Oxigraph runs in compose, not in any spec process: Mmg::Graph
# is stubbed to FakeSilver below, which stores the triples the seam
# posts and answers the three query shapes the service uses (bronze,
# labels, facts) plus an as-of read the specs use directly. The fake is
# oxigraph-faithful on bindings (bare values, no angle brackets) so the
# service parses both spellings it accepts.
class FakeSilver
  SILVER = "urn:mm:medallion/memory.conform/silver/1"
  BRONZE = "urn:mm:medallion/memory.episode/bronze/1"

  def initialize
    @triples = []
    @valid_to = {}
  end

  def update(sparql)
    sql = sparql.to_s
    if sql.include?("# s2:close")
      fact = sql[/<(urn:mm:fact:[^>]+)>/, 1]
      valid_to = sql[/<mm:validTo> "([^"]+)"/, 1]
      if valid_to.nil?
        @valid_to.delete(fact)
      else
        @valid_to[fact] = valid_to
      end
      return { ok: true }
    end
    graph = sql[/GRAPH <([^>]+)>/, 1]
    lines = sql.split("\n").grep(/\A<[^>]+> <[^>]+> .+ \.\s*\z/)
    return { ok: false, reason: :no_triples } if lines.empty? && sql.include?("INSERT DATA")

    lines.each do |line|
      m = line.match(/\A<([^>]+)> <([^>]+)> (.+?) \.\s*\z/)
      # Oxigraph-faithful bindings: bare values, so strip the literal
      # quotes AND the iri brackets the N-Triples carried.
      o = m[3].sub(/\A"(.*)"\z/m, '\1').sub(/\A<([^>]*)>\z/, '\1')
      @triples << [m[1], m[2], o]
    end
    { ok: true }
  end

  def query(sparql)
    sql = sparql.to_s
    graph = sql[/GRAPH <([^>]+)>/, 1]
    rows = @triples.select { |g, _, _, _| g == graph }
    if sql.include?("# s2:episode")
      ref = sql[/<mm:journalRef> "([^"]+)"/, 1]
      hits = rows.select { |_, _, p, o| p == "mm:journalRef" && o == ref }
      return { ok: true, rows: hits.map { |_, s, _, _| { "s" => s } } }
    end
    if sql.include?("# s2:bronze")
      episode = sql[/<(urn:mm:episode:[^>]+)>/, 1]
      rows = rows.select { |_, s, _, _| s == episode }
      return { ok: true, rows: rows.map { |_, _, p, o| { "p" => p, "o" => o } } }
    end
    if sql.include?("# s2:labels")
      rows = rows.select { |_, _, p, _| p == "mm:label" }
      return { ok: true, rows: rows.map { |_, s, _, o| { "s" => s, "o" => o } } }
    end
    out = rows.map { |_, s, p, o| { "f" => s, "p" => p, "o" => o } }
    @valid_to.each do |fact, vt|
      out << { "f" => fact, "p" => "mm:validTo", "o" => vt }
    end
    { ok: true, rows: out }
  end

  # Spec-side as-of read over the SILVER triples.
  def as_of(date)
    facts = {}
    @triples.each do |g, s, p, o|
      next unless g == SILVER
      next unless s.start_with?("urn:mm:fact:")
      next if p == "mm:validTo"

      (facts[s] ||= {})[p] = o
    end
    facts.each { |f, cols| cols["mm:validTo"] = @valid_to[f] if @valid_to.key?(f) }
    facts.values.select do |c|
      vf = c["mm:validFrom"]
      vt = c["mm:validTo"]
      !vf.nil? && vf <= date && (vt.nil? || date < vt)
    end
  end
end

RSpec.describe "S2 memory.conform (POST /_cpcp/rpc)" do
  include Rack::Test::Methods
  def app = Rails.application

  def rpc(method, params = {}, opid: nil)
    body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
    body["operationId"] = opid if opid
    post "/_cpcp/rpc", body.to_json, "CONTENT_TYPE" => "application/json"
    expect(last_response.status).to eq(200)
    JSON.parse(last_response.body)
  end

  def land_params(text, observed_at, session: "s1")
    {
      "bytes" => Base64.strict_encode64(text),
      "session" => session, "actor" => "user:1",
      "observed_at" => observed_at,
      "modality" => "text", "source_system" => "transcript",
      "kind" => "observed"
    }
  end

  def land!(text, observed_at, session: "s1")
    opid = "op-land-#{SecureRandom.hex(4)}"
    r = rpc("memory.land", land_params(text, observed_at, session: session), opid: opid)
    expect(r["ok"]).to be(true)
    [r.dig("result", "episode_iri"), opid]
  end

  def conform!(journal_ref)
    rpc("memory.conform", { "journal_ref" => journal_ref },
        opid: "op-conform-#{SecureRandom.hex(4)}")
  end

  let(:silver) { FakeSilver.new }

  before do
    allow(Mmg::Graph::Execute).to receive(:update) { |sparql| silver.update(sparql) }
    allow(Mmg::Graph::Execute).to receive(:query) { |sparql| silver.query(sparql) }
  end

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

  it "conforms an episode: resolves, writes Silver, reports the gate" do
    _, opid = land!("Priya Raman is my manager.", "2026-01-01T00:00:00Z")
    r = conform!(opid)
    expect(r["ok"]).to be(true)
    result = r["result"]
    expect(result["entities"].size).to eq(1)
    expect(result["entities"].first).to start_with("urn:mm:entity:priya-raman-")
    expect(result["facts_written"]).to eq(1)
    expect(result["closed"]).to eq(0)
    expect(result["shacl_engine"]).to eq("mmg_shacl_v1")
    expect(result["silver_graph"]).to eq("urn:mm:medallion/memory.conform/silver/1")
  end

  it "two surface forms share one IRI; the update closes the interval" do
    _, opid1 = land!("Priya Raman is my manager.", "2026-01-01T00:00:00Z")
    first = conform!(opid1)
    iri = first.dig("result", "entities").first

    _, opid2 = land!("P. Raman is now director. Priya Raman approved the budget.", "2026-06-01T00:00:00Z")
    second = conform!(opid2)
    expect(second["ok"]).to be(true)
    expect(second.dig("result", "entities")).to eq([iri])
    expect(second.dig("result", "closed")).to eq(1)
    expect(second.dig("result", "facts_written")).to eq(1)
  end

  it "as-of T1 sees manager, not director" do
    _, opid1 = land!("Priya Raman is my manager.", "2026-01-01T00:00:00Z")
    conform!(opid1)
    _, opid2 = land!("P. Raman is now director.", "2026-06-01T00:00:00Z")
    conform!(opid2)

    then_roles = silver.as_of("2026-03-01").select { |c| c["mm:predicate"] == "mm:role" }
    expect(then_roles.map { |c| c["mm:object"] }).to eq(["manager"])
    now_roles = silver.as_of("2026-09-01").select { |c| c["mm:predicate"] == "mm:role" }
    expect(now_roles.map { |c| c["mm:object"] }).to eq(["director"])
  end

  it "a duplicate conform is a no-op" do
    _, opid = land!("Priya Raman is my manager.", "2026-01-01T00:00:00Z")
    expect(conform!(opid).dig("result", "facts_written")).to eq(1)
    rerun = conform!(opid)
    expect(rerun["ok"]).to be(true)
    expect(rerun.dig("result", "facts_written")).to eq(0)
    expect(rerun.dig("result", "closed")).to eq(0)
    expect(rerun.dig("result", "skipped")).to be > 0
  end

  it "unknown journal_ref refuses without touching Silver" do
    r = conform!("op-never-landed")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("episode_not_landed")
  end

  it "missing journal_ref is grounding_refused" do
    r = rpc("memory.conform", {}, opid: "op-nojournal-#{SecureRandom.hex(4)}")
    expect(r["ok"]).to be(false)
    expect(r.dig("error", "reason")).to eq("grounding_refused")
  end

  it "an episode with no claims conforms vacuously" do
    _, opid = land!("It rained on Tuesday.", "2026-01-01T00:00:00Z")
    r = conform!(opid)
    expect(r["ok"]).to be(true)
    expect(r.dig("result", "entities")).to eq([])
    expect(r.dig("result", "facts_written")).to eq(0)
  end
end
