# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Generator do
  let(:client) { instance_double(Vv::CpcpHarness::Client) }

  def seam_config(**extra)
    Vv::CpcpHarness::Seam.new(**{ name: "back", endpoint: "https://back.example/_cpcp",
                                  include: [] }.merge(extra))
  end

  def generate(payload, **extra)
    cid = Vv::CpcpHarness::Cid.from(payload)[:result]
    described_class.tools_for(seam: seam_config(**extra), cid: cid, client: client)
  end

  it "turns a PUSH operation into a write tool" do
    tool = generate(push_cid, include: ["note.create"])[:result].first

    expect(tool.name).to eq "back_note_create"
    expect(tool.face).to eq :push
    expect(tool.read_only?).to be false
    expect(tool.iri).to eq "https://w3id.org/cpcp/osi8/demo#note.create"
    expect(tool.cpcp.cid["url"]).to eq "https://back.example/_cpcp/cid.json"
    expect(tool.schema.field("operationId").required).to be false
    expect(tool.description).to include "pass the operationId from the earlier result"
  end

  it "turns a PULL operation into a read tool" do
    tool = generate(pull_cid)[:result].first

    expect(tool.name).to eq "back_note_list"
    expect(tool.face).to eq :pull
    expect(tool.read_only?).to be true
    expect(tool.schema.field("operationId")).to be_nil
    expect(tool.description).to include "promises nothing"
  end

  it "builds the input schema from SHACL where the shape describes the inputs" do
    tool = generate(push_cid)[:result].first

    expect(tool.schema.validate({ "title" => "a" })).to eq "body is required"
    expect(tool.cpcp.input_shape).to eq "cpcp:NoteShape"
  end

  it "does not mistake a result shape for an input schema" do
    tool = generate(pull_cid)[:result].first

    # note.list takes no params; the Note shape describes what comes back.
    expect(tool.cpcp.input_shape).to be_nil
    expect(tool.schema.validate({})).to be_nil
  end

  it "refuses an allowlisted operation the seam does not publish" do
    result = generate(push_cid, include: ["note.delete"])

    expect(result[:ok]).to be false
    expect(result[:reason]).to eq :operation_not_published
    expect(result[:because]).to include "note.create"
  end

  it "refuses a CID whose kind contradicts its operations" do
    payload = pull_cid
    payload["operations"][0]["operationId"] = "required"

    expect(generate(payload)[:reason]).to eq :cid_face_conflict
  end

  it "names tools from the seam and the method, with dots flattened" do
    expect(described_class.tool_name("back", "note.create")).to eq "back_note_create"
  end

  it "calls the seam through the client, passing the face and the IRI" do
    tool = generate(push_cid)[:result].first
    context = Vv::CpcpHarness::Context.new(operation_id: "note-create-1", rpc_id: "toolu_1")

    expect(client).to receive(:call).with(
      method: "note.create", face: :push, params: { "title" => "a" },
      operation_id: "note-create-1", rpc_id: "toolu_1",
      iri: "https://w3id.org/cpcp/osi8/demo#note.create"
    ).and_return(Vv::CpcpHarness::Envelope.ok(result: {}))

    tool.handler.call({ "title" => "a" }, context)
  end
end
