# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)

require "vv-linkml"

# The published LinkML metamodel, copied verbatim into spec/fixtures. See
# spec/fixtures/linkml-model/PROVENANCE.md for the sources and their hashes.
module LinkmlFixtures
  DIR = File.expand_path("fixtures/linkml-model", __dir__)

  def fixture_path(name) = File.join(DIR, name)

  # Resolves `linkml:types`, `linkml:mappings` and so on from the fixture
  # directory, which is what the metamodel's own `imports` name.
  def self.resolver
    lambda do |name, _schema|
      path = File.join(DIR, "#{name.to_s.sub('linkml:', '')}.yaml")
      File.exist?(path) ? Vv::Linkml::Schema.load_file(path) : nil
    end
  end

  # Derivation over 102KB of schema is the slowest thing in the suite and is
  # deterministic, so it runs once.
  def self.derived_metamodel
    @derived_metamodel ||=
      Vv::Linkml::Derivation
      .new(Vv::Linkml::Schema.load_file(File.join(DIR, "meta.yaml")))
      .derive(resolver: resolver)
  end
end

RSpec.configure do |config|
  config.expect_with(:rspec) { |c| c.syntax = :expect }
  config.disable_monkey_patching!
  config.order = :random
  Kernel.srand config.seed
  config.include LinkmlFixtures
end

# The schema from 04derived-schemas.md's "Informative Example", flattened into
# one file (the chapter splits it across person.yaml and core.yaml and imports
# one from the other).
PERSON_SCHEMA = <<~YAML
  id: https://w3id.org/linkml/examples/person
  name: person
  prefixes:
    person: https://w3id.org/linkml/examples/person/
    linkml: https://w3id.org/linkml/
  default_prefix: person
  classes:
    NamedThing:
      attributes:
        id:
          range: string
          identifier: true
        name:
          range: string
          required: true
    Person:
      is_a: NamedThing
      description: A person, living or dead
      slots:
        - age_in_years
        - vital_status
      slot_usage:
        age_in_years:
          required: true
  slots:
    age_in_years:
      description: The age of a person in years
      range: integer
      multivalued: false
    vital_status:
      range: VitalStatusEnum
  enums:
    VitalStatusEnum:
      permissible_values:
        ALIVE:
        DECEASED:
YAML
