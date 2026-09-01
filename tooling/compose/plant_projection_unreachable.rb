#!/usr/bin/env ruby
# frozen_string_literal: true
# Plant for gap 7 (b). No Rails boot, no live Oxigraph.
# A Storable emit that cannot reach GRAPH must return the envelope;
# Immediate must return :error and write RefusalLog with restoration.
# Does not raise. Does not mark a silent success.

require "json"
require "fileutils"
require "tmpdir"

ROOT = File.expand_path("../..", __dir__)
Dir.chdir(ROOT)
require "bundler/setup"
require "vv-graph"
require "rails_cpcp/refusal_log"

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

Vv::Graph::Sparql.define_singleton_method(:execute) do |*_args, **_kwargs|
  { ok: false, reason: :graph_unreachable, because: "plant: GRAPH not reached" }
end

emitted = Gap7PlantHost.new.semantica_emit_triples!
ok &&= note(rows, "emit-envelope",
            emitted.is_a?(Hash) && emitted[:ok] == false && emitted[:reason] == :graph_unreachable,
            emitted.inspect)

Vv::Graph::Sparql.define_singleton_method(:execute) do |*_args, **_kwargs|
  { ok: false, reason: :sparql_parse_error, because: "plant: malformed INSERT" }
end
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

record = Object.new
def record.semantica_emit_triples!
  { ok: false, reason: :graph_unreachable, because: "plant: GRAPH not reached" }
end
def record.semantica_primary_subject_iri
  "urn:mm:gap7:plant"
end
def record.semantica_graph_iri
  "urn:mm:pod:state"
end

status = Vv::Graph::Publisher::Immediate.new.schedule(
  ref: Vv::Graph::Ref.new("Gap7PlantHost", 1),
  generation: 1,
  record: record,
)
ok &&= note(rows, "schedule-error", status == :error, "status=#{status.inspect}")

parse_record = Object.new
def parse_record.semantica_emit_triples!
  { ok: false, reason: :sparql_parse_error, because: "plant: malformed INSERT" }
end
def parse_record.semantica_primary_subject_iri
  "urn:mm:gap93:plant"
end
def parse_record.semantica_graph_iri
  "urn:mm:pod:state"
end
parse_status = Vv::Graph::Publisher::Immediate.new.schedule(
  ref: Vv::Graph::Ref.new("Gap93PlantHost", 1),
  generation: 1,
  record: parse_record,
)
ok &&= note(rows, "schedule-parse-error", parse_status == :error, "status=#{parse_status.inspect}")

lines = File.file?(log) ? File.readlines(log, chomp: true).map { |l| JSON.parse(l) } : []
refusals = lines.select { |l| l["kind"] == "refusal" }
ok &&= note(rows, "refusal-present", refusals.size >= 2, "n=#{refusals.size}")
reasons = refusals.map { |r| r["reason"] }
ok &&= note(rows, "reasons",
            reasons.include?("graph_unreachable") && reasons.include?("sparql_parse_error"),
            reasons.inspect)
keys = %w[state_reached inconsistency restore_when restore_action]
complete = refusals.all? do |r|
  r["because"].to_s.include?("MM_OXIGRAPH_URL") &&
    r["cpcp.restoration"].is_a?(Hash) &&
    keys.all? { |k| r["cpcp.restoration"][k].to_s.strip != "" }
end
ok &&= note(rows, "restoration-complete", complete,
            refusals.map { |r| r["cpcp.restoration"] }.inspect)

puts "plant | ok | detail"
puts "------|----|--------"
rows.each { |r| puts "#{r['plant']} | #{r['ok']} | #{r['detail']}" }
puts ok ? "plant projection-unreachable: OK" : "plant projection-unreachable: FAIL"
exit(ok ? 0 : 1)
