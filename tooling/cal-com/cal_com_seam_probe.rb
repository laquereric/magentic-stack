#!/usr/bin/env ruby
# frozen_string_literal: true
#
# The cal-com half of scheduling behaves, through the seam, with no network.
#
# Vv::CalCom::Cpcp.register! is the projection BACK mounts (the mind-pod
# rails_cpcp initializer calls it when defined). So every assertion below
# goes through RailsCpcp::Dispatcher rather than calling handlers directly.
# Testing a handler would prove the handler works; testing the seam proves
# the thing a caller can actually reach works.
#
# THE INVARIANTS THIS EXISTS FOR:
#
#   1. Credentials never travel in params. Every handler builds Client.new
#      with no arguments, which reads CAL_API_KEY / CAL_API_URL from the
#      environment. A seam that accepted a token in params would land
#      secrets in the idempotency store and the call log.
#   2. Writes name their intent. Every push requires operationId; a push
#      without one is refused before anything is performed.
#   3. Reads need no intent, but they still need their identifiers --
#      enforced by the dispatcher, before any handler runs.
#
# OFFLINE BY CONSTRUCTION. The probe dispatches only calls that terminate
# before the wire (unknown operation, missing params, missing operationId)
# plus the two local handlers (embed.url, webhook.verify), which never
# dial by construction. Anything that would perform HTTPS is covered by
# the gem specs with an injected FakeTransport instead.
#
# Logs go to tempfiles: the dispatcher observes every call into the
# refusal/call JSONL sinks, and the probe must not write into the repo.

require "json"
require "tmpdir"

ROOT = File.expand_path("../..", __dir__)
$LOAD_PATH.unshift File.join(ROOT, "gems/rails-cpcp/lib")
$LOAD_PATH.unshift File.join(ROOT, "gems/vv-cal-com/lib")

LOGDIR = Dir.mktmpdir("cal-com-probe")
ENV["CPCP_REFUSAL_LOG"] = File.join(LOGDIR, "refusals.jsonl")
ENV["CPCP_REFUSAL_HEARTBEAT"] = File.join(LOGDIR, "heartbeat.json")
ENV["CPCP_CALL_LOG"] = File.join(LOGDIR, "calls.jsonl")

require "rails_cpcp/registry"
require "rails_cpcp/dsl"
require "rails_cpcp/idempotency"
require "rails_cpcp/envelope"
require "rails_cpcp/replay"
require "rails_cpcp/refusal_log"
require "rails_cpcp/call_log"
require "rails_cpcp/genai_span"
require "rails_cpcp/dispatcher"
require "vv-cal-com"

RailsCpcp.idempotency_store = RailsCpcp::MemoryIdempotency.new

CHECKS = []

def check(name, ok, detail = "")
  CHECKS << { "assertion" => name, "ok" => !!ok, "detail" => detail.to_s[0, 220] }
  ok
end

def dispatch(method, params = {})
  RailsCpcp::Dispatcher.call({ "id" => CHECKS.length + 1, "method" => method, "params" => params })
end

