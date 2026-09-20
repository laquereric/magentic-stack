# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::Frame::Validator do
  # Every check below is planted: the bundle is broken in the way the check
  # names, and the check is proven to fail. A checker that has never been
  # planted is not a gate.

  def bundle_in(dir) = Vv::Frame.load(dir).fetch(:bundle)

  it "passes a bundle whose links agree in both directions" do
    BundleFixture.in_tmp do |dir|
      res = described_class.call(bundle_in(dir))
      expect(res[:ok]).to be(true), -> { res[:errors].inspect }
      expect(res[:edges]).to eq(1)
    end
  end

  it "PLANT: a decision pointing at a frame section that does not exist" do
    adrs = [{ id: "0001", file: "0001-a.md", title: "A", paths: ["a"], enforced_by: [],
              frame: { "layer" => "repo", "phase" => "extract", "freezes_at_rung" => 3,
                       "evidence" => "gold", "instrument" => "refusal" },
              grounds: [["Nowhere", "nowhere", "points into the void."]] }]
    BundleFixture.in_tmp(adrs: adrs) do |dir|
      res = described_class.call(bundle_in(dir))
      expect(res[:ok]).to be(false)
      expect(res[:errors].map { |e| e[:reason] }).to include(:dangling_anchor)
    end
  end

  it "PLANT: a frame section citing a decision that is not in the bundle" do
    frame = [["Layers", "x\n\n**Grounded by**\n\n" \
                        "* [ADR 0001 — Ownership](./adr/0001-ownership.md) — the tier rule.\n" \
                        "* [ADR 0404 — Ghost](./adr/0404-ghost.md) — cites a decision nobody wrote.\n"]]
    BundleFixture.in_tmp(frame_sections: frame) do |dir|
      res = described_class.call(bundle_in(dir))
      expect(res[:errors].map { |e| e[:reason] }).to include(:dangling_decision)
    end
  end

  it "PLANT: a one-way link -- the decision claims the section, the section does not list it back" do
    frame = [["Layers", "x\n\n**Grounded by**\n\n(nothing listed)\n"]]
    BundleFixture.in_tmp(frame_sections: frame) do |dir|
      res = described_class.call(bundle_in(dir))
      expect(res[:ok]).to be(false)
      asym = res[:errors].select { |e| e[:reason] == :asymmetric }
      expect(asym.first[:because]).to include("not listed back")
    end
  end

  it "PLANT: a one-way link in the other direction" do
    adrs = [{ id: "0001", file: "0001-ownership.md", title: "Ownership", paths: ["grammar"],
              enforced_by: [],
              frame: { "layer" => "repo", "phase" => "extract", "freezes_at_rung" => 3,
                       "evidence" => "gold", "instrument" => "refusal" },
              grounds: [] }]
    BundleFixture.in_tmp(adrs: adrs) do |dir|
      res = described_class.call(bundle_in(dir))
      reasons = res[:errors].map { |e| e[:reason] }
      expect(reasons).to include(:asymmetric)
      expect(reasons).to include(:orphan)
    end
  end

  it "PLANT: a placement with an axis value outside its closed set" do
    adrs = [{ id: "0001", file: "0001-ownership.md", title: "Ownership", paths: ["grammar"],
              enforced_by: [],
              frame: { "layer" => "somewhere", "phase" => "extract", "freezes_at_rung" => 3,
                       "evidence" => "gold", "instrument" => "refusal" },
              grounds: [["Layers", "layers", "the tier rule."]] }]
    BundleFixture.in_tmp(adrs: adrs) do |dir|
      res = described_class.call(bundle_in(dir))
      expect(res[:errors].map { |e| e[:reason] }).to include(:unknown_placement)
    end
  end

  it "refuses to serve an invalid bundle through load!" do
    frame = [["Layers", "x\n\n**Grounded by**\n\n(nothing listed)\n"]]
    BundleFixture.in_tmp(frame_sections: frame) do |dir|
      res = Vv::Frame.load!(dir)
      expect(res[:ok]).to be(false)
      expect(res[:reason]).to eq(:bundle_invalid)
    end
  end

  describe "the real bundle", if: Dir.exist?(BUNDLE_ROOT) do
    it "has no dangling, asymmetric or orphaned links" do
      res = described_class.call(Vv::Frame.load(BUNDLE_ROOT).fetch(:bundle))
      expect(res[:errors]).to be_empty
    end
  end
end
