# frozen_string_literal: true

RSpec.describe Vv::Linkml::Unspecified do
  it "records every gap with a location, a claim and an interpretation" do
    described_class.all.each do |gap|
      expect(gap.where).to be_a(String).and(satisfy { |w| !w.empty? })
      expect(gap.what).to be_a(String).and(satisfy { |w| !w.empty? })
      expect(gap.interpretation).to be_a(String).and(satisfy { |w| !w.empty? })
    end
  end

  it "groups gaps by the area they affect" do
    expect(described_class.affecting(:derivation).map(&:key))
      .to include(:pk_undefined, :safe_functions, :inlined_as_dict)
    expect(described_class.affecting(:validation).map(&:key))
      .to include(:recommended_check, :deprecated_is_a_string)
    expect(described_class.affecting(:nothing_like_this)).to be_empty
  end

  # Each of these is a claim about the specification, checkable against the
  # sources named in docs/LinkedDataModelingLanguage.md. They are asserted here
  # so that a future reader can find them rather than rediscover them.
  describe "the metaslots the specification uses that do not exist" do
    it "confirms inlined_as_dict and inlined_as_expanded_dict are not in the metamodel" do
      expect(Vv::Linkml::Metamodel.slot("inlined_as_dict")).to be_nil
      expect(Vv::Linkml::Metamodel.slot("inlined_as_expanded_dict")).to be_nil
    end

    it "confirms the three that do exist" do
      %w[inlined inlined_as_list inlined_as_simple_dict].each do |ms|
        expect(Vv::Linkml::Metamodel.slot(ms)).not_to be_nil
      end
    end
  end

  describe "deprecated is a string, not a boolean" do
    it "confirms the range the deprecation checks compare against" do
      expect(Vv::Linkml::Metamodel.range_of("deprecated")).to eq("string")
    end
  end
end

RSpec.describe Vv::Linkml do
  it "reports the specification's own status rather than implying it is a standard" do
    expect(described_class::SPEC[:status])
      .to eq("This is a draft specification open from comments to all.")
  end

  it "exposes the census the normativity claim rests on" do
    expect(described_class.census[:normative_metaslots]).to eq(122)
    expect(described_class.census[:metaslots]).to eq(216)
  end

  it "loads, derives and validates through the module entry points" do
    schema = described_class.load(PERSON_SCHEMA)
    expect(described_class.derive(schema)).to be_complete
    expect(described_class.validate(
             { "id" => "P1", "name" => "A", "age_in_years" => 1, "vital_status" => "ALIVE" },
             schema: schema, target: "Person"
           )).to be_valid
  end
end
