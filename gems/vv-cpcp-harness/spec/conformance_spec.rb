# frozen_string_literal: true

# The example caller the harness CID names (design §7.2): every grounded
# native tool, invoked through `execute()`, checked against what the
# binding claims about it.
RSpec.describe "harness CID conformance" do
  let(:receipts) { Vv::CpcpHarness::Receipts::MemoryStore.new }

  let(:bridge) do
    result = Vv::CpcpHarness.bridge(
      seams: [],
      name: "vv-cpcp-harness",
      receipts: receipts,
      approver: ->(_request) { { approved: true, by: "user:spec" } }
    )
    expect(result[:ok]).to be true
    b = result[:result]

    b.ground(name: "run_tests", description: "Run the project's test suite and return a summary.",
             cpcp: { iri: Vv::CpcpHarness.iri("vv-harness", "tests.run"), face: :pull,
                     output_shape: "cpcp/shapes/harness.ttl#TestRunShape" }) do |args, _ctx|
      { text: "3 passed, 0 failed.", ld: { "type" => "TestRun", "passed" => 3, "failed" => 0,
                                           "pattern" => args["pattern"] } }
    end

    b.ground(name: "notes_write", description: "Write a note into the local store.",
             schema: Vv::CpcpHarness::Schema.from_params({ "title" => "string (required)" }),
             cpcp: { iri: Vv::CpcpHarness.iri("vv-harness", "notes.write"), face: :push }) do |args, ctx|
      { text: "Wrote #{args["title"]}.", ld: { "type" => "Note", "title" => args["title"],
                                               "operationId" => ctx.operation_id } }
    end

    b
  end

  it "gives every grounded tool a unique IRI that the harness CID lists" do
    iris = bridge.tools.map(&:iri)
    listed = bridge.harness_cid["operations"].map { |op| op["iri"] }

    expect(iris.compact.uniq.length).to eq iris.length
    expect(listed).to match_array(iris)
  end

  it "declares operationId as optional on every PUSH, and on no PULL" do
    bridge.tools.each do |tool|
      field = tool.schema.field("operationId")
      if tool.push?
        expect(field).not_to be_nil, "#{tool.name} should declare operationId"
        expect(field.required).to be false
      else
        expect(field).to be_nil, "#{tool.name} should not declare operationId"
      end
    end
  end

  it "answers every call with an envelope carrying a face-appropriate identity" do
    bridge.tools.each do |tool|
      args = tool.push? ? { "title" => "a" } : {}
      result = bridge.execute(tool.name, args)

      expect(result).to include(:ok, :text, :iri)
      expect(result[:iri]).to eq tool.iri
      expect(result[:operation_id]).to(tool.push? ? be_a(String) : be_nil)
    end
  end

  it "uses only reasons the contract or this binding names" do
    broken = Vv::CpcpHarness.define_tool(
      name: "broken", description: "",
      cpcp: { iri: Vv::CpcpHarness.iri("vv-harness", "broken"), face: :pull }
    ) { { error: "nope", reason: "made_up_reason" } }
    bridge.registry.register(broken)

    bridge.tools.each do |tool|
      result = bridge.execute(tool.name, tool.push? ? { "title" => "a" } : {})
      next if result[:reason].nil?

      expect(Vv::CpcpHarness::Reasons.allowed?(result[:reason]))
        .to be(true), "#{tool.name} answered with #{result[:reason]}"
    end
  end

  it "makes no durable replay promise it cannot keep" do
    b = bridge
    tool = b.tools.find(&:push?)

    result = b.execute(tool.name, { "title" => "a" })

    expect(result[:text]).to include "does not outlive the process"
    expect(b.harness_cid["operations"].find { |op| op["iri"] == tool.iri }["durable_replay"]).to be false
  end
end
