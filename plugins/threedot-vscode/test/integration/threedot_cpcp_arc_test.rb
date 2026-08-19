#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Integration test for the arc: user -> VS Code -> 3dot plugin -> Rails threedot features.
#
# The 3dot plugin's data plane (src/cpcp.ts) is bootstrap -> discover -> pull -> push over a
# BACK's single /_cpcp seam. VS Code's editor shell is not browser-automatable, so this test
# drives that SAME CPCP arc with mmg-browser (headless Chrome, BiDi): it navigates to the BACK
# origin and runs same-origin fetch() calls to /_cpcp -- exactly what cpcp.ts does -- asserting
# behaviors from plugins/threedot-vscode/docs/DEMO_USE_CASES.md against a live rails-cpcp BACK.
#
# Run inside the mmg-browser gem bundle so require "mmg-browser" resolves:
#   BACK_URL=http://127.0.0.1:PORT bundle exec ruby threedot_cpcp_arc_test.rb
require "json"
require "mmg-browser"

BACK = ENV.fetch("BACK_URL", "http://127.0.0.1:3000")
$fails = []

def check(name, cond, detail = "")
  ok = !!cond
  line = (ok ? "  ok   " : "  FAIL ") + name
  line += "  :: #{detail}"[0, 200] unless detail.to_s.empty?
  puts line
  $fails << name unless ok
  ok
end

def rpc_js(method, params = {}, op = nil)
  body = { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params }
  body["operationId"] = op if op
  "(async()=>{const r=await fetch('/_cpcp/rpc',{method:'POST',headers:{'Content-Type':'application/json'}," \
  "body:JSON.stringify(#{JSON.generate(body)})});const j=await r.json();return JSON.stringify({status:r.status,body:j});})()"
end

def get_js(path)
  "(async()=>{const r=await fetch('#{path}');let b=null;try{b=await r.json();}catch(e){b=await r.text();}" \
  "return JSON.stringify({status:r.status,body:b});})()"
end

def run
  Mmg::Browser.with_session(engine: :chrome, headless: true, profile: nil) do |handle, session|
    ctx = session.browsing_context_create.dig(:result, "context")
    return check("browser-context", false, "no context") unless ctx
    # Land on the BACK origin so all /_cpcp fetches are same-origin (no CORS) -- the plugin
    # discovers a back URL then talks to it; here the browser IS on that origin.
    session.browsing_context_navigate(ctx, "#{BACK}/up")

    ev = lambda do |js|
      raw = session.script_evaluate(ctx, js).dig(:result, "result", "value")
      raw ? JSON.parse(raw) : nil
    end

    puts "== arc: user -> VS Code -> 3dot plugin -> Rails threedot features (BACK #{BACK}) =="

    # UC-discover: the plugin discovers the live CID (GET /_cpcp/cid.json).
    cid = ev.call(get_js("/_cpcp/cid.json"))
    check("discover: GET /_cpcp/cid.json 200", cid && cid["status"] == 200, cid && cid["status"])

    # UC-capabilities: /_cpcp/up advertises the operation surface (Activity view / completions).
    up = ev.call(get_js("/_cpcp/up"))
    ops = (up && up["body"].is_a?(Hash)) ? (up["body"]["operations"] || []) : []
    check("capabilities: note.* + l8.* advertised", (%w[note.list note.create] - ops).empty?, ops.length)

    # UC-read-by-reference: pull Context (note.list) -- a collection with @graph.
    list = ev.call(rpc_js("note.list"))
    graph = list && list["body"] && list["body"]["result"] && list["body"]["result"]["@graph"]
    check("pull: note.list ok + @graph array", list && list["body"]["ok"] == true && graph.is_a?(Array))

    # UC-effect: push an Effect (note.create with operationId) -- the sole write path.
    op = "arc-#{graph ? graph.length : 0}-#{BACK.bytesize}"
    c1 = ev.call(rpc_js("note.create", { "title" => "arc note", "body" => "via mmg-browser" }, op))
    r1 = c1 && c1["body"] && c1["body"]["result"]
    check("push: note.create ok + governance receipt", c1 && c1["body"]["ok"] == true && r1 && r1["governance"], r1 && r1.keys)

    before = ev.call(rpc_js("note.list"))["body"]["result"]["@graph"].length
    # UC-idempotent-replay: same operationId must NOT create a second Note.
    ev.call(rpc_js("note.create", { "title" => "arc note", "body" => "via mmg-browser" }, op))
    after = ev.call(rpc_js("note.list"))["body"]["result"]["@graph"].length
    check("idempotent replay: no second Note", before == after, "before=#{before} after=#{after}")

    # UC-diagnostic (server analog of three/missing-required): push w/o operationId is refused.
    miss = ev.call(rpc_js("note.create", { "title" => "x", "body" => "y" }))
    mreason = miss && miss["body"] && miss["body"]["error"] && miss["body"]["error"]["reason"]
    check("diagnostic: missing operationId refused (never-raise)", miss["body"]["ok"] == false && mreason == "operation_id_required", mreason)

    # UC-unknown-capability (three/unknown-capability analog): unknown op rejected.
    unk = ev.call(rpc_js("does.not.exist", {}, "u1"))
    ureason = unk && unk["body"] && unk["body"]["error"] && unk["body"]["error"]["reason"]
    check("unknown capability rejected", unk["body"]["ok"] == false && ureason == "unknown_operation", ureason)

    # UC-governance: the effect is auditable via a Level-8 governance PULL.
    jr = ev.call(rpc_js("l8.operation.journal"))
    jg = jr && jr["body"] && jr["body"]["result"] && jr["body"]["result"]["@graph"]
    check("governance: l8.operation.journal populated", jr["body"]["ok"] == true && jg.is_a?(Array) && jg.length > 0, jg && jg.length)
  end
rescue => e
  check("harness", false, "#{e.class}: #{e.message}")
end

run
puts
if $fails.empty?
  puts "ARC INTEGRATION: PASS"
  exit 0
else
  puts "ARC INTEGRATION: FAIL (#{$fails.join(', ')})"
  exit 1
end
