# frozen_string_literal: true

require "digest"

# The gem run against the real LinkML metamodel, not a hand-written miniature.
#
# meta.yaml is itself a LinkML schema -- 03schemas.md says so: "Every LinkML
# schema m is itself an instance of a special class SchemaDefinition that forms
# part of a special schema called the LinkML metamodel." So loading and deriving
# it exercises the whole path over 102KB of schema written by the people who
# wrote the specification.
#
# Two of this gem's interpretations of undefined functions are checked here
# against published fact: SafeCamel must produce the class_uri LinkML actually
# publishes, and the alias handling must let `slot_definitions` surface as
# `slots`. A miniature schema could not test either.
RSpec.describe "conformance against the published LinkML metamodel" do
  # Deriving the full 102KB metamodel takes long enough that doing it per
  # example would dominate the suite; it is deterministic, so once is enough.
  let(:schema) { Vv::Linkml::Schema.load_file(fixture_path("meta.yaml")) }
  let(:derived) { LinkmlFixtures.derived_metamodel }

  describe "the generated tables still match their source" do
    # If a fixture is refreshed without regenerating the tables, everything else
    # in this suite starts testing a stale metamodel. This is the check that
    # notices.
    it "reads the meta.yaml the tables were generated from" do
      digest = Digest::SHA256.file(fixture_path("meta.yaml")).hexdigest
      expect(digest).to eq("7f9e39fb18ab4bc034c00f37cd291fbb87f8fb1e2f36f43e566918bd56b96673")
    end

    it "agrees with meta.yaml on the number of metaslots and metaclasses" do
      expect(schema.slots.size).to eq(Vv::Linkml::Metamodel.slot_names.size)
      expect(schema.classes.size).to eq(Vv::Linkml::Metamodel.class_names.size)
    end

    it "agrees with meta.yaml on which metaslots are inheritable" do
      from_source = schema.slots.select { |_, s| s["inherited"] == true }.keys.sort
      expect(from_source).to eq(Vv::Linkml::Metamodel.inheritable_slots.sort)
    end

    it "agrees with meta.yaml on the SpecificationSubset" do
      from_source = schema.slots.select do |_, s|
        Array(s["in_subset"]).include?("SpecificationSubset")
      end.keys.sort
      expect(from_source).to eq(Vv::Linkml::Metamodel.normative_slots.sort)
    end
  end

  describe "loading" do
    it "loads the metamodel without a name collision" do
      expect(schema.classes.size).to eq(40)
      expect(schema.slots.size).to eq(216)
      expect(schema.enums.keys).to include("pv_formula_options")
    end

    it "reads its declared metamodel_version" do
      expect(schema.raw["metamodel_version"]).to eq(Vv::Linkml::Metamodel::VERSION_READ)
    end
  end

  describe "derivation" do
    it "resolves the whole import closure with no gaps" do
      expect(derived.sources)
        .to contain_exactly("meta", "types", "mappings", "extensions", "annotations", "units")
      expect(derived.gaps).to be_empty
      expect(derived).to be_complete
    end

    it "brings the 19 built-in types in through linkml:types" do
      expect(derived.schema.types.size).to eq(19)
    end

    # The metamodel declares `slot_definitions` with `alias: slots`. This is the
    # case that would break under a literal reading of DerivedSlot's pseudocode,
    # which seeds alias=name before any combination and gives the seed
    # precedence. See Unspecified::GAPS[:alias_seeding].
    it "surfaces slot_definitions under its declared alias, slots" do
      induced = derived.slots_for("schema_definition")
      expect(induced).to have_key("slots")
      expect(induced["slots"].name).to eq("slot_definitions")
      expect(induced["slots"].range).to eq("slot_definition")
      expect(induced["slots"]).to be_multivalued
    end

    it "induces inherited slots down the metamodel's own hierarchy" do
      # class_definition is_a definition is_a element, and element carries `name`.
      induced = derived.slots_for("class_definition")
      expect(induced).to have_key("name")
      expect(induced["name"]).to be_identifier
    end

    # K(v) in 04derived-schemas.md: "In the metamodel, the identifier
    # SlotDefinitionName is always `name`". PK() -- the function the
    # specification never defines -- must agree.
    it "finds `name` as the primary key of every metaclass that has one" do
      %w[class_definition slot_definition enum_definition type_definition
         schema_definition].each do |c|
        expect(derived.primary_key(c)&.name).to eq("name"), "for #{c}"
      end
    end

    describe "derived URIs match what LinkML publishes" do
      # SafeCamel and SafeSnake are undefined in the specification. These are the
      # IRIs the metamodel actually resolves at, so they are the check on this
      # gem's interpretation of both.
      it "derives class_uris that match the published w3id IRIs" do
        {
          "class_definition" => "https://w3id.org/linkml/ClassDefinition",
          "slot_definition" => "https://w3id.org/linkml/SlotDefinition",
          "schema_definition" => "https://w3id.org/linkml/SchemaDefinition",
          "permissible_value" => "https://w3id.org/linkml/PermissibleValue"
        }.each do |name, iri|
          expect(derived.uri_for(name).uri).to eq(iri), "for #{name}"
        end
      end

      it "derives slot_uris that match the published w3id IRIs" do
        {
          "range" => "https://w3id.org/linkml/range",
          "slot_definitions" => "https://w3id.org/linkml/slot_definitions",
          "permissible_values" => "https://w3id.org/linkml/permissible_values"
        }.each do |name, iri|
          expect(derived.uri_for(name).uri).to eq(iri), "for #{name}"
        end
      end

      it "keeps a declared slot_uri instead of deriving one" do
        # meta.yaml gives `alias` the slot_uri skos:prefLabel.
        uri = derived.uri_for("alias")
        expect(uri).not_to be_derived
        expect(uri.uri).to eq("http://www.w3.org/2004/02/skos/core#prefLabel")
      end

      it "resolves every element URI it derives" do
        unresolvable = derived.uris.values.reject(&:resolvable?)
        expect(unresolvable).to be_empty
      end
    end
  end

  describe "validating a schema as an instance of the metamodel" do
    # 05validation.md: "A LinkML schema is a LinkML instance that conforms to the
    # LinkML metamodel. As such, it can be validated in the same way as any other
    # LinkML instance."
    let(:validator) { Vv::Linkml::Validator.new(derived) }

    it "accepts a minimal well-formed schema" do
      instance = { "name" => "example", "id" => "https://example.org/example" }
      expect(validator.validate(instance, "schema_definition")).to be_valid
    end

    it "rejects a schema with no id, which the metamodel requires" do
      report = validator.validate({ "name" => "example" }, "schema_definition")
      expect(report).not_to be_valid
      expect(report.errors.map(&:path)).to include("$.id")
    end

    it "rejects a metaslot assignment the metamodel does not define" do
      instance = { "name" => "example", "id" => "https://example.org/x",
                   "reviewed_by" => "someone" }
      report = validator.validate(instance, "schema_definition")
      problem = report.errors.find { |p| p.check == "ApplicableSlot" }
      expect(problem.message).to match(/no applicable slot "reviewed_by"/)
    end
  end
end
