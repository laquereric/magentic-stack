# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Client do
  let(:cid) { Vv::CpcpHarness::Cid.from(push_cid)[:result] }
  let(:slept) { [] }

  def client_for(transport, **extra)
    described_class.new(seam: "back", transport: transport, cid: cid,
                        sleeper: ->(s) { slept << s }, **extra)
  end

  def transport(cid_payload: nil, &handler)
    Vv::CpcpHarness::FakeTransport.new(cid_payload: cid_payload || push_cid, &handler)
  end

  it "injects the CID's @context so the model never writes JSON-LD" do
    t = transport { |_call| exchange(200, ok_envelope({ "id" => "note:1" })) }
    client_for(t).call(method: "note.create", face: :push, params: { "title" => "a" },
                       operation_id: "note-create-1")

    expect(t.calls.first[:params]["@context"]).to eq push_cid["@context"]
    expect(t.calls.first[:params]["title"]).to eq "a"
    expect(t.calls.first[:operation_id]).to eq "note-create-1"
  end

  it "never sends the operationId as a param" do
    t = transport { |_call| exchange(200, ok_envelope({})) }
    client_for(t).call(method: "note.create", face: :push,
                       params: { "title" => "a", "operationId" => "note-create-1" },
                       operation_id: "note-create-1")

    expect(t.calls.first[:params]).not_to have_key "operationId"
  end

  it "refuses params that are not an object" do
    t = transport { |_call| exchange(200, ok_envelope({})) }
    env = client_for(t).call(method: "note.create", face: :push, params: [], operation_id: "x")

    expect(env[:reason]).to eq :harness_input_rejected
    expect(t.calls).to be_empty
  end

  it "returns the operationId on every result, including an unreachable seam" do
    t = transport { |_call| unreachable }
    env = client_for(t).call(method: "note.create", face: :push, params: {},
                             operation_id: "note-create-1")

    expect(env[:ok]).to be false
    expect(env[:reason]).to eq :seam_unreachable
    expect(env[:operation_id]).to eq "note-create-1"
    expect(env[:seam]).to eq "back"
  end

  it "retries a 503 with a window under the same operationId" do
    t = transport do |_call, n|
      n < 3 ? exchange(503, flat_refusal("sqlite_busy", "writer contention"), headers: { "retry-after" => "1" })
            : exchange(200, ok_envelope({ "id" => "note:1" }))
    end
    env = client_for(t).call(method: "note.create", face: :push, params: {},
                             operation_id: "note-create-1")

    expect(env[:ok]).to be true
    expect(t.calls.length).to eq 3
    expect(t.calls.map { |c| c[:operation_id] }.uniq).to eq ["note-create-1"]
    expect(slept).to eq [1, 1]
  end

  it "does not retry a 503 without a window" do
    t = transport { |_call| exchange(503, flat_refusal("graph_unreachable", "down")) }
    env = client_for(t).call(method: "note.list", face: :pull)

    expect(t.calls.length).to eq 1
    expect(env[:reason]).to eq :graph_unreachable
  end

  it "replays one dropped connection, then reports it" do
    t = transport { |_call| unreachable }
    env = client_for(t).call(method: "note.create", face: :push, params: {}, operation_id: "x")

    expect(t.calls.length).to eq 2
    expect(env[:reason]).to eq :seam_unreachable
  end

  it "does not retry a domain refusal that arrived as HTTP 200" do
    t = transport { |_call| exchange(200, nested_refusal("grounding_refused", "title missing")) }
    env = client_for(t).call(method: "note.create", face: :push, params: {}, operation_id: "x")

    expect(t.calls.length).to eq 1
    expect(env[:reason]).to eq :grounding_refused
    expect(env[:http_status]).to eq 200
  end

  it "reports a body that is not an envelope" do
    t = Vv::CpcpHarness::FakeTransport.new(cid_payload: push_cid) do |_call|
      { exchanged: true, http_status: 200, headers: {}, body: nil, raw: "<html>",
        parse_error: "JSON::ParserError: unexpected token" }
    end
    env = client_for(t).call(method: "note.list", face: :pull)

    expect(env[:reason]).to eq :seam_body_unparseable
  end

  it "refuses every call once the live CID no longer matches the pin" do
    changed = push_cid
    changed["description"] = "changed under us"
    t = transport(cid_payload: changed) { |_call| exchange(200, ok_envelope({})) }
    client = client_for(t)

    env = client.call(method: "note.create", face: :push, params: {}, operation_id: "x")
    expect(env[:reason]).to eq :contract_superseded
    expect(t.calls).to be_empty

    # And it stays refused until the snapshot is updated.
    expect(client.call(method: "note.create", face: :push, params: {}, operation_id: "y")[:reason])
      .to eq :contract_superseded
    expect(t.cid_calls).to eq 1
  end

  it "checks the pin once per TTL, not once per call" do
    t = transport { |_call| exchange(200, ok_envelope({})) }
    client = client_for(t, pin_ttl: 300)

    3.times { client.call(method: "note.list", face: :pull) }
    expect(t.cid_calls).to eq 1
  end

  it "treats an unfetchable live CID as a warning, not a supersession" do
    t = Vv::CpcpHarness::FakeTransport.new(cid_response: unreachable) do |_call|
      exchange(200, ok_envelope({}))
    end
    env = client_for(t).call(method: "note.list", face: :pull)

    expect(env[:ok]).to be true
    expect(env[:warnings].first).to match(/live CID could not be fetched/)
  end

  it "passes a non-durable idempotency store through, with a warning" do
    t = transport do |_call|
      exchange(200, ok_envelope({ "id" => "note:1", "idempotency" => "not_durable" }))
    end
    env = client_for(t).call(method: "note.create", face: :push, params: {}, operation_id: "x")

    expect(env[:ok]).to be true
    expect(env[:warnings].first).to match(/not durable/)
  end
end
