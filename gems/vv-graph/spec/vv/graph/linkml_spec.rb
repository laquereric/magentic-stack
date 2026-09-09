# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

# SHACL derivation moved to the Python generators (ADR 0069), so the tests for
# it went with it. What is left is runtime slot resolution, which no generated
# artifact answers.
RSpec.describe Vv::Graph::Linkml do
  let(:fixture) { File.expand_path("../../fixtures/linkml/note.yaml", __dir__) }
  let(:derived) { Vv::Linkml.derive(Vv::Linkml.load_file(fixture)) }

  describe ".field" do
    it "answers from the schema, marking LinkML as the source" do
      field = described_class.field(derived, model: :Note, name: :revision)
      expect(field[:xsd]).to eq "http://www.w3.org/2001/XMLSchema#integer"
      expect(field[:required]).to be false
      expect(field[:source]).to eq :linkml
    end

    it "reports multivalued and effectively-required slots" do
      expect(described_class.field(derived, model: :Note, name: :tags)[:multivalued]).to be true
      expect(described_class.field(derived, model: :Note, name: :id)[:required]).to be true
    end

    it "returns nil for a field the schema does not describe, rather than guessing" do
      expect(described_class.field(derived, model: :Note, name: :not_a_slot)).to be_nil
    end
  end

  describe ".slot_iri" do
    let(:pod) { Vv::Linkml.derive(Vv::Linkml.load_file(File.expand_path("../../fixtures/linkml/pod_note.yaml", __dir__))) }

    it "expands an asserted slot_uri written as a CURIE" do
      slot = pod.slot_for("Note", "title")
      expect(described_class.slot_iri(pod, slot, "Note")).to eq "urn:mm:vocab/pod#title"
    end

    it "takes an asserted slot_uri written as an absolute URN verbatim" do
      slot = pod.slot_for("Note", "created_at")
      expect(described_class.slot_iri(pod, slot, "Note")).to eq "urn:mm:vocab/pod#createdAt"
    end

    it "falls back to the wire convention when no slot_uri is asserted" do
      slot = derived.slot_for("Note", "title")
      expect(described_class.slot_iri(derived, slot, "Note")).to eq "https://w3id.org/cpcp/mm/Note/title"
    end
  end
end

RSpec.describe "Vv::Graph::Schema fed by LinkML" do
  let(:fixture) { File.expand_path("../../fixtures/linkml/note.yaml", __dir__) }
  let(:derived) { Vv::Linkml.derive(Vv::Linkml.load_file(fixture)) }

  before { Vv::Graph::Schema.reset! }
  after  { Vv::Graph::Schema.reset! }

  it "resolves from prefix convention when no schema is registered" do
    expect(Vv::Graph::Schema.field(model: :Note, name: :title)[:iri]).to eq "mm:Note/title"
  end

  it "prefers the authored schema once one is registered" do
    Vv::Graph::Schema.linkml_schema = derived
    field = Vv::Graph::Schema.field(model: :Note, name: :title)
    expect(field[:iri]).to eq "https://w3id.org/cpcp/mm/Note/title"
    expect(field[:xsd]).to eq "http://www.w3.org/2001/XMLSchema#string"
  end

  it "still lets an explicit operator override win over the schema" do
    Vv::Graph::Schema.linkml_schema = derived
    Vv::Graph::Schema.override(model: :Note, name: :title, iri: "mm:Note/headline")
    expect(Vv::Graph::Schema.field(model: :Note, name: :title)[:iri]).to eq "mm:Note/headline"
  end

  it "falls through to convention for a field the schema does not describe" do
    Vv::Graph::Schema.linkml_schema = derived
    expect(Vv::Graph::Schema.field(model: :Note, name: :unknown)[:iri]).to eq "mm:Note/unknown"
  end

  it "does not let a broken schema take down field resolution" do
    Vv::Graph::Schema.linkml_schema = Object.new
    expect(Vv::Graph::Schema.field(model: :Note, name: :title)[:iri]).to eq "mm:Note/title"
  end

  it "is inert again after reset!" do
    Vv::Graph::Schema.linkml_schema = derived
    Vv::Graph::Schema.reset!
    expect(Vv::Graph::Schema.linkml_schema).to be_nil
    expect(Vv::Graph::Schema.field(model: :Note, name: :title)[:iri]).to eq "mm:Note/title"
  end
end
