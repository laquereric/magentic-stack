# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe "M9 deletion cascades" do
  before { Mmg::Medallion::Cascade.clear! }

  it "supersession stales Gold, it does not invalidate it" do
    r = Mmg::Medallion.cascade(iris: ["urn:mm:user/1"], kind: :supersession)
    expect(r[:ok]).to be(true)
    expect(r[:silver]).to eq("closed")
    expect(r[:gold]).to eq("stale")
    expect(Mmg::Medallion::Cascade.tombstoned?("urn:mm:user/1")).to be(true)
  end

  it "correction invalidates Gold" do
    r = Mmg::Medallion.cascade(iris: ["urn:mm:user/1"], kind: :correction)
    expect(r[:ok]).to be(true)
    expect(r[:silver]).to eq("closed")
    expect(r[:gold]).to eq("invalidated")
  end

  it "forget tombstones both tiers" do
    r = Mmg::Medallion.cascade(iris: ["urn:mm:episode/9"], kind: :forget)
    expect(r[:ok]).to be(true)
    expect(r[:silver]).to eq("tombstoned")
    expect(r[:gold]).to eq("tombstoned")
  end

  it "refuses an unknown kind rather than guessing a walk" do
    r = Mmg::Medallion.cascade(iris: ["urn:mm:user/1"], kind: :vibes)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:audit_rejected)
  end

  it "refuses a tombstone with no subject" do
    r = Mmg::Medallion.cascade(iris: [], kind: :forget)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:audit_rejected)
  end

  it "answers the EngineBinding M9 probe" do
    expect(Mmg::Medallion.respond_to?(:cascade)).to be(true)
  end
end
