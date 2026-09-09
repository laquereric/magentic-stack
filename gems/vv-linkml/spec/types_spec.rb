# frozen_string_literal: true

RSpec.describe Vv::Linkml::Types do
  it "has the 19 types types.yaml defines" do
    expect(described_class.names.size).to eq(19)
  end

  # 03schemas.md's "Default Types" section lists 14. These are the five it drops.
  it "names the five types the specification's own list omits" do
    expect(described_class.omitted_from_spec_list)
      .to contain_exactly("curie", "date_or_datetime", "jsonpointer", "jsonpath",
                          "sparqlpath")
  end

  describe "the capitalisation trap" do
    # The failure this catches is silent in LinkML itself: an unresolvable range
    # is not an error, it falls through to default_range.
    it "does not resolve the capitalised names the specification prints" do
      expect(described_class.builtin?("Boolean")).to be(false)
      expect(described_class["Boolean"]).to be_nil
    end

    it "identifies the miscased form and names the correct one" do
      expect(described_class.miscased("Boolean")).to eq("boolean")
      expect(described_class.miscased("Uriorcurie")).to eq("uriorcurie")
      expect(described_class.miscased("boolean")).to be_nil
      expect(described_class.miscased("Widget")).to be_nil
    end

    it "explains the failure rather than just refusing" do
      expect { described_class.lookup!("Boolean") }
        .to raise_error(described_class::Unknown, /default_range takes over silently/)
    end
  end

  describe "type metadata" do
    it "carries the RDF datatype each type maps to" do
      expect(described_class["integer"].uri).to eq("http://www.w3.org/2001/XMLSchema#integer")
      expect(described_class["integer"].curie).to eq("xsd:integer")
    end

    # These two are nodes in RDF, not literals, which is why part 5 gives them a
    # NodeKind check instead of a Datatype check.
    it "marks objectidentifier and nodeidentifier as node-valued" do
      expect(described_class["objectidentifier"]).to be_node
      expect(described_class["nodeidentifier"]).to be_node
      expect(described_class["string"]).not_to be_node
    end

    it "records curie as mapping to xsd:string, not to a URI type" do
      expect(described_class["curie"].uri).to eq("http://www.w3.org/2001/XMLSchema#string")
      expect(described_class["uriorcurie"].uri).to eq("http://www.w3.org/2001/XMLSchema#anyURI")
    end
  end
end
