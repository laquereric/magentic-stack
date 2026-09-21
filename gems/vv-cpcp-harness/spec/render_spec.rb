# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Render do
  let(:render) { described_class }

  def read(payload, status: 200, **extra)
    Vv::CpcpHarness::Envelope.read(payload, http_status: status).merge(extra)
  end

  it "counts a collection in the sentence and puts the envelope in the node" do
    env = read(ok_envelope({ "@graph" => [{ "title" => "a" }, { "title" => "b" }] }),
               method: "note.list")
    result = render.result(env)

    expect(result[:text]).to eq "note.list succeeded with 2 items."
    expect(result[:ld]["result"]["@graph"].length).to eq 2
    expect(result[:ok]).to be true
  end

  it "names the operationId on a write" do
    env = read(ok_envelope({ "id" => "note:1" }), method: "note.create",
               operation_id: "note-create-a1b2c3d4e5f60718")

    expect(render.result(env)[:text]).to include "(operationId note-create-a1b2c3d4e5f60718)"
  end

  it "never reports a recording as a completed change" do
    env = read(ok_envelope({ "live_applied" => false, "effective" => "2026-10-01" }),
               method: "placement.record", operation_id: "placement-record-1")
    text = render.result(env)[:text]

    expect(text).to include "was recorded, not applied"
    expect(text).to include "2026-10-01"
  end

  it "gives a refusal its stable reason and explanation" do
    env = read(nested_refusal("grounding_refused", "cpcp:title is required"), method: "note.create")
    result = render.result(env)

    expect(result[:text]).to eq "note.create was refused: grounding_refused — cpcp:title is required."
    expect(result[:ok]).to be false
  end

  it "says what restoration would take when the seam says" do
    env = read(nested_refusal("graph_unreachable", "store down").merge(
                 "cpcp" => { "restoration" => {
                   "state_reached" => "the write landed, the projection did not",
                   "inconsistency" => "the graph lags the store",
                   "restore_when" => "the graph answers",
                   "restore_action" => "replay the projection"
                 } }
               ), status: 503, method: "note.create")

    expect(render.result(env)[:text]).to include "Restore when the graph answers by replay the projection."
  end

  it "keeps a warning beside the sentence" do
    env = read(ok_envelope({}), method: "note.create")
    result = render.result(env, warnings: ["The seam reports its store is not durable."])

    expect(result[:text]).to end_with "The seam reports its store is not durable."
  end

  it "renders two blocks for Claude, sentence first, and marks a 200 refusal an error" do
    env = read(nested_refusal("authorization_denied", "no"), method: "note.create")
    blocks = render.claude(render.result(env))

    expect(blocks["content"].first["text"]).to include "authorization_denied"
    expect(blocks["content"].length).to eq 2
    expect(blocks["is_error"]).to be true
  end

  it "renders one string for OpenCode, with an Error prefix on a refusal" do
    env = read(nested_refusal("unknown_operation", "no such method"), method: "note.nope")
    text = render.open_code(render.result(env))

    expect(text).to start_with "Error: note.nope was refused: unknown_operation"
    expect(text).to include "\"ok\": false"
  end

  it "truncates a long @graph and says how many items were dropped" do
    graph = Array.new(400) { |i| { "title" => "note #{i}", "body" => "x" * 100 } }
    env = read(ok_envelope({ "@graph" => graph }), method: "note.list")
    result = render.result(env)

    expect(result[:text]).to match(/of 400 items were omitted; narrow the read/)
    expect(result[:ld]["result"]["@graph"].length).to be < 400
    expect(JSON.generate(result[:ld]).bytesize).to be <= described_class::MAX_LD_BYTES
  end
end
