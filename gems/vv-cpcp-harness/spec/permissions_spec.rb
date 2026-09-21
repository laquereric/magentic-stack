# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Permissions do
  def tool(face:, name: "back_note_create", iri: "https://w3id.org/cpcp/osi8/back#note.create")
    Vv::CpcpHarness.define_tool(name: name, description: "", cpcp: { iri: iri, face: face })[:result]
  end

  it "allows a PULL and asks about a PUSH when no rule matches" do
    policy = described_class.new

    expect(policy.decide(tool(face: :pull)).action).to eq :allow
    expect(policy.decide(tool(face: :push)).action).to eq :ask
  end

  it "matches a rule by IRI prefix and face, without listing tools" do
    policy = described_class.new(rules: [
                                   { iri: "https://w3id.org/cpcp/osi8/back#*", face: :push, action: :deny }
                                 ])

    expect(policy.decide(tool(face: :push)).action).to eq :deny
    expect(policy.decide(tool(face: :pull)).action).to eq :allow
    other = tool(face: :push, name: "other_note_create", iri: "https://w3id.org/cpcp/osi8/other#note.create")
    expect(policy.decide(other).action).to eq :ask
  end

  it "matches a rule by bare tool name" do
    policy = described_class.new(rules: [{ name: "back_note_create", action: :allow }])

    expect(policy.decide(tool(face: :push)).action).to eq :allow
  end

  it "falls back to the read-only flag for an ungrounded tool" do
    policy = described_class.new
    reader = Vv::CpcpHarness::Tool.new(name: "read_file", read_only: true)
    writer = Vv::CpcpHarness::Tool.new(name: "write_file", read_only: false)

    expect(policy.decide(reader).action).to eq :allow
    expect(policy.decide(writer).action).to eq :ask
  end

  it "shows the approver what the decision needs" do
    seen = nil
    policy = described_class.new(approver: ->(request) { seen = request })
    context = Vv::CpcpHarness::Context.new(session_id: "8c1e", agent: "build")

    policy.approve(tool: tool(face: :push), args: { "title" => "a" },
                   operation_id: "note-create-1", context: context)

    expect(seen[:iri]).to eq "https://w3id.org/cpcp/osi8/back#note.create"
    expect(seen[:params]).to eq({ "title" => "a" })
    expect(seen[:operation_id]).to eq "note-create-1"
    expect(seen[:session_id]).to eq "8c1e"
  end

  it "treats a missing approver as a decline, never as an allow" do
    answer = described_class.new.approve(tool: tool(face: :push), args: {})

    expect(answer[:approved]).to be false
    expect(answer[:because]).to match(/no approver/)
  end

  it "records who approved" do
    policy = described_class.new(approver: ->(_r) { { approved: true, by: "user:eric" } })

    expect(policy.approve(tool: tool(face: :push), args: {})[:by]).to eq "user:eric"
  end
end
