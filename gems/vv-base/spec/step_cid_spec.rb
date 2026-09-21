# frozen_string_literal: true

require "spec_helper"

# ADR 0074 decision 6. The properties that matter are the ones a stored column
# would not have: same tuple always gives the same CID, different tuples never
# share one, and nothing mutable is in the digest.
RSpec.describe Vv::Base::StepCid do
  let(:tuple) do
    { bundle_key: "mind-pod", journey_key: "assure-an-effect-is-authorized",
      flow_key: "review-and-decide-authorization", step_key: "decide" }
  end

  it "is pure: four strings in, one CID out, no database" do
    expect(described_class.for(**tuple)).to eq(described_class.for(**tuple))
    expect(described_class.for(**tuple)).to start_with("cid:sha256:")
  end

  it "changes when any component of the tuple changes" do
    base = described_class.for(**tuple)
    tuple.each_key do |k|
      expect(described_class.for(**tuple.merge(k => "different"))).not_to eq(base)
    end
  end

  # The reason the separator is not a colon. These two tuples join to the same
  # string under any separator the keys can themselves contain, and a shared CID
  # for two different steps is the one failure this must not have.
  it "does not collide when a key contains the character a naive join would use" do
    a = described_class.for(bundle_key: "a:b", journey_key: "c",
                            flow_key: "f", step_key: "s")
    b = described_class.for(bundle_key: "a", journey_key: "b:c",
                            flow_key: "f", step_key: "s")
    expect(a).not_to eq(b)
  end

  it "refuses a blank component rather than digesting an empty string" do
    tuple.each_key do |k|
      expect { described_class.for(**tuple.merge(k => "  ")) }
        .to raise_error(ArgumentError, /#{k} is required/)
    end
  end

  it "refuses a component containing the separator" do
    expect { described_class.for(**tuple.merge(step_key: "ab")) }
      .to raise_error(ArgumentError, /may not contain the CID separator/)
  end

  context "against persisted rows" do
    def seed!(bundle_key: "spec")
      actor = Vv::Base::Actor.create!(name: "S", role_key: "steward", bundle_key: bundle_key)
      journey = Vv::Base::Journey.create!(
        title: "J", status: "draft", primary_actor: actor,
        bundle_key: bundle_key, journey_key: "register-a-subject"
      )
      flow = Vv::Base::Flow.create!(title: "F", status: "draft", journey: journey,
                                    flow_key: "declare-a-subject")
      flow.steps.create!(ordinal: 1, step_key: "subject.survey", title: "Review", kind: "inspect")
    end

    it "agrees with the pure function" do
      step = seed!
      expect(step.cid).to eq(
        described_class.for(bundle_key: "spec", journey_key: "register-a-subject",
                            flow_key: "declare-a-subject", step_key: "subject.survey")
      )
    end

    it "does not move when a mutable attribute changes" do
      step = seed!
      before = step.cid
      step.update!(title: "Renamed", ordinal: 7, route_key: "somewhere")
      expect(step.reload.cid).to eq(before)
    end

    it "differs for the same step_key in another bundle" do
      a = seed!(bundle_key: "spec")
      b = seed!(bundle_key: "other")
      expect(a.cid).not_to eq(b.cid)
    end

    it "resolves a cited CID back to exactly one step within its bundle" do
      step = seed!
      seed!(bundle_key: "other")
      found = described_class.resolve(step.cid, bundle_key: "spec")
      expect(found).to eq(step)
    end

    it "resolves to nothing for a CID minted in another bundle" do
      seed!(bundle_key: "spec")
      other = seed!(bundle_key: "other")
      expect(described_class.resolve(other.cid, bundle_key: "spec")).to be_nil
    end
  end
end
