# frozen_string_literal: true

require "rails-cpcp"
require "socket"
require "json"

# The things a naive client gets wrong, each against a throwaway seam on
# loopback. Nothing here reaches the network beyond 127.0.0.1, and nothing here
# needs a gem: webrick left the stdlib, and a client library that made its own
# tests depend on a server library would be a poor advertisement for itself.
RSpec.describe RailsCpcp::Client do
  # A one-request HTTP server. Returns [base_url, thread, captured] where
  # captured receives the parsed request body once it arrives.
  def seam(status: 200, body: "{}")
    server = TCPServer.new("127.0.0.1", 0)
    captured = {}
    thread = Thread.new do
      socket = server.accept
      request = +""
      request << socket.gets until request.end_with?("\r\n\r\n")
      length = request[/content-length:\s*(\d+)/i, 1].to_i
      captured[:body] = length.positive? ? socket.read(length) : nil
      captured[:head] = request.lines.first.to_s.strip
      socket.print("HTTP/1.1 #{status}\r\nContent-Type: application/json\r\n" \
                   "Content-Length: #{body.bytesize}\r\nConnection: close\r\n\r\n#{body}")
      socket.close
    rescue StandardError
      nil
    ensure
      server.close
    end
    ["http://127.0.0.1:#{server.addr[1]}/_cpcp", thread, captured]
  end

  it "reads the CID and lists what the seam publishes" do
    base, thread, = seam(body: { operations: [{ name: "a.list" }, { name: "b.get" }] }.to_json)
    out = described_class.discover(base)
    thread.join(2)
    expect(out[:ok]).to be true
    expect(out[:operations]).to eq %w[a.list b.get]
  end

  it "reads a refusal nested under error" do
    base, thread, = seam(body: { ok: false,
                                 error: { reason: "unknown_operation", because: "no such" } }.to_json)
    out = described_class.pull(base, "nope")
    thread.join(2)
    expect(out[:ok]).to be false
    expect(out[:reason]).to eq :unknown_operation
    expect(out[:because]).to eq "no such"
  end

  it "reads a refusal flat at the top level" do
    # Both shapes are live upstream and deliberately not unified. A client that
    # handles one is broken against half the seams.
    base, thread, = seam(body: { ok: false, reason: "unknown_store", because: "vault" }.to_json)
    out = described_class.pull(base, "x.y")
    thread.join(2)
    expect(out[:reason]).to eq :unknown_store
  end

  it "reads the body on a non-200" do
    # Status and envelope are two channels; branching on status loses the reason.
    base, thread, = seam(status: 503, body: { ok: false, reason: "graph_unreachable" }.to_json)
    out = described_class.pull(base, "x.y")
    thread.join(2)
    expect(out[:reason]).to eq :graph_unreachable
    expect(out[:http]).to eq 503
  end

  it "refuses an unreachable seam as data, never as an exception" do
    out = described_class.pull("http://127.0.0.1:1/_cpcp", "x.y")
    expect(out[:ok]).to be false
    expect(out[:reason]).to eq :unreachable
    expect(out[:because]).to be_a(String)
  end

  it "refuses a PUSH with no operationId before sending it" do
    expect(described_class.push("http://127.0.0.1:1/_cpcp", "x.create", {}, nil)[:reason])
      .to eq :operation_id_required
  end

  it "puts the operationId on the wire" do
    base, thread, captured = seam(body: { ok: true, result: {} }.to_json)
    described_class.push(base, "x.create", { "a" => 1 }, "intent-1")
    thread.join(2)
    sent = JSON.parse(captured[:body])
    expect(sent["operationId"]).to eq "intent-1"
    expect(sent["method"]).to eq "x.create"
    expect(sent["jsonrpc"]).to eq "2.0"
  end

  it "refuses non-object params locally rather than sending them" do
    [nil, "s", 42, [1]].each do |bad|
      expect(described_class.pull("http://127.0.0.1:1/_cpcp", "x.y", bad)[:reason])
        .to eq(:unparseable_json)
    end
  end

  it "derives a stable intent from the payload" do
    # Same bytes, same intent: a browser double-submit stops being two writes
    # without anyone having to track a token.
    a = described_class.intent_for("apply", "some prose")
    expect(a).to eq described_class.intent_for("apply", "some prose")
    expect(a).not_to eq described_class.intent_for("apply", "other prose")
    expect(a).to start_with "sha256:"
  end

  it "passes a success envelope through with its result" do
    base, thread, = seam(body: { ok: true, result: { "count" => 2 } }.to_json)
    out = described_class.pull(base, "x.list")
    thread.join(2)
    expect(out[:ok]).to be true
    expect(out[:result]).to eq("count" => 2)
  end
end
