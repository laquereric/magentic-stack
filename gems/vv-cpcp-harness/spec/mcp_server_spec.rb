# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Mcp::Server do
  let(:transports) { {} }
  let(:journal) { [] }

  def factory
    lambda do |seam|
      transports[seam.name] = Vv::CpcpHarness::FakeTransport.new(cid_payload: seam.cid_payload) do |call|
        case call[:method]
        when "note.list"
          exchange(200, ok_envelope({ "@graph" => [{ "type" => "Note", "title" => "hello" }] }))
        when "note.create"
          exchange(200, ok_envelope({ "type" => "Note", "id" => "note:1",
                                      "title" => call[:params]["title"] }))
        else
          exchange(200, nested_refusal("unknown_operation", "no such method"))
        end
      end
    end
  end

  def bridge(**options)
    result = Vv::CpcpHarness.bridge(
      seams: [seam(name: "reads", payload: pull_cid, include: ["note.list"]),
              seam(name: "writes", payload: push_cid, include: ["note.create"])],
      name: "acme-agent-harness",
      transport_factory: factory,
      journal_sink: ->(e) { journal << e },
      **options
    )
    expect(result[:ok]).to be true
    result[:result]
  end

  def server(**options)
    described_class.new(bridge: bridge(**options), session_id: "sess-1")
  end

  def request(method, params = {}, id: 1, version: Vv::CpcpHarness::Mcp::MODERN,
              client: { "name" => "claude-code", "version" => "2.0" })
    meta = {}
    meta[Vv::CpcpHarness::Mcp::META_PROTOCOL_VERSION] = version if version
    meta[Vv::CpcpHarness::Mcp::META_CLIENT_INFO] = client if client
    params = params.merge("_meta" => meta) unless meta.empty?
    { "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params }
  end

  describe "the modern, stateless era" do
    it "answers server/discover with every version it speaks" do
      result = server.handle(request("server/discover"))["result"]

      expect(result["resultType"]).to eq "complete"
      expect(result["supportedVersions"].first).to eq Vv::CpcpHarness::Mcp::MODERN
      expect(result["capabilities"]["tools"]).to eq({ "listChanged" => false })
      expect(result["_meta"][Vv::CpcpHarness::Mcp::META_SERVER_INFO]["name"]).to eq "acme-agent-harness"
    end

    it "needs no handshake before a call" do
      response = server.handle(request("tools/list"))

      expect(response["result"]["tools"].map { |t| t["name"] })
        .to eq %w[reads_note_list writes_note_create]
    end

    it "refuses a protocol version it does not speak, and says which it does" do
      response = server.handle(request("tools/list", version: "1900-01-01"))

      expect(response["error"]["code"]).to eq Vv::CpcpHarness::Mcp::UNSUPPORTED_PROTOCOL_VERSION
      expect(response["error"]["data"]["supported"]).to include Vv::CpcpHarness::Mcp::MODERN
      expect(response["error"]["data"]["requested"]).to eq "1900-01-01"
    end
  end

  describe "the legacy era" do
    it "answers an initialize handshake under the revision the client asked for" do
      result = server.handle({ "jsonrpc" => "2.0", "id" => 1, "method" => "initialize",
                               "params" => { "protocolVersion" => "2025-06-18",
                                             "clientInfo" => { "name" => "some-ide" } } })["result"]

      expect(result["protocolVersion"]).to eq "2025-06-18"
      expect(result["serverInfo"]["name"]).to eq "acme-agent-harness"
      expect(result["instructions"]).to include "operationId"
    end

    it "falls back to its newest legacy revision for one it does not speak" do
      result = server.handle({ "jsonrpc" => "2.0", "id" => 1, "method" => "initialize",
                               "params" => { "protocolVersion" => "2023-01-01" } })["result"]

      expect(result["protocolVersion"]).to eq Vv::CpcpHarness::Mcp::LEGACY.first
    end

    it "swallows notifications and answers ping" do
      expect(server.handle({ "jsonrpc" => "2.0", "method" => "notifications/initialized" })).to be_nil
      expect(server.handle(request("ping"))["result"]).to eq({})
    end
  end

  describe "tools/list" do
    it "carries the face as hints and the IRI as metadata, not as text for the model" do
      tools = server.handle(request("tools/list"))["result"]["tools"]
      read = tools.find { |t| t["name"] == "reads_note_list" }
      write = tools.find { |t| t["name"] == "writes_note_create" }
      prefix = Vv::CpcpHarness::Mcp::META_PREFIX

      expect(read["annotations"]).to include("readOnlyHint" => true, "destructiveHint" => false)
      expect(write["annotations"]).to include("readOnlyHint" => false, "destructiveHint" => true)
      # Repeats are safe only under the same operationId, which the model
      # may not pass, so the server claims nothing.
      expect(write["annotations"]["idempotentHint"]).to be false
      expect(write["_meta"]["#{prefix}iri"]).to eq "https://w3id.org/cpcp/osi8/demo#note.create"
      expect(write["description"]).not_to include "w3id.org"
    end

    it "gives a parameterless tool a schema that says so" do
      tools = server.handle(request("tools/list"))["result"]["tools"]
      read = tools.find { |t| t["name"] == "reads_note_list" }

      expect(read["inputSchema"]).to eq({ "type" => "object", "additionalProperties" => false })
    end

    it "declares operationId as an optional string on a write" do
      tools = server.handle(request("tools/list"))["result"]["tools"]
      write = tools.find { |t| t["name"] == "writes_note_create" }

      expect(write["inputSchema"]["properties"]).to have_key "operationId"
      expect(write["inputSchema"]["required"]).to contain_exactly("title", "body")
    end

    it "returns tools in a deterministic order" do
      s = server
      expect(s.handle(request("tools/list"))["result"]["tools"])
        .to eq s.handle(request("tools/list"))["result"]["tools"]
    end
  end

  describe "tools/call" do
    it "reads through the seam, sentence first and the grounded node after" do
      response = server.handle(request("tools/call", { "name" => "reads_note_list", "arguments" => {} }))
      result = response["result"]

      expect(result["resultType"]).to eq "complete"
      expect(result["isError"]).to be false
      expect(result["content"].first["text"]).to eq "note.list succeeded with 1 item."
      expect(result["content"].last["text"]).to include "\"@graph\""
      expect(result["structuredContent"]["result"]["@graph"].length).to eq 1
    end

    it "puts an unknown tool on the protocol side, where MCP puts it" do
      response = server.handle(request("tools/call", { "name" => "nope" }))

      expect(response["error"]["code"]).to eq Vv::CpcpHarness::Mcp::INVALID_PARAMS
      expect(response["error"]["message"]).to eq "Unknown tool: nope"
    end

    it "puts a refusal in the result, where the model can act on it" do
      response = server.handle(request("tools/call",
                                       { "name" => "writes_note_create",
                                         "arguments" => { "title" => "a" } }))
      result = response["result"]
      prefix = Vv::CpcpHarness::Mcp::META_PREFIX

      expect(response).not_to have_key "error"
      expect(result["isError"]).to be true
      expect(result["content"].first["text"]).to include "body is required"
      expect(result["_meta"]["#{prefix}reason"]).to eq "harness_input_rejected"
    end

    it "declines a write when nothing and no one approved it" do
      result = server.handle(request("tools/call",
                                     { "name" => "writes_note_create",
                                       "arguments" => { "title" => "a", "body" => "b" } }))["result"]

      expect(result["isError"]).to be true
      expect(result["content"].first["text"]).to include "user_declined"
    end

    it "lets the client's own prompt stand in, and records it as the client's word" do
      s = described_class.new(bridge: bridge(approver: Vv::CpcpHarness::Mcp.client_approval),
                              session_id: "sess-1")
      result = s.handle(request("tools/call",
                                { "name" => "writes_note_create",
                                  "arguments" => { "title" => "a", "body" => "b" } }))["result"]

      expect(result["isError"]).to be false
      expect(journal.last["approvedBy"]).to eq "client:claude-code"
    end

    it "records the road and what it cannot attest about the account" do
      s = described_class.new(bridge: bridge(approver: Vv::CpcpHarness::Mcp.client_approval),
                              session_id: "sess-1")
      s.handle(request("tools/call", { "name" => "writes_note_create",
                                       "arguments" => { "title" => "a", "body" => "b" } }, id: "call-7"))
      entry = journal.last

      expect(entry["backend"]).to eq "mcp:claude-code"
      expect(entry["authMode"]).to eq "client"
      expect(entry["sessionId"]).to eq "sess-1"
      expect(entry["rpcId"]).to eq "call-7"
      expect(entry["operationId"]).to match(/\Anote-create-[0-9a-f]{16}\z/)
    end

    it "refuses arguments that are not an object rather than coercing them" do
      response = server.handle(request("tools/call",
                                       { "name" => "reads_note_list", "arguments" => [] }))

      expect(response["error"]["code"]).to eq Vv::CpcpHarness::Mcp::INVALID_PARAMS
    end
  end

  describe "malformed frames" do
    it "answers a missing method and an unknown one" do
      expect(server.handle({ "jsonrpc" => "2.0", "id" => 1 })["error"]["code"])
        .to eq Vv::CpcpHarness::Mcp::INVALID_REQUEST
      expect(server.handle(request("resources/read"))["error"]["code"])
        .to eq Vv::CpcpHarness::Mcp::METHOD_NOT_FOUND
    end

    it "answers something that is not an object at all" do
      expect(server.handle("hello")["error"]["code"]).to eq Vv::CpcpHarness::Mcp::INVALID_REQUEST
    end
  end
end
