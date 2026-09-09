# frozen_string_literal: true

RSpec.describe Vv::Linkml::Schema do
  subject(:schema) { described_class.load(PERSON_SCHEMA) }

  it "indexes classes, slots and enums by name" do
    expect(schema.classes.keys).to contain_exactly("NamedThing", "Person")
    expect(schema.slots.keys).to contain_exactly("age_in_years", "vital_status")
    expect(schema.enums.keys).to contain_exactly("VitalStatusEnum")
  end

  it "reads attributes as SlotDefinitions scoped to their class" do
    attrs = schema.class_def("NamedThing").attributes
    expect(attrs.keys).to contain_exactly("id", "name")
    expect(attrs["id"]).to be_identifier
  end

  describe "the slot_definitions / slots alias" do
    it "accepts the metamodel name as well as the YAML key" do
      s = described_class.load(<<~YAML)
        id: http://example.org/x
        name: x
        slot_definitions:
          a: {range: string}
      YAML
      expect(s.slots.keys).to eq(["a"])
    end
  end

  describe "cross-type name uniqueness" do
    # 02instances.md: "Names MUST NOT be shared across definition types".
    it "refuses a name used by both a class and an enum" do
      yaml = <<~YAML
        id: http://example.org/x
        name: x
        classes:
          Status: {}
        enums:
          Status:
            permissible_values: {A: }
      YAML
      expect { described_class.load(yaml) }
        .to raise_error(described_class::NameCollision, /unique across definition types/)
    end

    it "allows the same name in only one table" do
      expect { described_class.load(PERSON_SCHEMA) }.not_to raise_error
    end
  end

  describe "#default_range" do
    # 04derived-schemas.md, Populate Schema Metadata: "if m'.default_range is not
    # set, set it to `string`."
    it "falls back to string and says the fallback was used" do
      expect(schema.default_range).to eq("string")
      expect(schema.default_range_asserted?).to be(false)
    end

    it "keeps a declared default_range and marks it asserted" do
      s = described_class.load("id: http://x\nname: x\ndefault_range: integer\n")
      expect(s.default_range).to eq("integer")
      expect(s.default_range_asserted?).to be(true)
    end
  end

  describe "#range_metatype" do
    it "distinguishes classes, enums and built-in types" do
      expect(schema.range_metatype("Person")).to eq(:class)
      expect(schema.range_metatype("VitalStatusEnum")).to eq(:enum)
      expect(schema.range_metatype("integer")).to eq(:builtin_type)
      expect(schema.range_metatype("Integer")).to be_nil
    end
  end

  describe "#unresolvable_ranges" do
    # LinkML does not raise on these. That is exactly why they are worth asking
    # for by name.
    it "finds a miscased built-in type and offers the fix" do
      s = described_class.load(<<~YAML)
        id: http://example.org/x
        name: x
        slots:
          flag: {range: Boolean}
      YAML
      expect(s.unresolvable_ranges).to eq([["flag", "Boolean", "boolean"]])
    end
  end

  describe "#default_namespace" do
    it "is nil when default_prefix names no entry in the prefix map" do
      s = described_class.load(<<~YAML)
        id: http://example.org/x
        name: x
        default_prefix: nowhere
        classes:
          A: {}
      YAML
      expect(s.default_namespace).to be_nil
    end

    it "is the expansion when the prefix is declared" do
      expect(schema.default_namespace).to eq("https://w3id.org/linkml/examples/person/")
    end
  end
end
