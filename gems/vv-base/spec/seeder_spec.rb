# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "yaml"

# ADR 0074 decision 4. What is asserted here is mostly what the loader REFUSES:
# the whole point of a seeding contract is that a seed cannot quietly become a
# different seed.
RSpec.describe Vv::Base::Seeder do
  def seed_dir(yaml)
    dir = Pathname.new(Dir.mktmpdir)
    dir.join("seed.yml").write(yaml)
    dir
  end

  let(:good) do
    <<~YAML
      actors:
        - { role_key: steward, name: "The steward" }
      information_models:
        - key: si.subject
          title: "A stewarded subject"
          fields:
            - { ordinal: 1, name: label, datatype: string, required: true }
      journeys:
        - journey_key: register-a-subject
          title: "Register what you steward"
          status: draft
          primary_actor_role_key: steward
          flows:
            - flow_key: declare-a-subject
              title: "Declare a subject"
              status: draft
              steps:
                - { ordinal: 1, step_key: subject.survey, kind: inspect, title: "Review" }
                - { ordinal: 2, step_key: subject.describe, kind: collect, title: "Describe", information_model: si.subject }
    YAML
  end

  def load(yaml, bundle_key: "spec")
    described_class.load!(seed_root: seed_dir(yaml), bundle_key: bundle_key)
  end

  it "loads parent before child and resolves references by natural key" do
    r = load(good)
    expect(r[:ok]).to be true
    expect(r).to include(actors: 1, information_models: 1, information_fields: 1,
                         journeys: 1, flows: 1, flow_steps: 2)

    journey = Vv::Base::Journey.find_by(bundle_key: "spec", journey_key: "register-a-subject")
    expect(journey.primary_actor.role_key).to eq("steward")
    step = journey.flows.first.steps.find_by(step_key: "subject.describe")
    expect(step.information_model.key).to eq("si.subject")
  end

  it "is idempotent: loading twice updates rather than duplicates" do
    load(good)
    load(good)
    expect(Vv::Base::Journey.where(bundle_key: "spec").count).to eq(1)
    expect(Vv::Base::Flow.joins(:journey).where(journeys: { bundle_key: "spec" }).count).to eq(1)
    expect(Vv::Base::Actor.where(bundle_key: "spec", role_key: "steward").count).to eq(1)
  end

  it "scopes by bundle: the same keys in another bundle are separate rows" do
    load(good, bundle_key: "spec")
    load(good, bundle_key: "other")
    expect(Vv::Base::Journey.where(journey_key: "register-a-subject").count).to eq(2)
    expect(Vv::Base::Actor.where(role_key: "steward").count).to eq(2)
  end

  it "refuses an unknown key rather than skipping it" do
    r = load(good.sub("title: \"Register what you steward\"", "titel: \"Register what you steward\""))
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:unknown_key)
    expect(r[:because]).to include("titel")
  end

  it "refuses a journey with no journey_key instead of deriving one from the title" do
    doc = YAML.safe_load(good)
    doc["journeys"].first.delete("journey_key")
    r = load(YAML.dump(doc))
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:missing_key)
    expect(r[:because]).to include("never derived")
  end

  it "refuses a document whose bundle_key contradicts the caller" do
    r = load("bundle_key: somewhere-else\n#{good}")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:bundle_key_mismatch)
  end

  it "refuses a reference that does not resolve in this bundle" do
    r = load(good.sub("information_model: si.subject", "information_model: si.missing"))
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:unresolved_information_model)
  end

  it "requires a bundle_key and does not guess one" do
    r = described_class.load!(seed_root: seed_dir(good), bundle_key: nil)
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:no_bundle_key)
  end

  it "rolls back entirely when a later entry is refused" do
    bad = good + <<~YAML
      #{'  '}- journey_key: second
          title: "Second"
          status: draft
          primary_actor_role_key: nobody
    YAML
    r = load(bad)
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:unresolved_actor)
    expect(Vv::Base::Journey.where(bundle_key: "spec").count).to eq(0)
    expect(Vv::Base::Actor.where(bundle_key: "spec").count).to eq(0)
  end

  it "seeds an active flow, which validates that it has steps" do
    doc = YAML.safe_load(good)
    doc["journeys"].first["flows"].first["status"] = "active"
    r = load(YAML.dump(doc))
    expect(r[:ok]).to be true
    flow = Vv::Base::Flow.find_by(flow_key: "declare-a-subject")
    expect(flow.status).to eq("active")
    expect(flow.steps.count).to eq(2)
  end

  it "reports a missing seed root rather than raising" do
    r = described_class.load!(seed_root: "/nonexistent/seed/root", bundle_key: "spec")
    expect(r[:ok]).to be false
    expect(r[:reason]).to eq(:seed_missing)
  end
end
