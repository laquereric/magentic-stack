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

lines = File.file?(log) ? File.readlines(log, chomp: true).map { |l| JSON.parse(l) } : []
refusal = lines.reverse.find { |l| l["kind"] == "refusal" }
ok &&= note(rows, "refusal-present", !refusal.nil?, "n=#{lines.size}")
if refusal
  rest = refusal["cpcp.restoration"]
  keys = %w[state_reached inconsistency restore_when restore_action]
  ok &&= note(rows, "reason", refusal["reason"] == "graph_unreachable", refusal["reason"].inspect)
  ok &&= note(rows, "because-names-offender",
              refusal["because"].to_s.include?("MM_OXIGRAPH_URL"),
              refusal["because"].inspect)
  ok &&= note(rows, "restoration-complete",
              rest.is_a?(Hash) && keys.all? { |k| rest[k].to_s.strip != "" },
              rest.inspect)
else
  ok &&= note(rows, "reason", false, "no refusal")
  ok &&= note(rows, "because-names-offender", false, "no refusal")
  ok &&= note(rows, "restoration-complete", false, "no refusal")
end

puts "plant | ok | detail"
puts "------|----|--------"
rows.each { |r| puts "#{r['plant']} | #{r['ok']} | #{r['detail']}" }
puts ok ? "plant projection-unreachable: OK" : "plant projection-unreachable: FAIL"
exit(ok ? 0 : 1)
