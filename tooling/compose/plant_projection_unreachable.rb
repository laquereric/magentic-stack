#!/usr/bin/env ruby
# frozen_string_literal: true
# Plant for gap 7 (b) / gap 112. No Rails boot, no live Oxigraph.
#
# Gap 69 made Immediate refuse on schema_status BEFORE reaching GRAPH.
# This harness used to have no outbox, so schedule recorded
# outbox_schema_check_failed twice and never graph_unreachable. The
# code was right; the plant was stale.
#
# Three faults, three reasons. Do not collapse them:
#   no AR connection     -> outbox_schema_check_failed
#   AR up, table missing -> outbox_not_installed
#   outbox installed     -> graph_unreachable / sparql_parse_error
# A SPARQL stub of graph_unreachable MUST NOT be recorded when the
# outbox is missing -- that would skip the gap-69 gate.

require "json"
require "fileutils"
require "tmpdir"

ROOT = File.expand_path("../..", __dir__)
Dir.chdir(ROOT)
require "bundler/setup"
require "vv-graph"
require "rails_cpcp/refusal_log"
require "active_record"
require "sqlite3"

log = File.join(Dir.tmpdir, "cpcp_refusals-gap7-#{Process.pid}.jsonl")
hb  = File.join(Dir.tmpdir, "cpcp_refusal_observer-gap7-#{Process.pid}.json")
FileUtils.rm_f(log)
FileUtils.rm_f(hb)
ENV["CPCP_REFUSAL_LOG"] = log
ENV["CPCP_REFUSAL_HEARTBEAT"] = hb
ENV.delete("MM_OXIGRAPH_URL")

rows = []
ok = true
def note(rows, name, passed, detail)
  rows << { "plant" => name, "ok" => passed, "detail" => detail }
  passed
end

def refusals_in(path)
  return [] unless File.file?(path)

  File.readlines(path, chomp: true).filter_map do |line|
    row = JSON.parse(line)
    row if row["kind"] == "refusal"
  end
end

def slice_log!(path)
  File.write(path, "")
end

def graph_stub(reason, because)
  Vv::Graph::Sparql.define_singleton_method(:execute) do |*_args, **_kwargs|
    { ok: false, reason: reason, because: because }
  end
end

def plant_record(reason)
  record = Object.new
  record.define_singleton_method(:semantica_emit_triples!) do
    { ok: false, reason: reason, because: "plant: GRAPH not reached" }
  end
  record.define_singleton_method(:semantica_primary_subject_iri) { "urn:mm:gap7:plant" }
  record.define_singleton_method(:semantica_graph_iri) { "urn:mm:pod:state" }
  record
end

def schedule(record, host)
  Vv::Graph::Publisher::Immediate.new.schedule(
    ref: Vv::Graph::Ref.new(host, 1),
    generation: 1,
    record: record,
  )
end

KEYS = %w[state_reached inconsistency restore_when restore_action].freeze

unless Object.const_defined?(:Gap7PlantHost)
  klass = Class.new do
    include Vv::Graph::Storable
    triples do
      subject -> { "urn:mm:gap7:plant" }
      triple "schema:name", -> { "n" }
    end
  end
  Object.const_set(:Gap7PlantHost, klass)
end

# --- emit path: Storable talks to SPARQL directly, no Immediate ----------
graph_stub(:graph_unreachable, "plant: GRAPH not reached")
emitted = Gap7PlantHost.new.semantica_emit_triples!
ok &&= note(rows, "emit-envelope",
            emitted.is_a?(Hash) && emitted[:ok] == false && emitted[:reason] == :graph_unreachable,
            emitted.inspect)

graph_stub(:sparql_parse_error, "plant: malformed INSERT")
parsed = Gap7PlantHost.new.semantica_emit_triples!
ok &&= note(rows, "emit-parse-error",
            parsed.is_a?(Hash) && parsed[:ok] == false && parsed[:reason] == :sparql_parse_error,
            parsed.inspect)

counts = { star: 0, other: 0 }
Vv::Graph::Sparql.define_singleton_method(:execute) do |query, **_kwargs|
  q = query.to_s
  if q.include?("isTRIPLE") || q.include?("<<")
    counts[:star] += 1
    { ok: false, reason: :sparql_parse_error, because: "blank nodes not allowed in DELETE" }
  else
    counts[:other] += 1
    { ok: true, count: 1 }
  end
end
star_ok = Gap7PlantHost.new.semantica_emit_triples!
ok &&= note(rows, "star-delete-exempt",
            star_ok == true && counts[:star] > 0 && counts[:other] > 0,
            "result=#{star_ok.inspect} star=#{counts[:star]} other=#{counts[:other]}")

