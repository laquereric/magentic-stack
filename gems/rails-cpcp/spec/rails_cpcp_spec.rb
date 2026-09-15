# frozen_string_literal: true
require "rails-cpcp"
require "tmpdir"
require "fileutils"

RSpec.describe RailsCpcp do
  before do
    @refusal_dir = Dir.mktmpdir("cpcp-refusals")
    ENV["CPCP_REFUSAL_LOG"] = File.join(@refusal_dir, "refusals.jsonl")
    ENV["CPCP_REFUSAL_HEARTBEAT"] = File.join(@refusal_dir, "observer.json")
    ENV["CPCP_CALL_LOG"] = File.join(@refusal_dir, "calls.jsonl")
    RailsCpcp::Registry.reset!
    RailsCpcp.reset_not_durable_observation!
    RailsCpcp.idempotency_store = RailsCpcp::MemoryIdempotency.new
    RailsCpcp.base_iri = "https://test.cpcp"
    RailsCpcp.project(model: "Note") do
      operation "note.list", direction: :pull, result: :collection,
        via: ->(_p, _c) { [{ "@id" => "https://test.cpcp/note/1", "title" => "a" }] }
      operation "note.get", direction: :pull, params: %w[id],
        via: ->(p, _c) { { "@id" => p["id"], "title" => "a" } }
      operation "note.create", direction: :push, params: %w[title],
        via: ->(p, _c) { { "@id" => "https://test.cpcp/note/2", "title" => p["title"] } }
    end
  end

  after { FileUtils.remove_entry(@refusal_dir) if @refusal_dir && File.directory?(@refusal_dir) }

  it "emits a gen_ai invoke_agent span at /_cpcp without prompts" do
    span_path = File.join(@refusal_dir, "spans.jsonl")
    ENV["CPCP_GENAI_SPAN_LOG"] = span_path
    r = RailsCpcp::Dispatcher.call({ "method" => "note.list", "id" => 1 })
    expect(r["ok"]).to be true
    lines = File.readlines(span_path)
    expect(lines.length).to eq(1)
    rec = JSON.parse(lines.first)
    span = rec["gen_ai_span"]
    expect(span["attributes"]["gen_ai.operation.name"]).to eq("invoke_agent")
    expect(span["attributes"]["rpc.method"]).to eq("note.list")
    expect(span["name"]).to eq("invoke_agent note.list")
    expect(span["kind"]).to eq("SERVER")
    expect(span["attributes"].keys).not_to include("prompt", "messages", "gen_ai.input.messages")
  ensure
    ENV.delete("CPCP_GENAI_SPAN_LOG")
  end

  it "marks a refusal span ERROR and still never raises" do
    span_path = File.join(@refusal_dir, "spans-err.jsonl")
    ENV["CPCP_GENAI_SPAN_LOG"] = span_path
    r = RailsCpcp::Dispatcher.call({ "method" => "nope", "id" => 2 })
    expect(r["ok"]).to be false
    span = JSON.parse(File.read(span_path))["gen_ai_span"]
    expect(span["status"]["code"]).to eq("ERROR")
    expect(span["attributes"]["error.type"]).to eq("unknown_operation")
  ensure
    ENV.delete("CPCP_GENAI_SPAN_LOG")
  end

  it "drops forbidden content keys from span attributes" do
    span = RailsCpcp::GenaiSpan.build(
      operation: "invoke_agent",
      suffix: "note.create",
      kind: "SERVER",
      traceparent: nil,
      ok: true,
      reason: nil,
      attributes: { "prompt" => "SECRET", "rpc.method" => "note.create" },
      duration_ms: 1
    )
    expect(span["attributes"]).not_to have_key("prompt")
    expect(span["attributes"]["rpc.method"]).to eq("note.create")
    expect(span["attributes"]["gen_ai.operation.name"]).to eq("invoke_agent")
  end

  it "projects a CID with directions from declared operations" do
    doc = RailsCpcp::Cid.document
    dirs = doc["operations"].to_h { |o| [o["name"], o["direction"]] }
    expect(dirs["note.list"]).to eq("PULL")
    expect(dirs["note.create"]).to eq("PUSH")
    expect(doc["operations"].map { |o| o["@id"] }).to include("https://test.cpcp/op/note.list")
  end

  it "wraps a PULL collection as @graph in a never-raise envelope" do
    r = RailsCpcp::Dispatcher.call({ "method" => "note.list", "id" => 1 })
    expect(r["ok"]).to be true
    expect(r["result"]["@graph"].length).to eq(1)
    expect(r["@context"]).to be_a(Hash)
  end

  it "fails closed (never raises) on unknown operation" do
    r = RailsCpcp::Dispatcher.call({ "method" => "nope", "id" => 2 })
    expect(r["ok"]).to be false
    expect(r["error"]["reason"]).to eq("unknown_operation")
  end

  it "requires operationId for PUSH and is idempotent" do
    no_id = RailsCpcp::Dispatcher.call({ "method" => "note.create", "params" => { "title" => "x" }, "id" => 3 })
    expect(no_id["ok"]).to be false
    expect(no_id["error"]["reason"]).to eq("operation_id_required")

    call = { "method" => "note.create", "operationId" => "op-1", "params" => { "title" => "x" }, "id" => 4 }
    first = RailsCpcp::Dispatcher.call(call)
    second = RailsCpcp::Dispatcher.call(call)
    expect(first["ok"]).to be true
    expect(first.dig("result", "replayed")).not_to eq(true)
    expect(second["ok"]).to be true
    expect(second.dig("result", "replayed")).to eq(true)
    expect(second["result"].keys).to include("replayed")
  end

  # AN operationId IDENTIFIES AN INTENT, NOT A ROW IN A SHARED NAMESPACE.
  #
  # The store was keyed on the id alone, so one id used for two DIFFERENT methods
  # returned the first method's result -- as a replay, with ok: true, and nothing
  # in the envelope to say the answer belonged elsewhere. Found when a harness
  # reused one id across acia.publish and mind.derive: publish executed and
  # stored, derive was handed publish's receipt and never ran. Both looked fine.
  it "does not hand one method's receipt to another that reused the operationId" do
    RailsCpcp.project(model: "Memo") do
      operation "memo.create", direction: :push, params: %w[title],
        via: ->(p, _c) { { "@id" => "https://test.cpcp/memo/1", "title" => p["title"] } }
    end

    shared = "same-id-two-methods"
    note = RailsCpcp::Dispatcher.call(
      { "method" => "note.create", "operationId" => shared, "params" => { "title" => "n" }, "id" => 1 }
    )
    memo = RailsCpcp::Dispatcher.call(
      { "method" => "memo.create", "operationId" => shared, "params" => { "title" => "m" }, "id" => 2 }
    )

    expect(note.dig("result", "replayed")).not_to eq(true)
    # A DIFFERENT operation must run, not replay the first one's answer.
    expect(memo.dig("result", "replayed")).not_to eq(true)
    expect(memo.dig("result", "@id")).to eq("https://test.cpcp/memo/1")

    # The same method with the same id still replays: the guarantee that was
    # always intended is untouched.
    again = RailsCpcp::Dispatcher.call(
      { "method" => "memo.create", "operationId" => shared, "params" => { "title" => "m" }, "id" => 3 }
    )
    expect(again.dig("result", "replayed")).to eq(true)
  end

  # A RECEIPT MUST OUTLIVE THE PROCESS THAT ISSUED IT -- including across this
  # change. Entries written under the old bare-id key are still honoured, or a
  # legitimate retry of an older operationId would execute a second time, which
  # is the failure the store exists to prevent.
  it "still replays a receipt stored under the pre-change bare key" do
    RailsCpcp.idempotency_store.put("legacy-op", { "@id" => "https://test.cpcp/note/legacy" })
    replayed = RailsCpcp::Dispatcher.call(
      { "method" => "note.create", "operationId" => "legacy-op", "params" => { "title" => "x" }, "id" => 9 }
    )
    expect(replayed["ok"]).to be true
    expect(replayed.dig("result", "replayed")).to eq(true)
  end

  # THE FALLBACK RETIRES ITSELF. A legacy hit copies the receipt to the scoped
  # key, so the next call for that id finds it there and the id stops being
  # reachable by a different method. Without this the legacy namespace would stay
  # exactly as large as the day it was frozen.
  it "moves a legacy receipt to the scoped key so the id stops crossing methods" do
    store = RailsCpcp.idempotency_store
    store.put("moving-op", { "@id" => "https://test.cpcp/note/moving" })

    first = RailsCpcp::Dispatcher.call(
      { "method" => "note.create", "operationId" => "moving-op", "params" => { "title" => "x" }, "id" => 10 }
    )
    expect(first.dig("result", "replayed")).to eq(true)

    # Now scoped, so the SAME id used by a DIFFERENT method no longer finds it.
    expect(store.get("note.create moving-op")).not_to be_nil

    RailsCpcp.project(model: "Other") do
      operation "other.create", direction: :push, params: %w[title],
        via: ->(p, _c) { { "@id" => "https://test.cpcp/other/1", "title" => p["title"] } }
    end
    other = RailsCpcp::Dispatcher.call(
      { "method" => "other.create", "operationId" => "moving-op", "params" => { "title" => "y" }, "id" => 11 }
    )
    # STILL the legacy row, which is why the fallback cannot be dropped yet --
    # this is the residual crossover, stated by a test rather than a comment.
    expect(other.dig("result", "replayed")).to eq(true)
  end

  it "gives empty body and unparseable body distinct reasons" do
    empty = RailsCpcp::RequestBody.read("")
    expect(empty.error).to eq("empty_body")
    bad = RailsCpcp::RequestBody.read("{")
    expect(bad.error).to eq("unparseable_json")
    ok = RailsCpcp::RequestBody.read(%({ "method": "nope" }))
    expect(ok.error).to be_nil
    expect(ok.payload["method"]).to eq("nope")
  end

  it "does not report unparseable JSON as unknown_operation" do
    parsed = RailsCpcp::RequestBody.read("not-json")
    expect(parsed.error).to eq("unparseable_json")
    dispatched = RailsCpcp::Dispatcher.call({ "method" => "nope", "id" => 9 })
    expect(dispatched.dig("error", "reason")).to eq("unknown_operation")
    expect(parsed.error).not_to eq(dispatched.dig("error", "reason"))
  end

  it "reports missing required params" do
    r = RailsCpcp::Dispatcher.call({ "method" => "note.get", "params" => {}, "id" => 5 })
    expect(r["ok"]).to be false
    expect(r["error"]["reason"]).to eq("missing_params")
  end

  describe "ADR 0054 refusal observer" do
    it "records a dispatcher Envelope.fail on the durable log" do
      RailsCpcp::Dispatcher.call({ "method" => "nope", "id" => 99 })
      expect(RailsCpcp::RefusalLog.ran?).to be true
      reasons = RailsCpcp::RefusalLog.refusals.map { |r| r["reason"] }
      expect(reasons).to include("unknown_operation")
    end

    it "distinguishes observer-never-ran from zero refusals" do
      ENV["CPCP_REFUSAL_LOG"] = File.join(@refusal_dir, "never.jsonl")
      ENV["CPCP_REFUSAL_HEARTBEAT"] = File.join(@refusal_dir, "never-observer.json")
      expect(File.file?(ENV["CPCP_REFUSAL_HEARTBEAT"])).to be false
      expect(RailsCpcp::RefusalLog.ran?).to be false
      expect(RailsCpcp::RefusalLog.refusals).to eq([])

      RailsCpcp::RefusalLog.heartbeat!
      expect(RailsCpcp::RefusalLog.ran?).to be true
      expect(RailsCpcp::RefusalLog.refusals).to eq([])
    end

    it "records a nested handler {ok:false} wrapped in Envelope.ok" do
      RailsCpcp.project(model: "Nested") do
        operation "nested.refuse", direction: :pull,
          via: ->(_p, _c) { { ok: false, reason: "open_failed", because: "boom" } }
      end
      RailsCpcp::Dispatcher.call({ "method" => "nested.refuse", "id" => 7 })
      reasons = RailsCpcp::RefusalLog.refusals.map { |r| r["reason"] }
      expect(reasons).to include("open_failed")
    end

    it "records once that MemoryIdempotency is not durable" do
      File.write(ENV.fetch("CPCP_REFUSAL_LOG"), "")
      RailsCpcp.reset_not_durable_observation!
      RailsCpcp::MemoryIdempotency.new
      RailsCpcp::MemoryIdempotency.new
      reasons = RailsCpcp::RefusalLog.refusals.map { |r| r["reason"] }
      expect(reasons.count("idempotency_not_durable")).to eq(1)
      row = RailsCpcp::RefusalLog.refusals.find { |r| r["reason"] == "idempotency_not_durable" }
      expect(row["cpcp.restoration"]).to include("state_reached", "inconsistency", "restore_when", "restore_action")
    end

    it "writes cpcp.restoration only when all four members are present" do
      RailsCpcp::RefusalLog.record(reason: "x", because: "y", source: "spec",
                                   restoration: { "state_reached" => "only" })
      RailsCpcp::RefusalLog.record(
        reason: "y", because: "z", source: "spec",
        restoration: {
          "state_reached" => "a", "inconsistency" => "b",
          "restore_when" => "c", "restore_action" => "d"
        }
      )
      rows = RailsCpcp::RefusalLog.refusals
      half = rows.find { |r| r["reason"] == "x" }
      full = rows.find { |r| r["reason"] == "y" }
      expect(half.key?("cpcp.restoration")).to be false
      expect(full["cpcp.restoration"]).to eq(
        "state_reached" => "a", "inconsistency" => "b",
        "restore_when" => "c", "restore_action" => "d"
      )
      expect(full["otel.scope.version"]).to eq("1")
      expect(full.key?("trace_id")).to be false
    end

    it "does not raise when the log path is unwritable" do
      blocker = File.join(@refusal_dir, "blocker")
      File.write(blocker, "not-a-dir")
      ENV["CPCP_REFUSAL_LOG"] = File.join(blocker, "refusals.jsonl")
      ENV["CPCP_REFUSAL_HEARTBEAT"] = File.join(blocker, "observer.json")
      expect {
        RailsCpcp::RefusalLog.record(reason: "x", because: "y", source: "spec")
        RailsCpcp::Dispatcher.call({ "method" => "nope", "id" => 1 })
      }.not_to raise_error
    end

    it "rotates explicitly with a loud marker, keeping generations" do
      3.times { |i| RailsCpcp::RefusalLog.record(reason: "r#{i}", because: "b", source: "spec") }
      res = RailsCpcp::RefusalLog.rotate!
      expect(res["rotated"]).to be true
      expect(res["dropped_lines"]).to be >= 3
      expect(File.file?(ENV["CPCP_REFUSAL_LOG"] + ".1")).to be true
      marker = JSON.parse(File.readlines(ENV["CPCP_REFUSAL_LOG"], chomp: true).first)
      expect(marker["kind"]).to eq("floor_rotated")
      expect(marker["dropped_lines"]).to eq(res["dropped_lines"])
      # Markers are not refusals.
      expect(RailsCpcp::RefusalLog.refusals).to eq([])
    end

    it "caps generations and reports status without raising" do
      2.times { RailsCpcp::RefusalLog.record(reason: "x", because: "y", source: "spec") }
      5.times { RailsCpcp::RefusalLog.rotate! }
      gens = (1..5).map { |i| ENV["CPCP_REFUSAL_LOG"] + ".#{i}" }.select { |g| File.file?(g) }
      expect(gens.size).to be <= 3
      st = RailsCpcp::RefusalLog.status
      expect(st["exists"]).to be true
      expect(st["heartbeat"]).to be true
      expect(st["last_at"]).not_to be_nil
      expect(st["generations"].size).to be <= 4
    end

    it "rotate! on a missing file reports absent, never raises" do
      FileUtils.rm_f(ENV["CPCP_REFUSAL_LOG"])
      expect(RailsCpcp::RefusalLog.rotate!).to eq("rotated" => false, "reason" => "absent")
    end
  end

  describe "R4 call log (success path, not a journal kind)" do
    it "records Envelope.ok PULL and PUSH, and announces writer_started first" do
      RailsCpcp::Dispatcher.call({ "method" => "note.list", "id" => 1 })
      RailsCpcp::Dispatcher.call(
        { "method" => "note.create", "params" => { "title" => "n" }, "id" => 2, "operationId" => "op-1" }
      )
      kinds = File.readlines(ENV["CPCP_CALL_LOG"], chomp: true).map { |l| JSON.parse(l)["kind"] }
      expect(kinds.first).to eq("writer_started")
      expect(RailsCpcp::CallLog.writer_started_at).not_to be_nil
      dirs = RailsCpcp::CallLog.calls.map { |c| [c["method"], c["direction"], c["replayed"]] }
      expect(dirs).to include(["note.list", "pull", false], ["note.create", "push", false])
    end

    it "does not count Envelope.fail" do
      RailsCpcp::Dispatcher.call({ "method" => "nope", "id" => 1 })
      expect(RailsCpcp::CallLog.calls).to eq([])
    end

    it "does not count nested {ok:false} wrapped in Envelope.ok" do
      RailsCpcp.project(model: "NestedCall") do
        operation "nested.refuse", direction: :pull,
          via: ->(_p, _c) { { ok: false, reason: "open_failed", because: "boom" } }
      end
      RailsCpcp::Dispatcher.call({ "method" => "nested.refuse", "id" => 7 })
      expect(RailsCpcp::CallLog.calls.map { |c| c["method"] }).not_to include("nested.refuse")
    end

    it "counts PUSH replay as traffic and marks replayed" do
      call = { "method" => "note.create", "params" => { "title" => "n" }, "id" => 2, "operationId" => "op-r" }
      RailsCpcp::Dispatcher.call(call)
      RailsCpcp::Dispatcher.call(call)
      replays = RailsCpcp::CallLog.calls.select { |c| c["replayed"] == true }
      expect(replays.length).to eq(1)
      expect(replays.first["direction"]).to eq("push")
    end

    it "carries writer_started across rotate! so a ratio cannot backfill" do
      RailsCpcp::Dispatcher.call({ "method" => "note.list", "id" => 1 })
      started = RailsCpcp::CallLog.writer_started_at
      res = RailsCpcp::CallLog.rotate!
      expect(res["rotated"]).to be true
      expect(RailsCpcp::CallLog.writer_started_at).to eq(started)
      expect(RailsCpcp::CallLog.calls).to eq([])
    end

    it "does not raise when the call log path is unwritable" do
      blocker = File.join(@refusal_dir, "call-blocker")
      File.write(blocker, "not-a-dir")
      ENV["CPCP_CALL_LOG"] = File.join(blocker, "calls.jsonl")
      expect {
        RailsCpcp::Dispatcher.call({ "method" => "note.list", "id" => 1 })
      }.not_to raise_error
    end
  end

  # The bug these hold shut cost a live receipt page its name field and raised
  # nothing anywhere: Array() on a Hash returns [[k, v], ...], so an operation
  # declaring result: :collection while returning an object envelope published a
  # graph of PAIRS. Valid JSON, no refusal, and callers read nil.
  describe "Envelope @graph" do
    it "puts a Hash in the graph as ONE node, not as a list of its pairs" do
      body = RailsCpcp::Envelope.ok(id: 1, collection: true,
                                    result: { "ok" => true, "entries" => [{ "name" => "n" }] })["result"]

      expect(body["@graph"]).to eq([{ "ok" => true, "entries" => [{ "name" => "n" }] }])
      # The shape the old code produced, written out so the regression is unmistakable.
      expect(body["@graph"]).not_to eq([["ok", true], ["entries", [{ "name" => "n" }]]])
      expect(body["@graph"].first["entries"].first["name"]).to eq "n"
    end

    it "leaves an array of nodes alone" do
      nodes = [{ "id" => 1 }, { "id" => 2 }]
      expect(RailsCpcp::Envelope.ok(id: 1, result: nodes, collection: true)["result"]["@graph"]).to eq nodes
    end

    it "makes an empty graph from nil rather than a node of nothing" do
      expect(RailsCpcp::Envelope.ok(id: 1, result: nil, collection: true)["result"]["@graph"]).to eq []
    end

    it "does not touch a non-collection result" do
      expect(RailsCpcp::Envelope.ok(id: 1, result: { "digest" => "sha256:x" })["result"])
        .to eq("digest" => "sha256:x")
    end
  end
end
