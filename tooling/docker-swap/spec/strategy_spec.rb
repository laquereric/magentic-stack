# frozen_string_literal: true
RSpec.describe Vv::DockerSwap::Strategy do
  def choose(**kw)
    described_class.choose(**{ delta_gem_count: 2, conflicting_dependencies: false,
                               independent_release_required: false }.merge(kw))
  end

  it "picks the superset image for a modest, non-conflicting delta released together" do
    expect(choose[:design]).to eq(:superset)
  end

  it "picks the common base when services must be released independently" do
    r = choose(independent_release_required: true)
    expect(r[:design]).to eq(:common_base)
    expect(r[:because]).to include("independently")
  end

  it "picks the common base when the delta gems conflict" do
    expect(choose(conflicting_dependencies: true)[:design]).to eq(:common_base)
  end

  it "picks the common base once the delta exceeds the modest threshold" do
    expect(choose(delta_gem_count: described_class::MODEST_DELTA)[:design]).to eq(:superset)
    expect(choose(delta_gem_count: described_class::MODEST_DELTA + 1)[:design]).to eq(:common_base)
  end

  it "lets independent release override an otherwise ideal superset case" do
    expect(choose(delta_gem_count: 0, independent_release_required: true)[:design]).to eq(:common_base)
  end

  it "refuses a nonsense delta rather than guessing" do
    r = choose(delta_gem_count: -1)
    expect(r).to include(ok: false, reason: :invalid_delta_gem_count)
  end
end
