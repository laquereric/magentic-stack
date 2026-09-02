# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOsiLevel8::ShapeId do
  it "resolves a historical osi.example IRI to its successor and keeps the original" do
    old = "https://osi.example/shapes/P1NoteCreateEffectShape"
    r = described_class.resolve(old)
    expect(r["shape_id"]).to eq(old)
    expect(r["shape_id_resolved"]).to eq("https://w3id.org/cpcp/osi8/note#P1NoteCreateEffectShape")
    expect(r["shape_id_resolution"]).to eq("historical")
    expect(r).not_to have_key("shape_id_unresolved")
  end

  it "treats an already-successor IRI as current" do
    cur = "https://w3id.org/cpcp/osi8/note#P1NoteCreateEffectShape"
    r = described_class.resolve(cur)
    expect(r["shape_id"]).to eq(cur)
    expect(r["shape_id_resolved"]).to eq(cur)
    expect(r["shape_id_resolution"]).to eq("current")
  end

  it "does not guess an unknown IRI" do
    r = described_class.resolve("https://osi.example/shapes/NotAShape")
    expect(r["shape_id_resolution"]).to eq("unresolved")
    expect(r).not_to have_key("shape_id_resolved")
    expect(r.dig("shape_id_unresolved", "ok")).to be(false)
    expect(r.dig("shape_id_unresolved", "reason")).to eq("shape_id_unresolved")
    expect(r.dig("shape_id_unresolved", "because")).to include("osi_example_successors.json")
  end
end
