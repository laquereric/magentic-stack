# frozen_string_literal: true

RSpec.describe Vv::Linkml::Derivation do
  subject(:derivation) { described_class.new(schema) }

  let(:schema) { Vv::Linkml::Schema.load(PERSON_SCHEMA) }

  describe "L(v) -- normalize as list" do
    it "matches the table in 04derived-schemas.md" do
      expect(described_class.normalize_list(nil)).to eq([])
      expect(described_class.normalize_list([1, 2])).to eq([1, 2])
      expect(described_class.normalize_list("x")).to eq(["x"])
      expect(described_class.normalize_list(false)).to eq([false])
    end
  end

  describe "P(e) and A*(e)" do
    it "includes the builtin Any in parents, as the chapter specifies" do
      expect(derivation.parents(schema.class_def("Person")))
        .to eq(["NamedThing", described_class::ANY])
    end

    it "excludes Any from the ancestor walk, since no schema defines it" do
      expect(derivation.ancestors(schema.class_def("Person"), kind: :class))
        .to eq(["NamedThing"])
      expect(derivation.reflexive_ancestors(schema.class_def("Person"), kind: :class))
        .to eq(%w[Person NamedThing])
    end

    it "refuses to loop on circular inheritance" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          A: {is_a: B}
          B: {is_a: A}
      YAML
      expect(described_class.new(s).ancestors(s.class_def("A"), kind: :class))
        .to contain_exactly("A", "B")
    end
  end

  describe "ApplicableSlots(c)" do
    # DirectSlots(c) = L(c.slots) ∪ L(c.attributes), unioned over A*(c).
    it "unions a class's own slots with every ancestor's attributes" do
      expect(derivation.applicable_slots("Person"))
        .to contain_exactly("age_in_years", "vital_status", "id", "name")
    end
  end

  describe "DerivedSlot(m, s, c)" do
    let(:age) { derivation.derived_slot("age_in_years", "Person") }

    it "takes the range from the top-level slot" do
      expect(age.range).to eq("integer")
      expect(age.source_of("range")).to eq(:top_level_slot)
    end

    it "takes the refinement from the class's slot_usage" do
      expect(age).to be_required
      expect(age.source_of("required")).to eq(:slot_usage)
    end

    it "records provenance for every metaslot it filled" do
      expect(age.provenance).to include("range" => :top_level_slot,
                                        "required" => :slot_usage)
    end

    it "reaches attributes defined on an ancestor" do
      id = derivation.derived_slot("id", "Person")
      expect(id).to be_identifier
      expect(id.source_of("identifier")).to eq(:attribute)
    end

    describe "the default range chain" do
      # range ifabsent default_range (meta.yaml), and default_range ifabsent
      # string (04derived-schemas.md). That is the whole chain.
      it "defaults an unranged slot to string and marks it derived, not asserted" do
        s = Vv::Linkml::Schema.load(<<~YAML)
          id: http://x
          name: x
          classes:
            A: {slots: [note]}
          slots:
            note: {}
        YAML
        note = described_class.new(s).derived_slot("note", "A")
        expect(note.range).to eq("string")
        expect(note.source_of("range")).to eq(:default_range)
        expect(note).not_to be_asserted("range")
        expect(note.notes.join).to match(/never declared a default_range/)
      end
    end

    describe "inheritance along the slot ancestry" do
      let(:inherited) do
        s = Vv::Linkml::Schema.load(<<~YAML)
          id: http://x
          name: x
          classes:
            A: {slots: [child]}
          slots:
            parent:
              range: integer
              required: true
              description: the parent's documentation
            child:
              is_a: parent
        YAML
        described_class.new(s).derived_slot("child", "A")
      end

      it "propagates the inheritable metaslots" do
        expect(inherited.range).to eq("integer")
        expect(inherited).to be_required
        expect(inherited.source_of("range")).to eq(:slot_ancestor)
      end

      # description is not marked `inherited` in meta.yaml. This is the check
      # that would fail if the inheritable set were treated as "everything".
      it "does not propagate description, which is not an inheritable metaslot" do
        expect(inherited.description).to be_nil
      end
    end

    describe "mixins outrank is_a" do
      # 04derived-schemas.md's ApplySlotUsage iterates mixins before is_a. Most
      # object-oriented intuition puts the primary parent first.
      # Uses a metaslot whose combination rule is plain precedence, so the two
      # orderings give different answers. min()/max() metaslots would agree
      # either way and prove nothing.
      it "takes the mixin's refinement over the is_a parent's" do
        s = Vv::Linkml::Schema.load(<<~YAML)
          id: http://x
          name: x
          classes:
            Base:
              slots: [v]
              slot_usage:
                v: {description: from the is_a parent, pattern: "^base"}
            Mix:
              mixin: true
              slot_usage:
                v: {description: from the mixin, pattern: "^mix"}
            C:
              is_a: Base
              mixins: [Mix]
          slots:
            v: {range: string}
        YAML
        v = described_class.new(s).derived_slot("v", "C")
        expect(v.description).to eq("from the mixin")
        expect(v.pattern).to eq("^mix")
      end
    end

    describe "AddMissingValues" do
      # The chapter's rule is `PK(c)=None => s.inlined=True`, using a PK()
      # function it never defines and passing the containing class where the
      # range class is meant. See Unspecified::GAPS[:add_missing_values_target].
      it "infers inlined for a range class with no identifier or key" do
        s = Vv::Linkml::Schema.load(<<~YAML)
          id: http://x
          name: x
          classes:
            Address:
              attributes:
                street: {range: string}
            Person:
              slots: [address]
          slots:
            address: {range: Address}
        YAML
        addr = described_class.new(s).derived_slot("address", "Person")
        expect(addr).to be_inlined
        expect(addr.source_of("inlined")).to eq(:add_missing_values)
        expect(addr.notes.join).to match(/no identifier or key slot/)
      end

      it "leaves inlined alone when the range class can be referenced" do
        addr = derivation.derived_slot("vital_status", "Person")
        expect(addr.assigned?("inlined")).to be(false)
      end
    end
  end

  describe "CombineSlotsMetaslots" do
    # Transcribed from the table; the row order is load-bearing.
    it "takes min for maximum_value and max for minimum_value" do
      expect(derivation.combine_metaslot("maximum_value", 10, 5).first).to eq(5)
      expect(derivation.combine_metaslot("minimum_value", 10, 5).first).to eq(10)
    end

    it "ORs booleans" do
      expect(derivation.combine_metaslot("required", false, true).first).to be(true)
    end

    it "unions multivalued metaslots" do
      expect(derivation.combine_metaslot("mixins", ["A"], ["B"]).first).to eq(%w[A B])
    end

    it "gives precedence to the first slot for everything else" do
      expect(derivation.combine_metaslot("description", "a", "b").first).to eq("a")
    end

    describe "the underdetermined rows" do
      it "keeps the higher-precedence pattern and names the discarded one" do
        value, note = derivation.combine_metaslot("pattern", "^a", "^b")
        expect(value).to eq("^a")
        expect(note).to match(/CombinePattern/)
      end

      it "picks the more specific of two related ranges without a note" do
        value, note = derivation.combine_metaslot("range", "Person", "NamedThing")
        expect(value).to eq("Person")
        expect(note).to be_nil
      end

      it "flags two unrelated ranges, since the chapter yields a set for a 0..1 slot" do
        value, note = derivation.combine_metaslot("range", "Person", "VitalStatusEnum")
        expect(value).to eq("Person")
        expect(note).to match(/A\*\(r1\) ∩ A\*\(r2\), a set/)
      end
    end
  end

  describe "element URIs" do
    it "derives an unset class_uri from default_prefix and SafeCamel" do
      uri = derivation.element_uri("Person")
      expect(uri.curie).to eq("person:Person")
      expect(uri.uri).to eq("https://w3id.org/linkml/examples/person/Person")
      expect(uri).to be_derived
      expect(uri).to be_resolvable
    end

    it "derives an unset slot_uri with SafeSnake" do
      expect(derivation.element_uri("age_in_years").curie).to eq("person:age_in_years")
    end

    it "prefers a declared class_uri and marks it not derived" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        prefixes: {foo: "http://example.org/foo/", bar: "http://example.org/bar/"}
        default_prefix: foo
        classes:
          A: {class_uri: "bar:A"}
          B: {}
      YAML
      d = described_class.new(s)
      expect(d.element_uri("A").uri).to eq("http://example.org/bar/A")
      expect(d.element_uri("A")).not_to be_derived
      expect(d.element_uri("B").uri).to eq("http://example.org/foo/B")
    end

    # An unresolvable CURIE still looks like a CURIE. This is the check that it
    # is reported rather than emitted as a plausible IRI.
    it "reports a CURIE with no expansion as unresolvable" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        default_prefix: nowhere
        classes:
          A: {}
      YAML
      uri = described_class.new(s).element_uri("A")
      expect(uri.curie).to eq("nowhere:A")
      expect(uri).not_to be_resolvable
      expect(uri.uri).to be_nil
    end
  end

  describe "#derive" do
    subject(:derived) { derivation.derive }

    it "produces induced slots for every class, keyed by alias" do
      expect(derived.class_names).to contain_exactly("NamedThing", "Person")
      expect(derived.slots_for("Person").keys)
        .to contain_exactly("id", "name", "age_in_years", "vital_status")
    end

    it "is complete for a schema with no imports and no dynamic enums" do
      expect(derived).to be_complete
      expect(derived.gaps).to be_empty
    end

    describe "PK(c), the function the specification never defines" do
      it "is the identifier slot, inherited from an ancestor's attributes" do
        expect(derived.primary_key("Person").name).to eq("id")
      end

      it "is nil for a class with neither an identifier nor a key" do
        s = Vv::Linkml::Schema.load("id: http://x\nname: x\nclasses:\n  A: {}\n")
        expect(described_class.new(s).derive.primary_key("A")).to be_nil
      end
    end

    describe "unresolved imports" do
      # The alternative is a derived schema that looks finished and is missing
      # half its classes.
      it "does not raise, and reports the schema as incomplete" do
        s = Vv::Linkml::Schema.load(<<~YAML)
          id: http://x
          name: x
          imports: ["some_other_schema"]
          classes:
            A: {}
        YAML
        d = described_class.new(s).derive
        expect(d).not_to be_complete
        expect(d.gaps.join).to match(/was not resolved/)
      end

      it "resolves linkml:types from the built-in table" do
        s = Vv::Linkml::Schema.load(<<~YAML)
          id: http://x
          name: x
          imports: ["linkml:types"]
          classes:
            A: {slots: [v]}
          slots:
            v: {range: integer}
        YAML
        d = described_class.new(s).derive
        expect(d).to be_complete
        expect(d.sources).to include("types")
        expect(d.schema.types.keys.size).to eq(19)
      end

      # CombineElements raises on a name present in both inputs; LinkML has no
      # import namespacing to fall back on.
      it "raises when an import collides with a local name" do
        s = Vv::Linkml::Schema.load(<<~YAML)
          id: http://x
          name: x
          imports: ["linkml:types"]
          types:
            string: {uri: "xsd:string"}
        YAML
        expect { described_class.new(s).derive }
          .to raise_error(Vv::Linkml::Schema::NameCollision, /both/)
      end
    end

    describe "dynamic enums" do
      it "reports an enum whose values come from an external ontology" do
        s = Vv::Linkml::Schema.load(<<~YAML)
          id: http://x
          name: x
          enums:
            E:
              reachable_from:
                source_ontology: "obo:hp"
                source_nodes: ["HP:0000001"]
        YAML
        d = described_class.new(s).derive
        expect(d).not_to be_complete
        expect(d.gaps.join).to match(/reachable_from resolves against an external ontology/)
      end
    end
  end

  describe "#permissible_values" do
    it "returns the static values with nothing unresolved" do
      values, unresolved = derivation.permissible_values("VitalStatusEnum")
      expect(values).to eq(%w[ALIVE DECEASED])
      expect(unresolved).to be_empty
    end

    it "unions inherited enums" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        enums:
          Base:
            permissible_values: {A: , B: }
          Sub:
            inherits: [Base]
            permissible_values: {C: }
      YAML
      values, = described_class.new(s).permissible_values("Sub")
      expect(values).to contain_exactly("C", "A", "B")
    end
  end
end
