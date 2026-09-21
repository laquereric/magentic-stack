# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Transport do
  let(:endpoint) { "https://back.example/_cpcp" }

  def transport(**extra)
    described_class.new(endpoint: endpoint, credential: -> { "s3cret" },
                        status_profile: "dual-v1", **extra)
  end

  it "speaks JSON-RPC 2.0 with the credential out of band" do
    stub = stub_request(:post, "#{endpoint}/rpc")
           .with(
             headers: {
               "Authorization" => "Bearer s3cret",
               "Content-Type" => "application/json",
               "CPCP-HTTP-Status-Profile" => "dual-v1"
             }
           ) do |request|
             body = JSON.parse(request.body)
             expect(body["jsonrpc"]).to eq "2.0"
             expect(body["method"]).to eq "note.create"
             expect(body["params"]).to eq({ "title" => "a" })
             expect(body["operationId"]).to eq "note-create-1"
             true
           end.to_return(status: 200, body: JSON.generate(ok_envelope({ "id" => "note:1" })))

    res = transport.rpc(method: "note.create", params: { "title" => "a" },
                        operation_id: "note-create-1", rpc_id: "toolu_01H")

    expect(stub).to have_been_requested
    expect(res[:exchanged]).to be true
    expect(res[:http_status]).to eq 200
    expect(res[:body]["ok"]).to be true
  end

  it "sends no operationId on a PULL" do
    stub_request(:post, "#{endpoint}/rpc").to_return(status: 200, body: JSON.generate(ok_envelope({})))
    transport.rpc(method: "note.list", params: {})

    expect(a_request(:post, "#{endpoint}/rpc")
             .with { |req| !JSON.parse(req.body).key?("operationId") }).to have_been_made
  end

  it "keeps the headers the contract gives meaning to" do
    stub_request(:post, "#{endpoint}/rpc")
      .to_return(status: 503, body: JSON.generate(flat_refusal("sqlite_busy", "contention")),
                 headers: { "Retry-After" => "2", "Content-Type" => "application/json" })

    res = transport.rpc(method: "note.create", params: {}, operation_id: "x")

    expect(res[:http_status]).to eq 503
    expect(res[:headers]["retry-after"]).to eq "2"
  end

  it "reports a body that is not JSON without raising" do
    stub_request(:post, "#{endpoint}/rpc").to_return(status: 502, body: "<html>bad gateway</html>")

    res = transport.rpc(method: "note.list", params: {})

    expect(res[:exchanged]).to be true
    expect(res[:parse_error]).to match(/ParserError/)
    expect(res[:body]).to be_nil
  end

  it "turns a dropped connection into an envelope, never an exception" do
    stub_request(:post, "#{endpoint}/rpc").to_raise(Errno::ECONNREFUSED)

    res = transport.rpc(method: "note.list", params: {})

    expect(res[:ok]).to be false
    expect(res[:reason]).to eq :seam_unreachable
    expect(res[:transport_error]).to eq :connection
  end

  it "turns a timeout into an envelope" do
    stub_request(:post, "#{endpoint}/rpc").to_timeout

    expect(transport.rpc(method: "note.list", params: {})[:reason]).to eq :seam_unreachable
  end

  it "fetches the two descriptive GETs" do
    stub_request(:get, "#{endpoint}/cid.json").to_return(status: 200, body: JSON.generate(push_cid))
    stub_request(:get, "#{endpoint}/up").to_return(status: 200, body: '{"ok":true}')

    expect(transport.cid[:body]["cid"]).to eq "cid:cpcp:demo:push-note"
    expect(transport.up[:http_status]).to eq 200
  end

  it "refuses without an endpoint rather than guessing one" do
    blank = described_class.new(endpoint: "", credential: -> { "t" })

    expect(blank.rpc(method: "note.list")[:reason]).to eq :seam_unreachable
  end

  it "reads the credential at call time" do
    value = "first"
    t = described_class.new(endpoint: endpoint, credential: -> { value })
    stub_request(:post, "#{endpoint}/rpc").to_return(status: 200, body: "{}")

    t.rpc(method: "note.list")
    value = "second"
    t.rpc(method: "note.list")

    expect(a_request(:post, "#{endpoint}/rpc")
             .with(headers: { "Authorization" => "Bearer second" })).to have_been_made
  end
end
