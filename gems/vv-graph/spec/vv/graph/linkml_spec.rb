# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

RSpec.describe Vv::Graph::Linkml do
  let(:fixture) { File.expand_path("../../fixtures/linkml/note.yaml", __dir__) }
  let(:schema)  { Vv::Linkml.load_file(fixture) }
  let(:derived) { Vv::Linkml.derive(schema) }
  let(:result)  { described_class.shapes(derived) }
  let(:ttl)     { result[:ttl] }

  it "derives a node shape per class, targeting the class URI" do
    expect(result[:ok]).to be true
    expect(result[:node_shapes]).to eq 2
    expect(ttl).to include "<urn:vv-graph:shape:Note> a sh:NodeShape"
    expect(ttl).to include "sh:targetClass <https://w3id.org/cpcp/mm/Note>"
  end

  it "maps a required slot to sh:minCount 1" do
    expect(ttl).to match(/sh:path <[^>]*title>[^\]]*sh:minCount 1/m)
  end

  it "maps a single-valued slot to sh:maxCount 1 and a multivalued one to neither" do
    expect(ttl).to match(/sh:path <[^>]*body>[^\]]*sh:maxCount 1/m)
    tags = ttl[/sh:path <[^>]*tags>.*?\]/m]
    expect(tags).not_to include "sh:maxCount"
  end

  it "maps a builtin range to sh:datatype with the XSD URI from types.yaml" do
    expect(ttl).to include "sh:datatype <http://www.w3.org/2001/XMLSchema#integer>"
    expect(ttl).to include "sh:datatype <http://www.w3.org/2001/XMLSchema#boolean>"
  end

  it "maps a class range to sh:class rather than a datatype" do
    note_ref = ttl[/sh:path <[^>]*note>.*?\]/m]
    expect(note_ref).to include "sh:class <https://w3id.org/cpcp/mm/Note>"
    expect(note_ref).not_to include "sh:datatype"
  end

  it "maps an enum range to sh:in over its permissible values" do
    expect(ttl).to include "sh:in ("
    expect(ttl).to include '"draft"'
    expect(ttl).to include '"withdrawn"'
  end

  it "carries pattern and value bounds across" do
    # The schema's regex is ^\S.*$ — one backslash. It appears here with two
    # because a lone \S is not a valid Turtle string escape, so the backslash
    # has to be escaped to survive parsing. The regex SHACL ends up applying
    # is still the single-backslash one.
    expect(ttl).to include 'sh:pattern "^\\\\S.*$"'
    expect(ttl).to include "sh:minInclusive 1"
  end

  it "treats an identifier as required without it being declared required" do
    expect(schema.class_def("Note").attributes["id"].required?).to be false
    expect(ttl).to match(/sh:path <[^>]*id>[^\]]*sh:minCount 1/m)
  end

  describe "an incomplete derivation" do
    let(:incomplete) do
      instance_double(
        Vv::Linkml::DerivedSchema,
        complete?: false,
        gaps: ["unresolved import: linkml:nonexistent"]
      )
    end

    it "refuses by default rather than emitting shapes that under-constrain" do
      out = described_class.shapes(incomplete)
      expect(out[:ok]).to be false
      expect(out[:refusal]).to eq :linkml_derivation_incomplete
      expect(out[:gaps]).to include(/unresolved import/)
    end

    it "emits when the caller opts out, and says the result is not conclusive" do
      allow(incomplete).to receive(:class_names).and_return([])
      out = described_class.shapes(incomplete, strict: false)
      expect(out[:ok]).to be true
      expect(out[:conclusive]).to be false
    end
  end

  describe "field resolution" do
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

  describe "refusals" do
    it "refuses a missing schema file without raising" do
      out = described_class.shapes("/nonexistent/schema.yaml")
      expect(out[:ok]).to be false
      expect(out[:refusal]).to eq :linkml_schema_not_found
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
