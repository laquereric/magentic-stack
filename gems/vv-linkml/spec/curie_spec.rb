# frozen_string_literal: true

RSpec.describe Vv::Linkml::Curie do
  let(:prefixes) do
    described_class::Prefixes.new("foo" => "http://example.org/foo/",
                                  "foobar" => "http://example.org/foo/bar/")
  end

  describe "URI(s, v) -- expansion" do
    it "concatenates the prefix reference with the CURIE reference" do
      expect(prefixes.expand("foo:A")).to eq("http://example.org/foo/A")
    end

    it "passes an absolute URI through unchanged" do
      expect(prefixes.expand("http://example.org/other/A")).to eq("http://example.org/other/A")
    end

    # An undeclared prefix has no expansion. Concatenating something plausible is
    # exactly how a schema ends up full of IRIs that parse and do not resolve.
    it "returns nil for an undeclared prefix rather than inventing an expansion" do
      expect(prefixes.expand("nope:A")).to be_nil
    end

    it "explains the refusal when asked to expand strictly" do
      expect { prefixes.expand!("nope:A") }
        .to raise_error(described_class::UnknownPrefix, /not in the schema's prefix map/)
    end
  end

  describe "CURIE(s, v) -- contraction" do
    # "The one with the shortest reference is chosen as the canonical", which is
    # the longest matching prefix.
    it "contracts by the longest matching prefix" do
      expect(prefixes.contract("http://example.org/foo/bar/X")).to eq("foobar:X")
    end

    it "returns nil when no prefix matches" do
      expect(prefixes.contract("http://elsewhere.org/X")).to be_nil
    end
  end

  # SafeCamel, SafeSnake and Safe are used in the Element URI table and defined
  # nowhere in the specification. These are this gem's interpretation, pinned so
  # a change to them is a visible change.
  describe "the undefined name-mangling functions" do
    it "camel-cases without flattening a name that is already CamelCase" do
      expect(described_class.safe_camel("named_thing")).to eq("NamedThing")
      expect(described_class.safe_camel("NamedThing")).to eq("NamedThing")
      expect(described_class.safe_camel("vital status")).to eq("VitalStatus")
    end

    it "snake-cases, breaking CamelCase word boundaries" do
      expect(described_class.safe_snake("age_in_years")).to eq("age_in_years")
      expect(described_class.safe_snake("vitalStatus")).to eq("vital_status")
      expect(described_class.safe_snake("HTTPStatus")).to eq("http_status")
    end

    it "percent-encodes anything outside RFC 3986's unreserved set" do
      expect(described_class.safe("Forklift Driver")).to eq("Forklift%20Driver")
      expect(described_class.safe("ALIVE")).to eq("ALIVE")
    end
  end
end
