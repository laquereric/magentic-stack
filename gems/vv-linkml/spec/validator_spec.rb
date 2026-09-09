# frozen_string_literal: true

RSpec.describe Vv::Linkml::Validator do
  subject(:validator) { described_class.new(schema) }

  let(:schema) { Vv::Linkml::Schema.load(PERSON_SCHEMA) }
  let(:valid) do
    { "id" => "P1", "name" => "Alex", "age_in_years" => 40, "vital_status" => "ALIVE" }
  end

  it "passes a conforming instance, conclusively" do
    report = validator.validate(valid, "Person")
    expect(report).to be_valid
    expect(report).to be_conclusive
    expect(report.problems).to be_empty
  end

  describe "core checks" do
    it "reports a required slot that is absent" do
      report = validator.validate(valid.reject { |k, _| k == "age_in_years" }, "Person")
      expect(report).not_to be_valid
      expect(report.errors.map(&:check)).to include("Required")
    end

    # 02instances.md: "An assignment of a slot to None is equivalent to omitting
    # that assignment." So an explicit null is the same failure as an absence.
    it "treats an explicit null as absence" do
      report = validator.validate(valid.merge("age_in_years" => nil), "Person")
      expect(report.errors.map(&:check)).to include("Required")
    end

    # meta.yaml: "An identifier slot is automatically required. Identifiers
    # cannot be optional." The schema never writes `required: true` on `id`.
    it "requires an identifier slot even though the schema never marked it required" do
      report = validator.validate(valid.reject { |k, _| k == "id" }, "Person")
      problem = report.errors.find { |p| p.path == "$.id" }
      expect(problem.check).to eq("Required")
      expect(problem.message).to match(/identifiers and keys are automatically required/)
    end

    it "reports a collection in a single-valued slot" do
      report = validator.validate(valid.merge("age_in_years" => [40, 41]), "Person")
      expect(report.errors.map(&:check)).to include("Singlevalued")
    end

    it "reports an assignment naming no applicable slot" do
      report = validator.validate(valid.merge("nickname" => "Al"), "Person")
      problem = report.errors.find { |p| p.check == "ApplicableSlot" }
      expect(problem.message).to match(/no applicable slot "nickname"/)
    end
  end

  describe "atomic checks" do
    it "reports a value that does not conform to its type" do
      report = validator.validate(valid.merge("age_in_years" => "forty"), "Person")
      problem = report.errors.find { |p| p.check == "Datatype" }
      expect(problem.message).to match(%r{XMLSchema#integer})
    end

    it "accepts an integer for a float range, since an integer is a decimal value" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          M: {slots: [v]}
        slots:
          v: {range: float}
      YAML
      expect(described_class.new(s).validate({ "v" => 1 }, "M")).to be_valid
    end

    it "checks pattern and bounds" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          M: {slots: [code, n]}
        slots:
          code: {range: string, pattern: "^[A-Z]{2}$"}
          n: {range: integer, minimum_value: 1, maximum_value: 10}
      YAML
      v = described_class.new(s)
      expect(v.validate({ "code" => "ab", "n" => 5 }, "M").errors.map(&:check)).to eq(["Pattern"])
      expect(v.validate({ "code" => "AB", "n" => 99 }, "M").errors.map(&:check)).to eq(["MaximumValue"])
      expect(v.validate({ "code" => "AB", "n" => 0 }, "M").errors.map(&:check)).to eq(["MinimumValue"])
    end
  end

  describe "enum checks" do
    it "reports a value outside the permissible values" do
      report = validator.validate(valid.merge("vital_status" => "UNDEAD"), "Person")
      problem = report.errors.find { |p| p.check == "Permissible" }
      expect(problem.message).to match(/ALIVE, DECEASED/)
    end

    # An enum drawing its values from an external ontology cannot be checked
    # here. Reporting "no errors" for it would be a lie by omission.
    it "skips the check for a dynamic enum rather than passing it" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          M: {slots: [term]}
        slots:
          term: {range: E}
        enums:
          E:
            reachable_from:
              source_ontology: "obo:hp"
              source_nodes: ["HP:0000001"]
      YAML
      report = described_class.new(s).validate({ "term" => "anything" }, "M")
      expect(report).to be_valid
      expect(report).not_to be_conclusive
      expect(report.skipped.join).to match(/Permissible was not checked/)
    end
  end

  describe "inlined vs referenced" do
    let(:nested_schema) do
      Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          Address:
            attributes:
              street: {range: string}
          Company:
            attributes:
              id: {range: string, identifier: true}
          Person:
            slots: [address, employer]
        slots:
          address: {range: Address}
          employer: {range: Company, inlined: false}
      YAML
    end

    it "validates an inlined object against its range class" do
      report = described_class.new(nested_schema)
                              .validate({ "address" => { "street" => 1 } }, "Person")
      problem = report.errors.find { |p| p.check == "Datatype" }
      expect(problem.path).to eq("$.address.street")
    end

    it "reports an object where the slot asked for a reference" do
      report = described_class.new(nested_schema)
                              .validate({ "employer" => { "id" => "C1" } }, "Person")
      expect(report.errors.map(&:check)).to include("Referenced")
    end

    it "reports a reference to a class that nothing can reference" do
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
          address: {range: Address, inlined: false}
      YAML
      report = described_class.new(s).validate({ "address" => "somewhere" }, "Person")
      problem = report.errors.find { |p| p.check == "Inlined" }
      expect(problem.message).to match(/has no identifier or key slot/)
    end
  end

  describe "abstract and mixin classes" do
    it "refuses to instantiate them" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          A: {abstract: true}
          M: {mixin: true}
      YAML
      v = described_class.new(s)
      expect(v.validate({}, "A").errors.map(&:check)).to eq(["Abstract"])
      expect(v.validate({}, "M").errors.map(&:check)).to eq(["Mixin"])
    end
  end

  describe "deprecation" do
    # meta.yaml gives `deprecated` range string, not boolean. 05validation.md's
    # tables compare `deprecated=True`, which no valid schema can satisfy.
    it "reads a non-empty deprecated string as deprecated, and warns" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          M: {slots: [old]}
        slots:
          old: {range: string, deprecated: use `new` instead}
      YAML
      report = described_class.new(s).validate({ "old" => "x" }, "M")
      expect(report).to be_valid
      expect(report.warnings.map(&:check)).to eq(["DeprecatedSlot"])
      expect(report.warnings.first.message).to match(/use `new` instead/)
    end
  end

  describe "conclusiveness" do
    # This is the result the gem exists to make visible: a pass that is a pass
    # over a subset.
    it "is valid but inconclusive when the schema leans on an unspecified section" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          M:
            slots: [a, b]
            rules:
              - preconditions: {slot_conditions: {a: {equals_string: "x"}}}
                postconditions: {slot_conditions: {b: {required: true}}}
        slots:
          a: {range: string}
          b: {range: string}
      YAML
      report = described_class.new(s).validate({ "a" => "x" }, "M")
      expect(report).to be_valid
      expect(report).not_to be_conclusive
      expect(report.skipped.join).to match(/"Rules" section is a heading with no content/)
      expect(report.to_s).to match(/inconclusive/)
    end

    it "names unique_keys as unimplementable too" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          M:
            slots: [a]
            unique_keys:
              k: {unique_key_slots: [a]}
        slots:
          a: {range: string}
      YAML
      report = described_class.new(s).validate({ "a" => "x" }, "M")
      expect(report.skipped.join).to match(/Uniqueness checks/)
    end
  end

  describe "severity" do
    it "reports a missing recommended slot as a warning, not an error" do
      s = Vv::Linkml::Schema.load(<<~YAML)
        id: http://x
        name: x
        classes:
          M: {slots: [a]}
        slots:
          a: {range: string, recommended: true}
      YAML
      report = described_class.new(s).validate({}, "M")
      expect(report).to be_valid
      expect(report.warnings.map(&:check)).to eq(["Recommended"])
    end
  end
end
