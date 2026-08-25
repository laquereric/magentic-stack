# frozen_string_literal: true

require "spec_helper"
require "securerandom"

RSpec.describe Vv::Base do
  it "does not define the host ApplicationRecord" do
    expect(defined?(::ApplicationRecord)).to be_nil
    expect(Vv::Base::Actor.superclass).to eq(Vv::Base::Record)
    expect(Vv::Base::Record.abstract_class).to eq(true)
  end

  it "does not install bare constants unless asked" do
    expect(defined?(::Actor)).to be_nil
    expect(defined?(::Mission)).to be_nil
  end

  it "install_bare_constants! is opt-in and never-raise on collision" do
    box = Module.new
    r = described_class.install_bare_constants!(into: box)
    expect(r).to include(ok: true)
    expect(box::Actor).to eq(Vv::Base::Actor)
    again = described_class.install_bare_constants!(into: box)
    expect(again).to include(ok: false, reason: :constant_exists)
    expect(again[:because]).to include("Actor")
  end

  describe Vv::Base::LedgerPlaced do
    it "excludes private_local from cross_boundary and from Pull.relation" do
      pub  = Vv::Base::Mission.create!(title: "Public",  status: "ratified", ledger_placement: "canonical")
      priv = Vv::Base::Mission.create!(title: "Secret",  status: "ratified", ledger_placement: "private_local")

      expect(Vv::Base::Mission.all).to include(pub, priv) # semantics NOT silently narrowed
      expect(Vv::Base::Mission.cross_boundary).to include(pub)
      expect(Vv::Base::Mission.cross_boundary).not_to include(priv)

      pulled = Vv::Base::Pull.relation(Vv::Base::Mission)
      expect(pulled).to include(ok: true)
      expect(pulled[:relation]).to include(pub)
      expect(pulled[:relation]).not_to include(priv)
    end

    it "refuses an unknown ledger_placement" do
      m = Vv::Base::Mission.new(title: "X", status: "draft", ledger_placement: "leaked")
      expect(m.valid?).to eq(false)
      expect(m.errors[:ledger_placement]).not_to be_empty
    end

    it "Pull.relation refuses a class that is not ledger-placed" do
      r = Vv::Base::Pull.relation(String)
      expect(r).to include(ok: false, reason: :not_ledger_placed)
    end
  end

  describe "canonical homes" do
    it "persists Actor / Journey / Flow together" do
      actor = Vv::Base::Actor.create!(name: "Op", role_key: "op-#{SecureRandom.hex(3)}")
      journey = Vv::Base::Journey.create!(title: "J", status: "active", primary_actor: actor)
      flow = Vv::Base::Flow.create!(title: "F", status: "draft", journey: journey)
      expect(actor.journeys).to eq([journey])
      expect(journey.flows).to eq([flow])
    end

    it "persists Persona Mission Vision" do
      expect(Vv::Base::Persona.create!(name: "P", status: "ratified")).to be_persisted
      expect(Vv::Base::Mission.create!(title: "M", status: "ratified")).to be_persisted
      expect(Vv::Base::Vision.create!(title: "V", status: "draft")).to be_persisted
    end

    it "does not reach for RailsCpcp" do
      constants = [Vv::Base::Actor, Vv::Base::Persona, Vv::Base::Journey,
                   Vv::Base::Flow, Vv::Base::Mission, Vv::Base::Vision]
      constants.each do |k|
        expect(k.instance_methods(false)).not_to include(:as_api)
      end
      expect(defined?(RailsCpcp)).to be_nil
    end
  end
end
