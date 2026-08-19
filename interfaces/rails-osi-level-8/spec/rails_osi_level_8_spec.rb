# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "pathname"

RSpec.describe RailsOsiLevel8 do
  it "exposes VERSION" do
    expect(RailsOsiLevel8::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
  end

  it "aliases OsiLevel8" do
    expect(OsiLevel8).to equal(RailsOsiLevel8)
  end

  it "Ledger.crosses_boundary? denies private_local" do
    expect(RailsOsiLevel8::Ledger.crosses_boundary?(:canonical)).to be(true)
    expect(RailsOsiLevel8::Ledger.crosses_boundary?(:private_local)).to be(false)
  end

  it "LedgerPolicy places note.create request on sync_intent" do
    expect(
      RailsOsiLevel8::LedgerPolicy.placement_for!(operation: "note.create", evidence: :request)
    ).to eq("sync_intent")
  end

  describe "Grounding minimal closed-shape" do
    before do
      root = Pathname(File.expand_path("../data/osi-level-8", __dir__))
      RailsOsiLevel8.configure do |c|
        c.shape_root = root
        c.profile_catalog = RailsOsiLevel8::ProfileCatalog.default(root)
      end
    end

    it "refuses note.create without idempotency key / title" do
      r = RailsOsiLevel8::Grounding.validate({}, profile: "P1::NoteCreateEffectShape")
      expect(r.conforms?).to be(false)
      expect(r.safe_report["violations"]).not_to be_empty
    end

    it "accepts a shaped note.create effect" do
      r = RailsOsiLevel8::Grounding.validate(
        { "title" => "hi", "operationId" => "op-1", "idempotencyKey" => "op-1" },
        profile: "P1::NoteCreateEffectShape"
      )
      expect(r.conforms?).to be(true)
    end
  end
end
