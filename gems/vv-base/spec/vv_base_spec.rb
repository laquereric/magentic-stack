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
      actor = Vv::Base::Actor.create!(name: "Op", role_key: "op-#{SecureRandom.hex(3)}", bundle_key: "spec")
      journey = Vv::Base::Journey.create!(title: "J", status: "active", primary_actor: actor, bundle_key: "spec", journey_key: "j-#{SecureRandom.hex(3)}")
      flow = Vv::Base::Flow.create!(title: "F", status: "draft", journey: journey, flow_key: "f-#{SecureRandom.hex(3)}")
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

  describe "F2 flow steps and information model" do
    def journey_with_draft_flow
      actor = Vv::Base::Actor.create!(name: "Op", role_key: "op-#{SecureRandom.hex(3)}", bundle_key: "spec")
      journey = Vv::Base::Journey.create!(title: "J", status: "active", primary_actor: actor, bundle_key: "spec", journey_key: "j-#{SecureRandom.hex(3)}")
      flow = Vv::Base::Flow.create!(title: "F", status: "draft", journey: journey, task_goal: "collect", flow_key: "f-#{SecureRandom.hex(3)}")
      [journey, flow]
    end

    it "refuses an active collect/decide flow with zero steps" do
      _journey, flow = journey_with_draft_flow
      flow.status = "active"
      expect(flow.valid?).to eq(false)
      expect(flow.errors[:steps]).to include("active_flow_requires_steps")
    end

    it "activates a decide flow once it has a step" do
      _journey, flow = journey_with_draft_flow
      model = Vv::Base::InformationModel.create!(key: "j-decision-#{SecureRandom.hex(3)}", title: "Decision", bundle_key: "spec")
      flow.steps.create!(
        ordinal: 1, step_key: "decide", title: "Decide", kind: "decide",
        information_model: model, route_key: "decide"
      )
      expect(flow.update(status: "active")).to eq(true)
      expect(flow.reload.steps.size).to eq(1)
    end

    it "stores due_on as datatype date, not string; datatype enum is closed" do
      model = Vv::Base::InformationModel.create!(key: "due-#{SecureRandom.hex(3)}", title: "Due", bundle_key: "spec")
      due = Vv::Base::InformationField.create!(
        information_model: model, name: "due_on", datatype: "date",
        required: true, cardinality: "1", ordinal: 1
      )
      expect(due.datatype).to eq("date")
      expect(due.datatype).not_to eq("string")
      fake = Vv::Base::InformationField.new(
        information_model: model, name: "also_due", datatype: "varchar",
        required: true, cardinality: "1", ordinal: 2
      )
      expect(fake.valid?).to eq(false)
      expect(fake.errors[:datatype]).not_to be_empty
    end

    it "requires an information model on a collect step" do
      _journey, flow = journey_with_draft_flow
      step = Vv::Base::FlowStep.new(
        flow: flow, ordinal: 1, step_key: "form", title: "Form", kind: "collect"
      )
      expect(step.valid?).to eq(false)
      expect(step.errors[:information_model]).not_to be_empty
    end
  end
end
