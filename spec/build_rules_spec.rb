# frozen_string_literal: true
RSpec.describe Vv::DockerSwap::BuildRules do
  S = Vv::DockerSwap::BuildRules::Step

  describe ".cache_order_ok?" do
    it "accepts dependencies copied before source" do
      steps = [S.new(kind: :from), S.new(kind: :copy_dependencies), S.new(kind: :run), S.new(kind: :copy_source)]
      expect(described_class.cache_order_ok?(steps)[:ordered]).to be(true)
    end

    it "flags source copied before dependencies" do
      steps = [S.new(kind: :from), S.new(kind: :copy_source), S.new(kind: :copy_dependencies)]
      r = described_class.cache_order_ok?(steps)
      expect(r[:ordered]).to be(false)
      expect(r[:because]).to include("re-run bundle install")
    end

    it "refuses a plan with no dependency copy at all" do
      r = described_class.cache_order_ok?([S.new(kind: :from), S.new(kind: :copy_source)])
      expect(r).to include(ok: false, reason: :no_dependency_copy)
    end
  end

  describe ".leaked_build_packages" do
    it "passes when build packages are purged in the same RUN" do
      steps = [S.new(kind: :run, installs: %w[build-essential libpq-dev], purges: %w[build-essential libpq-dev])]
      expect(described_class.leaked_build_packages(steps)).to be_empty
    end

    it "flags a purge that happens in a LATER step" do
      steps = [S.new(kind: :run, installs: %w[build-essential], purges: []),
               S.new(kind: :run, installs: [], purges: %w[build-essential])]
      leaks = described_class.leaked_build_packages(steps)
      expect(leaks.map { |l| l[:package] }).to eq(["build-essential"])
      expect(leaks.first[:because]).to include("already committed")
    end

    it "does not flag runtime packages that are meant to survive" do
      steps = [S.new(kind: :run, installs: %w[libpq5 ca-certificates], purges: [])]
      expect(described_class.leaked_build_packages(steps)).to be_empty
    end
  end

  describe ".classify_package" do
    it "separates build-only from runtime" do
      expect(described_class.classify_package("libpq-dev")[:kind]).to eq(:build_only)
      expect(described_class.classify_package("libpq5")[:kind]).to eq(:runtime)
    end

    it "refuses an unclassified package rather than assuming it is safe" do
      expect(described_class.classify_package("imagemagick")).to include(ok: false, reason: :unknown_package)
    end
  end

  it "ships a dockerignore baseline that excludes the git dir and test trees" do
    expect(described_class::DOCKERIGNORE_BASELINE).to include(".git", "spec/", "vendor/bundle/")
  end
end
