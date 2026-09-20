# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Frame do
  describe "the boundary never raises" do
    it "refuses a missing bundle by name" do
      res = described_class.load("/nonexistent/path/nope")
      expect(res[:ok]).to be(false)
      expect(res[:reason]).to eq(:bundle_missing)
      expect(res[:because]).to include("nope")
    end

    it "refuses a directory with no frame document" do
      Dir.mktmpdir do |dir|
        res = described_class.load(dir)
        expect(res[:ok]).to be(false)
        expect(res[:reason]).to eq(:frame_missing)
      end
    end

    it "refuses unparseable frontmatter rather than half-loading it" do
      Dir.mktmpdir do |dir|
        BundleFixture.write(dir)
        File.write(File.join(dir, "adr", "0002-broken.md"), "---\ntitle: \"unterminated\n: :\n---\n\n# x\n")
        res = described_class.load(dir)
        expect(res[:ok]).to be(false)
        expect(res[:reason]).to eq(:frontmatter_invalid)
        expect(res[:because]).to include("0002-broken.md")
      end
    end

    it "refuses an unknown decision by id" do
      BundleFixture.in_tmp do |dir|
        b = described_class.load(dir).fetch(:bundle)
        expect(b.decision("9999")).to include(ok: false, reason: :unknown_decision)
      end
    end
  end

  describe "loading a valid bundle" do
    it "reads the frame, its sections, and the decisions" do
      BundleFixture.in_tmp do |dir|
        res = described_class.load(dir)
        expect(res[:ok]).to be(true)
        b = res[:bundle]
        expect(b.frame.title).to eq("Test Frame")
        expect(b.sections.map(&:slug)).to eq(["layers"])
        expect(b.decisions.map(&:id)).to eq(["0001"])
      end
    end

    it "serves a decision's text verbatim" do
      BundleFixture.in_tmp do |dir|
        b = described_class.load(dir).fetch(:bundle)
        d = b.decision("0001").fetch(:decision)
        on_disk = File.read(File.join(dir, "adr", "0001-ownership.md"))
        expect(on_disk).to include(d.body)
      end
    end

    it "zero-pads a short id rather than missing the decision" do
      BundleFixture.in_tmp do |dir|
        b = described_class.load(dir).fetch(:bundle)
        expect(b.decision("1")[:ok]).to be(true)
      end
    end
  end

  describe "#for_path" do
    it "returns the decisions that govern a path, most specific first" do
      adrs = [
        { id: "0001", file: "0001-a.md", title: "Broad", paths: ["gems"],
          frame: { "layer" => "gems", "phase" => "expand", "freezes_at_rung" => 2,
                   "evidence" => "silver", "instrument" => "rung" },
          enforced_by: [], grounds: [["Layers", "layers", "broad."]] },
        { id: "0002", file: "0002-b.md", title: "Narrow", paths: ["gems/vv-base/lib"],
          frame: { "layer" => "gems", "phase" => "expand", "freezes_at_rung" => 2,
                   "evidence" => "silver", "instrument" => "rung" },
          enforced_by: [], grounds: [["Layers", "layers", "narrow."]] }
      ]
      frame = [["Layers", "x\n\n**Grounded by**\n\n" \
                          "* [ADR 0001 — Broad](./adr/0001-a.md) — broad.\n" \
                          "* [ADR 0002 — Narrow](./adr/0002-b.md) — narrow.\n"]]
      BundleFixture.in_tmp(adrs: adrs, frame_sections: frame) do |dir|
        b = described_class.load(dir).fetch(:bundle)
        expect(b.for_path("gems/vv-base/lib/thing.rb").map(&:id)).to eq(%w[0002 0001])
        expect(b.for_path("gems/other/x.rb").map(&:id)).to eq(["0001"])
        expect(b.for_path("runtimes/x.rb")).to be_empty
      end
    end

    it "does not match a sibling directory that merely shares a prefix" do
      BundleFixture.in_tmp do |dir|
        b = described_class.load(dir).fetch(:bundle)
        expect(b.for_path("grammar-notes/x.md")).to be_empty
        expect(b.for_path("grammar/osi-level-8/spec.ttl").map(&:id)).to eq(["0001"])
      end
    end
  end

  describe "the ledger" do
    it "counts paid entries against declared liabilities" do
      adrs = [
        { id: "0001", file: "0001-a.md", title: "Gated", paths: ["a"], enforced_by: ["t/check.py"],
          frame: { "layer" => "repo", "phase" => "extract", "freezes_at_rung" => 3,
                   "evidence" => "gold", "instrument" => "refusal" },
          grounds: [["Layers", "layers", "gated."]] },
        { id: "0002", file: "0002-b.md", title: "Declared", paths: ["b"], enforced_by: [], unenforced: true,
          frame: { "layer" => "repo", "phase" => "extract", "freezes_at_rung" => 3,
                   "evidence" => "gold", "instrument" => "ledger" },
          grounds: [["Layers", "layers", "declared."]] }
      ]
      frame = [["Layers", "x\n\n**Grounded by**\n\n" \
                          "* [ADR 0001 — Gated](./adr/0001-a.md) — gated.\n" \
                          "* [ADR 0002 — Declared](./adr/0002-b.md) — declared.\n"]]
      BundleFixture.in_tmp(adrs: adrs, frame_sections: frame) do |dir|
        b = described_class.load(dir).fetch(:bundle)
        expect(b.ledger).to eq(enforced: 1, unenforced: 1, ungated: 0, total: 2)
      end
    end
  end

  describe "the real bundle", if: Dir.exist?(BUNDLE_ROOT) do
    let(:bundle) { described_class.load(BUNDLE_ROOT).fetch(:bundle) }

    it "loads and validates" do
      res = described_class.load!(BUNDLE_ROOT)
      expect(res[:ok]).to be(true), -> { res[:because].inspect }
      expect(res[:validation][:edges]).to be > 100
    end

    it "answers which decisions govern a substrate path" do
      govern = bundle.for_path("gems/rails-osi-level-8/lib/rails_osi_level_8/profile9")
      expect(govern).not_to be_empty
      expect(govern.first.placement.known?).to be(true)
    end

    it "carries every decision at a known placement" do
      expect(bundle.decisions.reject { |d| d.placement.known? }).to be_empty
    end
  end
end
