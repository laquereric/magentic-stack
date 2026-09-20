# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Frame::ContextPack do
  def bundle_in(dir) = Vv::Frame.load(dir).fetch(:bundle)

  it "packs the frame sections and the governing decisions, in a stable order" do
    BundleFixture.in_tmp do |dir|
      pack = described_class.build(bundle: bundle_in(dir), path: "grammar/x.ttl").fetch(:pack)
      expect(pack.included.map { |p| p[:kind] }).to eq(%i[section decision])
      expect(pack).to be_complete
      expect(pack.estimated_tokens).to be > 0
    end
  end

  it "is deterministic: the same question twice gives the same pack" do
    BundleFixture.in_tmp do |dir|
      b = bundle_in(dir)
      a = described_class.build(bundle: b, path: "grammar/x.ttl").fetch(:pack)
      c = described_class.build(bundle: b, path: "grammar/x.ttl").fetch(:pack)
      expect(a.to_markdown).to eq(c.to_markdown)
    end
  end

  describe "no silent truncation" do
    it "PLANT: a budget too small names everything it could not carry, in the document" do
      BundleFixture.in_tmp do |dir|
        pack = described_class.build(bundle: bundle_in(dir), path: "grammar/x.ttl",
                                     budget_tokens: 1).fetch(:pack)
        expect(pack).not_to be_complete
        expect(pack.dropped).not_to be_empty
        md = pack.to_markdown
        expect(md).to include("## Omitted from this pack")
        expect(md).to include("This context is **partial**")
        expect(md).to include("budget_exhausted")
        pack.dropped.each { |d| expect(md).to include(d[:title]) }
      end
    end

    it "carries no omissions note when nothing was omitted" do
      BundleFixture.in_tmp do |dir|
        pack = described_class.build(bundle: bundle_in(dir), path: "grammar/x.ttl").fetch(:pack)
        expect(pack.to_markdown).not_to include("Omitted from this pack")
      end
    end

    it "every dropped item names its reason and its size" do
      BundleFixture.in_tmp do |dir|
        pack = described_class.build(bundle: bundle_in(dir), budget_tokens: 1).fetch(:pack)
        pack.dropped.each do |d|
          expect(d[:reason]).to eq(:budget_exhausted)
          expect(d[:estimated_tokens]).to be > 0
          expect(d[:id]).not_to be_empty
        end
      end
    end
  end

  describe "verbatim" do
    it "a packed decision is byte-identical to the decision on disk" do
      BundleFixture.in_tmp do |dir|
        b = bundle_in(dir)
        pack = described_class.build(bundle: b, path: "grammar/x.ttl").fetch(:pack)
        part = pack.parts.find { |p| p[:kind] == :decision }
        expect(part[:body]).to eq(b.decision("0001").fetch(:decision).body)
      end
    end
  end

  it "refuses a budget that is not positive" do
    BundleFixture.in_tmp do |dir|
      expect(described_class.build(bundle: bundle_in(dir), budget_tokens: 0))
        .to include(ok: false, reason: :budget_not_positive)
    end
  end

  it "can be narrowed to named sections" do
    BundleFixture.in_tmp do |dir|
      pack = described_class.build(bundle: bundle_in(dir), sections: ["layers"],
                                   path: "runtimes/nothing.rb").fetch(:pack)
      expect(pack.included.map { |p| p[:id] }).to eq(["layers"])
    end
  end

  describe "the smart zone", if: Dir.exist?(BUNDLE_ROOT) do
    let(:bundle) { Vv::Frame.load(BUNDLE_ROOT).fetch(:bundle) }

    it "the whole constraint set fits inside the smart zone" do
      pack = described_class.build(bundle: bundle).fetch(:pack)
      expect(pack).to be_complete
      expect(pack).to be_within_smart_zone
      expect(pack.estimated_tokens).to be < described_class::SMART_ZONE_TOKENS
    end

    it "a path-scoped pack is far smaller than the whole bundle" do
      whole = described_class.build(bundle: bundle).fetch(:pack)
      scoped = described_class.build(bundle: bundle, sections: %w[trajectory smart-context],
                                     path: "gems/rails-osi-level-8/lib/rails_osi_level_8").fetch(:pack)
      expect(scoped.estimated_tokens).to be < whole.estimated_tokens / 2
      expect(scoped).to be_complete
    end
  end
end
