# frozen_string_literal: true

require "spec_helper"

# Gap 68 U5. Discovery error must not become :no_storable_models.
RSpec.describe GraphReplay do
  it "storable_models is ok:true with models:[] when none declare triples" do
    allow(Rails.application.config).to receive(:eager_load).and_return(true)
    allow(ActiveRecord::Base).to receive(:descendants).and_return([])
    result = GraphReplay.storable_models
    expect(result[:ok]).to be(true)
    expect(result[:models]).to eq([])
  end

  it "storable_models is ok:false :storable_discovery_failed when discovery raises" do
    allow(Rails.application.config).to receive(:eager_load).and_return(true)
    allow(ActiveRecord::Base).to receive(:descendants)
      .and_raise(StandardError, "boom")
    result = GraphReplay.storable_models
    expect(result[:ok]).to be(false)
    expect(result[:reason]).to eq(:storable_discovery_failed)
    expect(result[:because]).to include("boom")
  end

  it "run forwards discovery refusal rather than :no_storable_models" do
    allow(GraphReplay).to receive(:storable_models).and_return(
      { ok: false, reason: :storable_discovery_failed, because: "StandardError: boom" },
    )
    result = GraphReplay.run
    expect(result[:ok]).to be(false)
    expect(result[:reason]).to eq(:storable_discovery_failed)
    expect(result[:because]).to include("boom")
  end

  it "run refuses :no_storable_models only on a successful empty catalogue" do
    allow(GraphReplay).to receive(:storable_models).and_return(
      { ok: true, models: [] },
    )
    result = GraphReplay.run
    expect(result[:ok]).to be(false)
    expect(result[:reason]).to eq(:no_storable_models)
  end
end
