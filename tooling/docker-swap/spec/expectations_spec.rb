# frozen_string_literal: true
RSpec.describe Vv::DockerSwap::Expectations do
  it "claims disk and pull bandwidth" do
    expect(described_class.optimizes?(:disk)[:optimized]).to be(true)
    expect(described_class.optimizes?(:pull_bandwidth)[:optimized]).to be(true)
  end

  it "explicitly does NOT claim RAM -- the caveat this module exists to preserve" do
    r = described_class.optimizes?(:ram)
    expect(r[:ok]).to be(true)
    expect(r[:optimized]).to be(false)
    expect(r[:because]).to include("processes that actually run")
  end

  it "keeps ram out of the optimized list so a refactor cannot quietly add it" do
    expect(described_class::OPTIMIZES).not_to include(:ram)
    expect(described_class::DOES_NOT_OPTIMIZE).to include(:ram)
  end

  it "refuses a resource the doctrine makes no claim about" do
    expect(described_class.optimizes?(:carbon)).to include(ok: false, reason: :unknown_resource)
  end

  it "names what must stay out of the writable container layer" do
    expect(described_class::BELONGS_IN_VOLUME_OR_SERVICE).to include(:database_data, :uploads)
    expect(described_class::BELONGS_ON_STDOUT).to eq([:logs])
  end
end
