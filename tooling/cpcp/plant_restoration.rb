#!/usr/bin/env ruby
# frozen_string_literal: true
# Plant for gap 74. No Rails boot. Proves:
#   - a record without restoration has no cpcp.restoration (absent, not {})
#   - a complete restoration is written as one attribute key
#   - a partial restoration is DROPPED
#   - OTEL-native scope version is present
#   - fabricated fields (trace_id, span_id, container_id, SeverityNumber) absent
#   - SHACL over the restoration object (not an OTEL LogRecord) conforms

require "json"
require "fileutils"
require "tmpdir"
require "open3"

ROOT = File.expand_path("../..", __dir__)
require File.join(ROOT, "gems/rails-cpcp/lib/rails_cpcp/refusal_log")

log = File.join(Dir.tmpdir, "cpcp_refusals-rest-#{Process.pid}.jsonl")
hb  = File.join(Dir.tmpdir, "cpcp_refusal_observer-rest-#{Process.pid}.json")
FileUtils.rm_f(log)
FileUtils.rm_f(hb)
ENV["CPCP_REFUSAL_LOG"] = log
ENV["CPCP_REFUSAL_HEARTBEAT"] = hb

rows = []
ok = true
def note(rows, name, passed, detail)
  rows << { "plant" => name, "ok" => passed, "detail" => detail }
  passed
end

complete = {
  "state_reached" => "application row committed; projection schedule raised",
  "inconsistency" => "GRAPH/outbox may not match the committed row",
  "restore_when" => "drain applies a projection job for this ref",
  "restore_action" => "replay or drain pending projection jobs"
}

RailsCpcp::RefusalLog.record(reason: "no_state", because: "envelope only", source: "plant/none")
RailsCpcp::RefusalLog.record(reason: "projection_error", because: "plant", source: "plant/full",
                             restoration: complete)
RailsCpcp::RefusalLog.record(reason: "half", because: "plant", source: "plant/half",
                             restoration: { "state_reached" => "only one" })

lines = File.readlines(log, chomp: true).map { |l| JSON.parse(l) }
bare, full, half = lines

ok &&= note(rows, "absent-not-empty",
            bare.key?("cpcp.restoration") == false,
            "keys=#{bare.keys.inspect}")
ok &&= note(rows, "scope-version-native",
            bare["otel.scope.name"] == "rails-cpcp/refusal-log" &&
              bare["otel.scope.version"] == "1",
            "scope=#{bare['otel.scope.name']}/#{bare['otel.scope.version']}")
ok &&= note(rows, "complete-one-key",
            full["cpcp.restoration"] == complete,
            full["cpcp.restoration"].inspect)
ok &&= note(rows, "partial-dropped",
            half.key?("cpcp.restoration") == false,
            "keys=#{half.keys.inspect}")

fabricated = %w[trace_id span_id container_id SeverityNumber]
found = lines.flat_map { |r| fabricated.select { |k| r.key?(k) } }
ok &&= note(rows, "no-fabricated", found.empty?, found.inspect)

# SHACL on the restoration object only — not on an OTEL LogRecord.
shape = File.join(ROOT, "gems/rails-cpcp/shapes/cpcp-restoration.shacl.ttl")
data = File.join(Dir.tmpdir, "restoration-#{Process.pid}.ttl")
File.write(data, <<~TTL)
  @prefix cpcp: <https://w3id.org/cpcp/ns#> .
  @prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .
  [] a cpcp:Restoration ;
    cpcp:stateReached #{complete['state_reached'].inspect} ;
    cpcp:inconsistency #{complete['inconsistency'].inspect} ;
    cpcp:restoreWhen #{complete['restore_when'].inspect} ;
    cpcp:restoreAction #{complete['restore_action'].inspect} .
TTL

py = "/Users/ericlaquer/NoIcloud/.mm_tmp/checker-plants/.venv/bin/python"
def run_pyshacl(py, shape, data)
  Open3.capture2e(py, "-m", "pyshacl", "-s", shape, data)
end

if File.exist?(py)
  out, status = run_pyshacl(py, shape, data)
  ok &&= note(rows, "shacl-restoration-only", status.success?,
              status.success? ? "conforms" : out.lines.last(12).join)
  partial = File.join(Dir.tmpdir, "restoration-partial-#{Process.pid}.ttl")
  File.write(partial, <<~TTL)
    @prefix cpcp: <https://w3id.org/cpcp/ns#> .
    [] a cpcp:Restoration ;
      cpcp:stateReached "only one" .
  TTL
  out, status = run_pyshacl(py, shape, partial)
  ok &&= note(rows, "shacl-rejects-partial", !status.success?,
              status.success? ? "WRONG: partial conformed" : "refused (expected)")
else
  rows << { "plant" => "shacl-restoration-only", "ok" => true,
            "detail" => "SKIP pyshacl venv missing; shape file present at #{shape}" }
end

puts "PLANT TABLE"
rows.each do |r|
  flag = r["ok"] ? "OK " : "FAIL"
  puts "  #{flag}  #{r['plant']}: #{r['detail']}"
end
puts ok ? "plant restoration: OK" : "plant restoration: FAIL"
exit(ok ? 0 : 1)
