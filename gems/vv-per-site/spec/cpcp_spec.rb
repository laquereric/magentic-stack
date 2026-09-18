# frozen_string_literal: true

require "spec_helper"

# A seam double: captures what register! declares (names, directions,
# required params) and lets the suite invoke each `via` handler, without
# loading rails-cpcp into this gem's own bundle.
class FakeCpcpProjection
  Op = Struct.new(:name, :direction, :params, :handler, :summary)
  attr_reader :operations

  def initialize
    @operations = {}
  end

  def operation(name, direction:, via:, params: [], summary: nil)
    @operations[name.to_s] = Op.new(name.to_s, direction.to_sym, Array(params).map(&:to_s), via, summary)
  end
end

module FakeRailsCpcp
  def self.projections
    @projections ||= {}
  end

  def self.project(model:, &blk)
    proj = FakeCpcpProjection.new
    proj.instance_eval(&blk)
    projections[model.to_s] = proj
  end
end

RSpec.describe Vv::PerSite::Cpcp do
  LEAF = "generated/personas.md#the-builder"

  before do
    Vv::PerSite::Okf::Importer.import(fixture_docs)
    Vv::PerSite::Site.create!(
      key: "wheat-stewardship",
      name: "Wheat Stewardship",
      host: "wheat.example",
      bundle_key: "fixture-stewardship"
    )
  end

  def key_params(extra = {})
    { "site_key" => "wheat-stewardship" }.merge(extra)
  end

  def bind_cta(action_kind: "calendar")
    described_class.cta_register(key_params(
      "okf_path" => LEAF, "key" => "builder-primer",
      "title" => "Request the technical primer",
      "action_kind" => action_kind, "payload" => { "event" => "discovery" }
    ))
  end

  describe "register!" do
    it "refuses rather than raising when rails-cpcp is absent" do
      hide_const("RailsCpcp")
      out = described_class.register!

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:cpcp_absent)
    end

    # Bundler evaluates every path gemspec at setup, so under the root bundle
    # ::RailsCpcp is defined with ONLY VERSION. That is still "absent": the
    # seam was never required.
    it "refuses when only the version stub is present" do
      stub_const("RailsCpcp", Module.new)
      out = described_class.register!

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:cpcp_absent)
    end

    context "against the seam" do
      before { stub_const("RailsCpcp", FakeRailsCpcp) }

      it "declares eight operations on the PerSite projection" do
        out = described_class.register!

        expect(out).to eq(ok: true, operations: described_class::OPERATIONS)
        ops = FakeRailsCpcp.projections["PerSite"].operations
        expect(ops.keys).to contain_exactly(*described_class::OPERATIONS)
      end

      it "reads through pulls and writes through pushes" do
        described_class.register!
        ops = FakeRailsCpcp.projections["PerSite"].operations

        pulls = %w[persite.guide.root persite.guide.at persite.guide.choose
                   persite.sites.list persite.leaves.list]
        pushes = %w[persite.site.register persite.cta.register persite.cta.remove]
        expect(ops.values.select { |o| o.direction == :pull }.map(&:name)).to contain_exactly(*pulls)
        expect(ops.values.select { |o| o.direction == :push }.map(&:name)).to contain_exactly(*pushes)
      end

      it "requires the params the handlers need" do
        described_class.register!
        ops = FakeRailsCpcp.projections["PerSite"].operations

        expect(ops["persite.guide.choose"].params).to include("site_key", "from_path", "child_path")
        expect(ops["persite.cta.register"].params).to include("operationId", "site_key", "okf_path")
      end

      it "reaches the guide through the declared handler" do
        described_class.register!
        via = FakeRailsCpcp.projections["PerSite"].operations["persite.guide.root"].handler

        out = via.call(key_params, nil)
        expect(out[:ok]).to be(true)
        expect(out[:node][:okf_path]).to eq("index.md")
        expect(out[:options].map { |o| o[:path] }).to include("generated")
      end
    end
  end

  describe "guide reads" do
    it "walks root, choose and at, with the site's CTA on the leaf" do
      expect(bind_cta[:ok]).to be(true)

      root = described_class.guide_root(key_params)
      expect(root[:ok]).to be(true)
      expect(root[:node][:okf_path]).to eq("index.md")
      expect(root[:node]).to include(:kind, :title, :cta_leaf, :body)
      expect(root[:cta]).to be_nil

      at = described_class.guide_at(key_params("okf_path" => LEAF))
      expect(at[:ok]).to be(true)
      expect(at[:cta]).to include(key: "builder-primer", title: "Request the technical primer",
                                  action_kind: "calendar", payload: { "event" => "discovery" },
                                  okf_path: LEAF, site_key: "wheat-stewardship")

      step = described_class.guide_choose(key_params("from_path" => "index.md", "child_path" => "generated"))
      expect(step[:ok]).to be(true)
      expect(step[:node][:okf_path]).to eq("generated")
    end

    it "refuses an unknown site, path, or non-child choice" do
      expect(described_class.guide_root("site_key" => "nope")).to include(ok: false, reason: :unknown_site)
      expect(described_class.guide_at(key_params("okf_path" => "missing.md"))).to include(ok: false, reason: :unknown_path)
      expect(described_class.guide_choose(key_params("from_path" => "index.md", "child_path" => "nope")))
        .to include(ok: false, reason: :not_a_child)
    end
  end

  describe "sites.list and leaves.list" do
    it "lists every site with its CTA count" do
      bind_cta
      out = described_class.sites_list

      expect(out[:ok]).to be(true)
      expect(out[:sites]).to include(include(key: "wheat-stewardship", bundle_key: "fixture-stewardship", cta_count: 1))
    end

    it "lists CTA leaves, with this site's binding beside each when asked" do
      bind_cta
      bare = described_class.leaves_list("bundle_key" => "fixture-stewardship")

      expect(bare[:ok]).to be(true)
      leaf = bare[:leaves].find { |l| l[:okf_path] == LEAF }
      expect(leaf[:cta]).to be_nil

      bound = described_class.leaves_list("bundle_key" => "fixture-stewardship", "site_key" => "wheat-stewardship")
      leaf = bound[:leaves].find { |l| l[:okf_path] == LEAF }
      expect(leaf[:cta]).to include(key: "builder-primer")
    end

    it "refuses a missing bundle or an unknown site" do
      expect(described_class.leaves_list({})).to include(ok: false, reason: :bundle_required)
      expect(described_class.leaves_list("bundle_key" => "fixture-stewardship", "site_key" => "nope"))
        .to include(ok: false, reason: :unknown_site)
    end
  end

  describe "site.register" do
    it "creates the site, then re-points it when the key exists" do
      created = described_class.site_register("operationId" => "op-1", "key" => "rye",
                                              "name" => "Rye", "bundle_key" => "fixture-stewardship",
                                              "host" => "rye.example")

      expect(created[:ok]).to be(true)
      expect(created[:created]).to be(true)
      expect(created[:site]).to include(key: "rye", cta_count: 0)

      updated = described_class.site_register("operationId" => "op-2", "key" => "rye",
                                              "name" => "Rye Mill", "bundle_key" => "fixture-stewardship")

      expect(updated[:ok]).to be(true)
      expect(updated[:created]).to be(false)
      expect(updated[:site][:name]).to eq("Rye Mill")
      expect(Vv::PerSite::Site.where(key: "rye").count).to eq(1)
    end

    it "refuses a site that fails validation, naming what is missing" do
      out = described_class.site_register("operationId" => "op-3", "key" => "bare",
                                          "name" => "", "bundle_key" => "fixture-stewardship")

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:site_invalid)
      expect(Vv::PerSite::Site.find_by(key: "bare")).to be_nil
    end
  end

  describe "cta.register" do
    it "binds the action onto the leaf and re-binds idempotently" do
      first = bind_cta
      expect(first[:ok]).to be(true)
      expect(first[:cta]).to include(key: "builder-primer", action_kind: "calendar")

      second = bind_cta
      expect(second[:ok]).to be(true)
      expect(Vv::PerSite::Cta.count).to eq(1)
    end

    it "refuses an unknown site, an unknown path, and a non-leaf node" do
      expect(described_class.cta_register(key_params("site_key" => "nope", "okf_path" => LEAF,
                                                     "key" => "k", "title" => "t", "action_kind" => "url")))
        .to include(ok: false, reason: :unknown_site)
      expect(described_class.cta_register(key_params("okf_path" => "missing.md",
                                                     "key" => "k", "title" => "t", "action_kind" => "url")))
        .to include(ok: false, reason: :unknown_path)
      expect(described_class.cta_register(key_params("okf_path" => "index.md",
                                                     "key" => "k", "title" => "t", "action_kind" => "url")))
        .to include(ok: false, reason: :not_a_cta_leaf)
    end

    it "refuses a bad action kind and a non-object payload, writing nothing" do
      bad_kind = key_params("okf_path" => LEAF, "key" => "k", "title" => "t", "action_kind" => "smoke-signal")
      bad_payload = key_params("okf_path" => LEAF, "key" => "k", "title" => "t",
                               "action_kind" => "url", "payload" => "https://x.example")

      expect(described_class.cta_register(bad_kind)).to include(ok: false, reason: :cta_invalid)
      expect(described_class.cta_register(bad_payload)).to include(ok: false, reason: :payload_invalid)
      expect(Vv::PerSite::Cta.count).to eq(0)
    end
  end

  describe "cta.remove" do
    it "unbinds the CTA and refuses when there is nothing there" do
      bind_cta
      out = described_class.cta_remove(key_params("okf_path" => LEAF))

      expect(out).to include(ok: true, removed: "builder-primer", okf_path: LEAF)
      expect(Vv::PerSite::Cta.count).to eq(0)

      again = described_class.cta_remove(key_params("okf_path" => LEAF))
      expect(again).to include(ok: false, reason: :no_binding)
    end
  end

  it "never raises, even when the store blows up" do
    allow(Vv::PerSite::Site).to receive(:find_by).and_raise(RuntimeError, "boom")

    out = described_class.guide_root(key_params)
    expect(out[:ok]).to be(false)
    expect(out[:reason]).to eq(:store_error)
    expect(out[:because]).to include("boom")
  end
end
