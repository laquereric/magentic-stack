# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Cid do
  let(:cid) { described_class.from(push_cid)[:result] }

  it "reads the operation manifest" do
    op = cid.operation("note.create")

    expect(op.iri).to eq "https://w3id.org/cpcp/osi8/demo#note.create"
    expect(op.requires_operation_id?).to be true
    expect(cid.methods_published).to eq ["note.create"]
    expect(cid.context["@vocab"]).to eq "https://w3id.org/cpcp/ns#"
  end

  it "loads a committed snapshot and refuses an unreadable one" do
    loaded = described_class.load(
      File.join(Vv::CpcpHarness::SpecHelpers::FIXTURES, "demo-pull-note.cid.json")
    )
    expect(loaded[:ok]).to be true
    expect(loaded[:result].kind).to eq "pull"

    expect(described_class.load("/nope/missing.cid.json")[:reason]).to eq :cid_unreadable
  end

  it "digests the canonical form, so reformatting does not trip the pin" do
    reformatted = described_class.from(JSON.parse(JSON.generate(push_cid.to_a.reverse.to_h)))[:result]

    expect(reformatted.digest).to eq cid.digest
    expect(cid.digest).to start_with "sha256-"
  end

  it "derives the face from the kind and the operation together" do
    expect(cid.face_for(cid.operation("note.create"))[:result]).to eq :push

    pull = described_class.from(pull_cid)[:result]
    expect(pull.face_for(pull.operation("note.list"))[:result]).to eq :pull
  end

  it "refuses to guess when the kind and the operation disagree" do
    payload = pull_cid
    payload["operations"][0]["operationId"] = "required"
    conflicted = described_class.from(payload)[:result]

    refusal = conflicted.face_for(conflicted.operation("note.list"))
    expect(refusal[:ok]).to be false
    expect(refusal[:reason]).to eq :cid_face_conflict
  end

  it "notices a live CID that no longer matches the snapshot" do
    changed = push_cid
    changed["operations"] << { "method" => "note.delete", "iri" => "x", "operationId" => "required" }
    live = described_class.from(changed)[:result]

    expect(cid.superseded_by(live)).to match(/digest/)
    expect(cid.superseded_by(cid)).to be_nil
  end

  it "notices a superseded contract version" do
    pinned = described_class.from(push_cid.merge("contract_version" => 3))[:result]
    live = described_class.from(push_cid.merge("contract_version" => 4))[:result]

    expect(pinned.superseded_by(live)).to match(/digest/)
    expect(pinned.superseded_by(pinned, contract_version: 4)).to match(/contract version/)
  end
end
