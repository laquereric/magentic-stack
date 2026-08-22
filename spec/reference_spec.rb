# frozen_string_literal: true
RSpec.describe Mmg::EffectPlane::Reference do
  it "A18: bounds the preview even when the resolver ignores max_bytes" do
    flood = ->(_ref, _max) { { body: "x" * (10 * 1024 * 1024), media_type: "application/json" } }
    r = described_class.preview(reference: Fx.reference, resolver: flood, max_bytes: 512)
    expect(r[:ok]).to be(true)
    expect(r[:bytes]).to eq(512)
    expect(r[:truncated]).to be(true)
    expect(r[:sample].bytesize).to eq(512)
  end

  it "asks the resolver for at most max_bytes" do
    seen = nil
    spy = ->(_ref, max) { seen = max; { body: "ok" } }
    described_class.preview(reference: Fx.reference, resolver: spy, max_bytes: 64)
    expect(seen).to eq(64)
  end

  it "returns typed metadata alongside the bounded sample" do
    r = described_class.preview(reference: Fx.reference, resolver: ->(_r, _m) { { body: "{}" } }, max_bytes: 64)
    expect(r[:truncated]).to be(false)
    expect(r[:media_type]).to eq("application/json")
    expect(r[:schema_ref]).to eq("urn:mm:schema:result")
    expect(r[:snapshot_digest]).to eq(Fx::DIGEST)
  end

  it "refuses a non-positive max_bytes rather than materializing everything" do
    expect(described_class.preview(reference: Fx.reference, resolver: ->(_r, _m) { { body: "x" } }, max_bytes: 0))
      .to include(ok: false, reason: :invalid_max_bytes)
  end

  it "A19: a collected snapshot resolves to :snapshot_collected, not a false not-found" do
    collected = lambda do |_ref, _max|
      { ok: false, reason: :collected,
        tombstone: { former_snapshot_digest: Fx::DIGEST, collected_at: "2026-08-22", policy_reason: :expired } }
    end
    r = described_class.resolve(reference: Fx.reference, resolver: collected)
    expect(r[:reason]).to eq(:snapshot_collected)
    expect(r[:former_snapshot_digest]).to eq(Fx::DIGEST)
    expect(r[:policy_reason]).to eq(:expired)
  end

  it "tells the four outcomes apart" do
    expect(described_class::REFUSALS).to eq(%i[unknown_iri reference_inaccessible reference_expired snapshot_collected])
    expect(described_class.describe({})).to include(reason: :unknown_iri)
    expect(described_class.describe(Fx.reference(snapshot_digest: nil))).to include(reason: :reference_inaccessible)
  end

  it "builds a tombstone that names the former digest" do
    r = described_class.tombstone(reference: Fx.reference,
                                  collection_receipt: { former_snapshot_digest: Fx::DIGEST, policy_reason: :expired })
    expect(r).to include(ok: false, reason: :snapshot_collected, former_snapshot_digest: Fx::DIGEST)
  end

  it "refuses a tombstone that does not name what was collected" do
    expect(described_class.tombstone(reference: Fx.reference, collection_receipt: {}))
      .to include(ok: false, reason: :reference_inaccessible)
  end

  it "requires a resolver capability" do
    expect(described_class.resolve(reference: Fx.reference, resolver: nil)).to include(ok: false, reason: :no_resolver)
  end
end
