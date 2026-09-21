# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Journal do
  let(:tool) do
    Vv::CpcpHarness.define_tool(
      name: "back_note_create", description: "",
      cpcp: { iri: "https://w3id.org/cpcp/osi8/demo#note.create", face: :push,
              cid: { "url" => "https://back.example/_cpcp/cid.json", "digest" => "sha256-9f2c" } }
    )[:result]
  end
  let(:context) do
    Vv::CpcpHarness::Context.new(session_id: "8c1e", backend: "claude", model: "claude-opus-5",
                                 agent: "build", rpc_id: "toolu_01H", approved_by: "user:eric")
  end

  it "writes one line per PUSH, joinable to the seam's record by operationId" do
    journal = described_class.new(clock: -> { Time.utc(2026, 9, 20, 14, 3, 11) })
    journal.push(tool: tool, envelope: { ok: true, http_status: 200, live_applied: true },
                 operation_id: "note-create-a1b2c3d4e5f60718", operation_id_source: :minted,
                 context: context)
    entry = journal.entries.first

    expect(entry["at"]).to eq "2026-09-20T14:03:11.000Z"
    expect(entry["iri"]).to eq "https://w3id.org/cpcp/osi8/demo#note.create"
    expect(entry["operationId"]).to eq "note-create-a1b2c3d4e5f60718"
    expect(entry["operationIdSource"]).to eq "minted"
    expect(entry["cidDigest"]).to eq "sha256-9f2c"
    expect(entry["outcome"]).to eq({ "ok" => true, "http" => 200, "liveApplied" => true })
  end

  it "journals a refusal too, with its reason" do
    journal = described_class.new
    journal.push(tool: tool, envelope: { ok: false, reason: :user_declined },
                 operation_id: "note-create-1", operation_id_source: :minted, context: context)

    expect(journal.entries.first["outcome"]).to include("ok" => false, "reason" => "user_declined")
  end

  it "samples reads, since a read promises nothing" do
    journal = described_class.new(pull_sample: 3)
    5.times { journal.pull(tool: tool, envelope: { ok: true }, context: context) }

    expect(journal.entries.length).to eq 1
  end

  it "ships each entry to a sink and appends JSONL" do
    shipped = []
    Dir.mktmpdir do |dir|
      path = File.join(dir, "journal", "pushes.jsonl")
      journal = described_class.new(path: path, sink: ->(e) { shipped << e })
      2.times do |i|
        journal.push(tool: tool, envelope: { ok: true }, operation_id: "note-create-#{i}",
                     operation_id_source: :model, context: context)
      end

      lines = File.readlines(path)
      expect(lines.length).to eq 2
      expect(JSON.parse(lines.first)["operationId"]).to eq "note-create-0"
      expect(shipped.length).to eq 2
    end
  end

  it "does not take a call down when it cannot be written" do
    journal = described_class.new(path: "/nope/cannot/write.jsonl")

    expect do
      journal.push(tool: tool, envelope: { ok: true }, operation_id: "x",
                   operation_id_source: :minted, context: context)
    end.not_to raise_error
  end
end