# --- CASE A: no AR connection. Lookup raises. :check_failed. -------------
slice_log!(log)
graph_stub(:graph_unreachable, "plant: GRAPH not reached")
status_a = schedule(plant_record(:graph_unreachable), "Gap7NoConn")
reasons_a = refusals_in(log).map { |r| r["reason"] }
ok &&= note(rows, "no-connection-schedule-error", status_a == :error, "status=#{status_a.inspect}")
ok &&= note(rows, "no-connection-check-failed",
            reasons_a == ["outbox_schema_check_failed"],
            reasons_a.inspect)
ok &&= note(rows, "no-connection-does-not-reach-graph",
            !reasons_a.include?("graph_unreachable") && !reasons_a.include?("outbox_not_installed"),
            reasons_a.inspect)

# --- CASE B: AR up, table not installed. :missing. -----------------------
slice_log!(log)
::ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
::ActiveRecord::Base.connection.execute("SELECT 1")
missing = Vv::Graph::ProjectionJob.schema_status
ok &&= note(rows, "no-table-schema-missing", missing == :missing, "schema_status=#{missing.inspect}")
graph_stub(:graph_unreachable, "plant: GRAPH not reached")
status_b = schedule(plant_record(:graph_unreachable), "Gap7NoTable")
reasons_b = refusals_in(log).map { |r| r["reason"] }
ok &&= note(rows, "no-table-schedule-error", status_b == :error, "status=#{status_b.inspect}")
ok &&= note(rows, "no-table-not-installed",
            reasons_b == ["outbox_not_installed"],
            reasons_b.inspect)
ok &&= note(rows, "no-table-does-not-reach-graph",
            !reasons_b.include?("graph_unreachable"),
            reasons_b.inspect)
rest_b = refusals_in(log)
ok &&= note(rows, "no-table-restoration",
            rest_b.all? { |r| r["cpcp.restoration"].is_a?(Hash) && KEYS.all? { |k| r["cpcp.restoration"][k].to_s.strip != "" } },
            rest_b.map { |r| r["cpcp.restoration"] }.inspect)

# --- CASE C: outbox installed. Immediate reaches GRAPH. ------------------
slice_log!(log)
installed = Vv::Graph::ProjectionJob.ensure_schema!
ok &&= note(rows, "outbox-installed",
            installed == true && Vv::Graph::ProjectionJob.schema_status == :available,
            "ensure_schema!=#{installed.inspect} status=#{Vv::Graph::ProjectionJob.schema_status.inspect}")

graph_stub(:graph_unreachable, "plant: GRAPH not reached")
status_c1 = schedule(plant_record(:graph_unreachable), "Gap7Unreachable")
reasons_c1 = refusals_in(log).map { |r| r["reason"] }
ok &&= note(rows, "outbox-installed-schedule-error", status_c1 == :error, "status=#{status_c1.inspect}")
ok &&= note(rows, "outbox-installed-graph-unreachable",
            reasons_c1 == ["graph_unreachable"],
            reasons_c1.inspect)
ok &&= note(rows, "outbox-installed-not-an-outbox-reason",
            !reasons_c1.include?("outbox_not_installed") && !reasons_c1.include?("outbox_schema_check_failed"),
            reasons_c1.inspect)

slice_log!(log)
graph_stub(:sparql_parse_error, "plant: malformed INSERT")
status_c2 = schedule(plant_record(:sparql_parse_error), "Gap7Parse")
reasons_c2 = refusals_in(log).map { |r| r["reason"] }
ok &&= note(rows, "outbox-installed-sparql-parse-error",
            status_c2 == :error && reasons_c2 == ["sparql_parse_error"],
            "status=#{status_c2.inspect} reasons=#{reasons_c2.inspect}")

graph_rows = refusals_in(log)
complete = graph_rows.all? do |r|
  r["because"].to_s.include?("MM_OXIGRAPH_URL") &&
    r["cpcp.restoration"].is_a?(Hash) &&
    KEYS.all? { |k| r["cpcp.restoration"][k].to_s.strip != "" }
end
ok &&= note(rows, "graph-restoration-complete", complete,
            graph_rows.map { |r| [r["reason"], r["because"], r["cpcp.restoration"]] }.inspect)

puts "plant | ok | detail"
puts "------|----|--------"
rows.each { |r| puts "#{r['plant']} | #{r['ok']} | #{r['detail']}" }
puts ok ? "plant projection-unreachable: OK" : "plant projection-unreachable: FAIL"
exit(ok ? 0 : 1)
