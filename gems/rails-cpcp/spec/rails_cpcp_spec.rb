# frozen_string_literal: true
require "rails-cpcp"
require "tmpdir"
require "fileutils"

RSpec.describe RailsCpcp do
  before do
    @refusal_dir = Dir.mktmpdir("cpcp-refusals")
    ENV["CPCP_REFUSAL_LOG"] = File.join(@refusal_dir, "refusals.jsonl")
    ENV["CPCP_REFUSAL_HEARTBEAT"] = File.join(@refusal_dir, "observer.json")
    RailsCpcp::Registry.reset!
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
  end
end