def main
  r = Vv::CalCom::Cpcp.register!
  check("registration-ok", r[:ok] == true, r.inspect[0, 140])

  names = RailsCpcp::Registry.operations.map(&:name)
  missing = Vv::CalCom::Cpcp::OPERATIONS - names
  check("all-operations-resolve", missing.empty?, missing.inspect)
  # Nothing registered beyond OPERATIONS: a project block added without
  # updating OPERATIONS is a seam nobody listed, which reads as covered.
  extra = names - Vv::CalCom::Cpcp::OPERATIONS
  check("no-unlisted-operations", extra.empty?, extra.inspect)

  # The dispatcher is the thing a caller reaches, so unknown names fail
  # here with a typed refusal rather than anywhere deeper.
  r = dispatch("booking.nope", {})
  check("unknown-operation-refuses",
        r["ok"] == false && r.dig("error", "reason") == "unknown_operation",
        r.to_json[0, 140])

  # WRITES NAME THEIR INTENT. A push with complete params but no
  # operationId anywhere (neither top-level nor in params) is refused
  # before any handler runs -- nothing is performed unnamed.
  r = dispatch("booking.create",
               { "operationId" => nil, "eventTypeId" => 123, "start" => "2026-09-20T15:00:00Z" })
  check("push-without-operation-id-refuses",
        r["ok"] == false && r.dig("error", "reason") == "operation_id_required",
        r.to_json[0, 140])

  # ...and the refusal names what is missing, so a caller can repair it.
  r = dispatch("slot.list", { "eventTypeId" => 10, "start" => "2026-09-20" })
  check("missing-params-are-named",
        r["ok"] == false && r.dig("error", "reason") == "missing_params" &&
          r.dig("error", "because").to_s.include?("end"),
        r.to_json[0, 140])

  # Identifier gating happens in the dispatcher, before the wire: no uid,
  # no handler, no dial.
  r = dispatch("booking.get", {})
  check("get-without-uid-refuses-before-the-wire",
        r["ok"] == false && r.dig("error", "reason") == "missing_params",
        r.to_json[0, 140])

  # A LOCAL READ, end to end through the seam. embed.url never dials by
  # construction; the envelope proves the projection is mounted.
  r = dispatch("embed.url", { "username" => "ada", "eventSlug" => "intro" })
  check("embed-url-resolves",
        r["ok"] == true && r["result"][:ok] == true &&
          r["result"][:data] == "https://cal.com/ada/intro",
        r.to_json[0, 160])

  # A LOCAL WRITE-FREE VERIFY, end to end. Signed here, verified through
  # the seam; the dispatcher envelope stays ok while the inner result
  # carries the Cal.com verdict.
  secret = "probe-webhook-secret"
  body = JSON.generate(
    "triggerEvent" => "BOOKING_CREATED",
    "createdAt" => "2026-09-17T00:00:00.000Z",
    "payload" => { "uid" => "b1", "status" => "ACCEPTED" }
  )
  sig = Vv::CalCom::Webhooks.signed_payload(secret, body)
  r = dispatch("webhook.verify",
               { "body" => body, "signature" => sig, "signingSecret" => secret })
  check("webhook-verify-accepts-a-locally-signed-payload",
        r["ok"] == true && r["result"][:ok] == true &&
          r["result"][:type] == "BOOKING_CREATED" && r["result"][:event_id] == "b1",
        r.to_json[0, 180])

  # A forgery is a refusal, not a crash -- and the dispatcher envelope
  # still reports the call itself as handled.
  r = dispatch("webhook.verify",
               { "body" => body, "signature" => "0" * 64, "signingSecret" => secret })
  check("webhook-verify-refuses-a-forgery",
        r["ok"] == true && r["result"][:ok] == false &&
          r["result"][:reason] == :webhook_invalid,
        r.to_json[0, 180])

  # CREDENTIALS NEVER TRAVEL IN PARAMS. The seam's contract is that auth
  # comes from the environment: no projected operation declares a token,
  # key, or secret param, so there is nowhere to put one.
  secretish = Vv::CalCom::Cpcp::OPERATIONS.flat_map do |op|
    proj = RailsCpcp::Registry.find(op)
    Array(proj&.params).select { |p| p.match?(/token|secret|api_?key|password/i) }
  end
  check("no-operation-takes-credentials", secretish.empty?, secretish.inspect)

  # FAILS CLOSED: a probe that checked nothing must not read as coverage.
  check("probe-checked-something", !CHECKS.empty?, "#{CHECKS.length} checks")

  ok = CHECKS.all? { |c| c["ok"] }
  CHECKS.each { |c| puts format("  %s %s -- %s", c["ok"] ? "ok" : "FAIL", c["assertion"], c["detail"]) }
  puts "population: #{CHECKS.length} examined, 0 skipped"
  puts "cal-com seam: #{ok ? 'OK' : 'FAIL'}"
  exit(ok ? 0 : 1)
end

main
