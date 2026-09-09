# frozen_string_literal: true

RSpec.describe Vv::Linkml::Metamodel do
  describe "the census" do
    # These numbers are the reason the gem distinguishes "in the metamodel" from
    # "in the specification". If they drift, the claim in the README drifted too.
    it "counts 216 metaslots, of which 122 are normative" do
      expect(described_class.slot_names.size).to eq(216)
      expect(described_class.normative_slots.size).to eq(122)
      expect(described_class.non_normative_slots.size).to eq(94)
    end

    it "counts 40 metaclasses, of which 15 are normative" do
      expect(described_class.class_names.size).to eq(40)
      expect(described_class.normative_classes.size).to eq(15)
    end

    it "reads metamodel_version 1.11.0" do
      expect(described_class::VERSION_READ).to eq("1.11.0")
    end
  end

  describe ".normative?" do
    it "is true for the metaslots the specification tables" do
      %w[name range required multivalued identifier key inlined class_uri
         slot_uri permissible_values].each do |ms|
        expect(described_class).to be_normative(ms), "expected #{ms} to be normative"
      end
    end

    # The documentation metaslots are the ones people assume are load-bearing.
    it "is false for description, comments, examples, title and deprecated" do
      %w[description comments examples title deprecated].each do |ms|
        expect(described_class).not_to be_normative(ms),
                                      "expected #{ms} to be outside SpecificationSubset"
      end
    end
  end

  describe ".inheritable?" do
    it "is true for exactly the 40 metaslots meta.yaml marks inherited" do
      expect(described_class.inheritable_slots.size).to eq(40)
    end

    it "propagates range, required and multivalued along the slot ancestry" do
      expect(described_class).to be_inheritable("range")
      expect(described_class).to be_inheritable("required")
      expect(described_class).to be_inheritable("multivalued")
    end

    # The one that surprises people: a slot inheriting from a documented parent
    # inherits none of the documentation.
    it "does not propagate description" do
      expect(described_class).not_to be_inheritable("description")
    end
  end

  describe "YAML aliases" do
    it "knows the ten metaslots whose YAML key differs from their name" do
      expect(described_class.aliases.size).to eq(10)
    end

    it "maps slot_definitions to slots and type_uri to uri" do
      expect(described_class.aliases).to include("slot_definitions" => "slots",
                                                 "type_uri" => "uri")
    end

    it "resolves a YAML key back to its metaslot" do
      expect(described_class.metaslot_for_yaml_key("slots")).to eq("slot_definitions")
      expect(described_class.metaslot_for_yaml_key("uri")).to eq("type_uri")
      expect(described_class.metaslot_for_yaml_key("range")).to eq("range")
    end
  end

  describe ".slot!" do
    it "refuses a name that is not in the metamodel and says why" do
      expect { described_class.slot!("reviewed_by") }
        .to raise_error(described_class::UnknownMetaslot, /annotations/)
    end
  end
end
