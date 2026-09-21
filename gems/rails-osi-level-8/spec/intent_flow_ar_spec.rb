# frozen_string_literal: true

require "spec_helper"
require "vv-base"
require "active_record"

RSpec.describe "intent → ux lineage with vv-base", :intent_flow_ar do
  before(:context) do
    ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
    ActiveRecord::Migration.verbose = false
    # ADR 0074 decisions 1 and 2 are in this list because J1 now seeds through
    # Vv::Base::Seeder, which requires the key and bundle columns. Keys before
    # scope: the scoped index replaces the global one the first migration adds.
    %w[
      20260824120000_create_vv_base_canonical_homes.rb
      20260912000000_create_vv_base_flow_steps_and_information_models.rb
      20260921000000_add_natural_keys_to_journeys_and_flows.rb
      20260921000100_add_bundle_key_to_canonical_homes.rb
    ].each do |file|
      require File.expand_path("../../vv-base/db/migrate/#{file}", __dir__)
    end
    CreateVvBaseCanonicalHomes.new.change
    CreateVvBaseFlowStepsAndInformationModels.new.change
    AddNaturalKeysToJourneysAndFlows.new.change
    AddBundleKeyToCanonicalHomes.new.change
    RailsOsiLevel8::Intent::GraphStore.reset!
    RailsOsiLevel8::Profile9::Graph.reset!
    RailsOsiLevel8::Profile9::Graph.j1_journey_cid
  end

  after(:context) do
    RailsOsiLevel8::Profile9::Graph.reset!
    RailsOsiLevel8::Intent::GraphStore.reset!
  end

  def g = RailsOsiLevel8::Profile9::Graph

  it "J1 is a vv-base Journey whose projection CID is the P9 envelope cid" do
    expect(g.vv_base_ready?).to eq(true)
    journey = Vv::Base::Journey.find_by!(
      bundle_key: RailsOsiLevel8::Profile9::J1::BUNDLE_KEY,
      journey_key: RailsOsiLevel8::Profile9::J1::JOURNEY_KEY
    )
    expected = RailsOsiLevel8::Intent::Projection.for(journey)["cid"]
    expect(g.j1_journey_cid).to eq(expected)
    expect(g.j1_journey_cid).to start_with("cid:sha256:")
    expect(g.j1_journey_cid).not_to eq(RailsOsiLevel8::Profile9::Graph::JOURNEY_CID)
  end

  it "journey.get returns the same intentGroundingCid as Grounding.for_journey" do
    journey = Vv::Base::Journey.find_by!(
      bundle_key: RailsOsiLevel8::Profile9::J1::BUNDLE_KEY,
      journey_key: RailsOsiLevel8::Profile9::J1::JOURNEY_KEY
    )
    bound = RailsOsiLevel8::Intent::Grounding.for_journey(journey)
    expect(bound).not_to be_empty
    detail = RailsOsiLevel8::Profile9::Pulls.journey_get("journeyCid" => g.j1_journey_cid)
    expect(detail["intentGroundingCid"]).to eq(bound.first["cid"])
    expect(detail["cid"]).to eq(g.j1_journey_cid)
  end

  it "refuses a P9 journey CID that is not the vv-base projection" do
    real = g.journey(g.j1_journey_cid)
    g.journeys["cid:journey:rogue"] = real.merge("cid" => "cid:journey:rogue")
    expect {
      RailsOsiLevel8::Profile9::Pulls.journey_get("journeyCid" => "cid:journey:rogue")
    }.to raise_error(RailsOsiLevel8::KnownRefusal) { |e|
      expect(e.reason).to eq("UX_LINEAGE_UNRESOLVED")
      expect(e.because["resource"]).to eq("projection")
    }
  end

  it "page.get carries flow/step/acia/grounding cites" do
    bundle = RailsOsiLevel8::Profile9::Pulls.page_get(
      "pageCid" => g.j1_page_cid,
      "correlationId" => "corr-j1",
      "receiptSeed" => "seed-j1"
    )
    page = bundle["page"]
    expect(page["flowCid"]).to eq(g.j1_flow_cid)
    expect(page["stepKey"]).to eq(g.j1_step_key)
    expect(page["aciaCid"]).to be_present
    expect(page["intentGroundingCid"]).to eq(g.j1_grounding_cid)
  end
end
