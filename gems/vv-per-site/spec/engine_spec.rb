# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::PerSite do
  it "exposes VERSION" do
    expect(Vv::PerSite::VERSION).to match(/\d+\.\d+\.\d+/)
  end

  it "loads the engine only when Rails::Engine is defined" do
    expect(defined?(Vv::PerSite::Engine)).to be_nil
  end

  it "has a db/seeds.rb Rails entry point" do
    path = File.expand_path("../db/seeds.rb", __dir__)
    expect(File.exist?(path)).to eq(true)
    expect(File.read(path)).to include("Vv::PerSite.load_seed")
  end

  it "has rake tasks for seed, load, import, and sync" do
    rake = File.read(File.expand_path("../tasks/vv_per_site.rake", __dir__))
    expect(rake).to include("task seed:")
    expect(rake).to include("task load:")
    expect(rake).to include("task import:")
    expect(rake).to include("task sync:")
  end
end
