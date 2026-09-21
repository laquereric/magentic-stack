# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness do
  it "has a version" do
    expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "builds the canonical operation IRI" do
    expect(described_class.iri("back", "note.create"))
      .to eq "https://w3id.org/cpcp/osi8/back#note.create"
  end

  it "reads a credential at call time, and never bakes it into a tool" do
    ENV["CPCP_SPEC_TOKEN"] = "one"
    credential = described_class.env("CPCP_SPEC_TOKEN")
    expect(credential.call).to eq "one"

    ENV["CPCP_SPEC_TOKEN"] = "two"
    expect(credential.call).to eq "two"
  ensure
    ENV.delete("CPCP_SPEC_TOKEN")
  end

  it "refuses a seam configured without a CID" do
    result = described_class.bridge(seams: [{ name: "back", endpoint: "https://back.example/_cpcp" }])

    expect(result[:ok]).to be false
    expect(result[:reason]).to eq :cid_unreadable
  end

  it "enforces what a grounded tool must keep" do
    expect(
      described_class.define_tool(name: "t", cpcp: { iri: "x", face: :sideways })[:reason]
    ).to eq :tool_definition_invalid

    expect(
      described_class.define_tool(name: "t", cpcp: { face: :pull })[:reason]
    ).to eq :tool_definition_invalid

    expect(
      described_class.define_tool(name: "t", read_only: true,
                                  cpcp: { iri: "x", face: :push })[:reason]
    ).to eq :tool_definition_invalid
  end

  it "keeps the binding's reasons and the contract's reasons apart" do
    expect(described_class::Reasons.binding?(:seam_unreachable)).to be true
    expect(described_class::Reasons.seam?(:seam_unreachable)).to be false
    expect(described_class::Reasons.seam?(:grounding_refused)).to be true
    expect(described_class::Reasons.layer_for(:harness_input_rejected)).to eq :http_request
    expect(described_class::Reasons.allowed?(:made_up)).to be false
  end
end
