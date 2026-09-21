# frozen_string_literal: true

require "stringio"

RSpec.describe Vv::CpcpHarness::Mcp::Stdio do
  let(:output) { StringIO.new }
  let(:log) { StringIO.new }

  def bridge
    Vv::CpcpHarness.bridge(
      seams: [seam(name: "reads", payload: pull_cid, include: ["note.list"])],
      name: "acme-agent-harness",
      transport_factory: lambda { |seam|
        Vv::CpcpHarness::FakeTransport.new(cid_payload: seam.cid_payload) do |_call|
          exchange(200, ok_envelope({ "@graph" => [] }))
        end
      }
    )[:result]
  end

  def run(*lines)
    transport = described_class.new(server: bridge.mcp_server(session_id: "sess-1"),
                                    input: StringIO.new(lines.join), output: output, log: log)
    handled = transport.run
    [handled, output.string.lines.map { |l| JSON.parse(l) }]
  end

  def frame(payload)
    "#{JSON.generate(payload)}\n"
  end

  it "answers one line-delimited frame per line" do
    handled, responses = run(
      frame({ "jsonrpc" => "2.0", "id" => 1, "method" => "server/discover", "params" => {} }),
      frame({ "jsonrpc" => "2.0", "id" => 2, "method" => "tools/list", "params" => {} })
    )

    expect(handled).to eq 2
    expect(responses.map { |r| r["id"] }).to eq [1, 2]
    expect(responses.last["result"]["tools"].first["name"]).to eq "reads_note_list"
  end

  it "writes nothing but JSON-RPC to the stream, and each response on one line" do
    _, = run(frame({ "jsonrpc" => "2.0", "id" => 1, "method" => "tools/list", "params" => {} }))

    expect(output.string.lines.length).to eq 1
    expect { JSON.parse(output.string) }.not_to raise_error
  end

  it "keeps going after a line it could not parse, and logs to stderr" do
    handled, responses = run(
      "{ not json\n",
      frame({ "jsonrpc" => "2.0", "id" => 2, "method" => "ping", "params" => {} })
    )

    expect(handled).to eq 2
    expect(responses.first["error"]["code"]).to eq Vv::CpcpHarness::Mcp::PARSE_ERROR
    expect(responses.last["result"]).to eq({})
    expect(log.string).to include "ParserError"
  end

  it "says no to a batch rather than answering half of it" do
    _, responses = run(frame([{ "jsonrpc" => "2.0", "id" => 1, "method" => "ping" }]))

    expect(responses.first["error"]["code"]).to eq Vv::CpcpHarness::Mcp::INVALID_REQUEST
    expect(responses.first["error"]["message"]).to include "batched"
  end

  it "writes no response for a notification" do
    handled, responses = run(
      frame({ "jsonrpc" => "2.0", "method" => "notifications/initialized" }),
      "\n"
    )

    expect(handled).to eq 1
    expect(responses).to be_empty
  end
end
