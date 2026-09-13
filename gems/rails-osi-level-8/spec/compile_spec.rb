# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOsiLevel8::Profile9::Compile do
  it "is a function of model + catalog version: same inputs, same aciaCid" do
    a = described_class.call(
      fields: described_class::J1_FIELDS, step_kind: "decide", title: "Authorization review", frame: "j1"
    )
    b = described_class.call(
      fields: described_class::J1_FIELDS, step_kind: "decide", title: "Authorization review", frame: "j1"
    )
    expect(a["ok"]).to eq(true)
    expect(a["digest"]).to eq(b["digest"])
    expect(a["aciaCid"]).to eq(b["aciaCid"])
    expect(a["aciaCid"]).to start_with("cid:acia:")
    expect(a["document"]["componentRegistryVersion"]).to eq("ghis-19@1")
  end

  it "refuses a date field rather than compiling it to text" do
    r = described_class.call(
      fields: [{ "name" => "due_on", "datatype" => "date", "ordinal" => 1 }],
      step_kind: "collect",
      title: "Due"
    )
    expect(r["ok"]).to eq(false)
    expect(r["reason"]).to eq("date_kind_missing")
    expect(r.dig("because", "wouldHaveBeen")).to eq("text")
    expect(r["document"]).to be_nil
  end

  it "ghis-20@1 compiles date to DateInput, not SemanticText" do
    r = described_class.call(
      fields: [{ "name" => "due_on", "datatype" => "date", "ordinal" => 1 }],
      step_kind: "date",
      title: "Due",
      catalog_version: described_class::GHIS_20
    )
    expect(r["ok"]).to eq(true)
    expect(r["catalogVersion"]).to eq("ghis-20@1")
    expect(r.dig("document", "componentRegistryVersion")).to eq("ghis-20@1")
    kinds = []
    walk = ->(n) {
      kinds << n["componentKind"] if n.is_a?(Hash)
      Array(n.is_a?(Hash) ? n["children"] : nil).each { |c| walk.call(c) }
    }
    walk.call(r.dig("document", "root"))
    expect(kinds).to include("DateInput")
    expect(kinds).not_to include("SemanticText")
    node = r.dig("document", "root", "children").find { |n| n["componentKind"] == "DateInput" }
    expect(node.dig("props", "valueJson", "datatype")).to eq("date")
    expect(node.dig("props", "valueJson", "field")).to eq("due_on")
  end

  it "refuses a string field: ghis-19@1 has no Input kind" do
    r = described_class.call(
      fields: [{ "name" => "note", "datatype" => "string", "ordinal" => 1 }],
      step_kind: "collect",
      title: "Note"
    )
    expect(r["ok"]).to eq(false)
    expect(r["reason"]).to eq("kind_not_in_catalog")
  end

  it "ghis-21@1 compiles string to Input, not SemanticText; date stays DateInput" do
    r = described_class.call(
      fields: [
        { "name" => "note", "datatype" => "string", "ordinal" => 1 },
        { "name" => "due_on", "datatype" => "date", "ordinal" => 2 }
      ],
      step_kind: "collect",
      title: "Form",
      catalog_version: described_class::GHIS_21
    )
    expect(r["ok"]).to eq(true)
    kinds = []
    walk = ->(n) {
      kinds << n["componentKind"] if n.is_a?(Hash)
      Array(n.is_a?(Hash) ? n["children"] : nil).each { |c| walk.call(c) }
    }
    walk.call(r.dig("document", "root"))
    expect(kinds).to include("Input", "DateInput")
    expect(kinds).not_to include("SemanticText")
    input = r.dig("document", "root", "children").find { |n| n["componentKind"] == "Input" }
    expect(input.dig("props", "valueJson", "datatype")).to eq("string")
  end

  it "compiles J1 enum decide into DecisionForm under PageShell" do
    r = described_class.j1_document
    expect(r["ok"]).to eq(true)
    kinds = []
    walk = ->(n) {
      kinds << n["componentKind"] if n.is_a?(Hash)
      Array(n.is_a?(Hash) ? n["children"] : nil).each { |c| walk.call(c) }
    }
    walk.call(r.dig("document", "root"))
    expect(kinds).to include("PageShell", "DecisionForm", "ActionControl", "EvidencePanel")
    form = r.dig("document", "root", "children").find { |n| n["componentKind"] == "DecisionForm" }
    expect(form.dig("props", "valueJson", "choices")).to eq("approve,deny")
    expect(form.dig("props", "valueJson", "field")).to eq("decision")
  end
end
