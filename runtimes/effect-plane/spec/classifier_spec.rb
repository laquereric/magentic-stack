# frozen_string_literal: true
RSpec.describe Mmg::EffectPlane::Classifier do
  def classify(placement, authority: { role: :materialization, reconstructable_from: "cursor:1" }, external: [])
    described_class.classify(effect: "e1", placement: placement, authority: authority, external_effects: external)
  end

  it "A03: a container layer is reversible only as discard-and-recreate" do
    r = classify(Fx.place(stage: :container_layer, target: "/tmp/x"))
    expect(r[:classification]).to eq(:reversible)
    expect(r[:rollback]).to eq(:discard_and_recreate)
  end

  it "A01: a source revision restores no runtime state" do
    r = classify(Fx.place(stage: :source, target: "app/x.rb", source_ref: "abc"))
    expect(r[:rollback]).to eq(:select_revision)
    expect(r[:because]).to include("restores no runtime state")
  end

  it "A05: a host volume NEVER classifies as image-selection rollback" do
    p = Mmg::EffectPlane::Placement.declare(
      effect_id: "e1", target: "/data/x", topology_evidence: { stage: :host_volume },
      mount_inventory: [{ path: "/data", writable: true, disposition: :excluded }]
    )

    bare = classify(p, authority: {})
    expect(bare[:classification]).to eq(:irreversible)
    expect(bare[:rollback]).to eq(:not_by_image_selection)

    cloned = classify(p, authority: { clone_evidence: "snap-1" })
    expect(cloned[:classification]).to eq(:compensable)
    expect(cloned[:rollback]).not_to eq(:fork_and_activate)
  end

  it "A08: a sole-authority store is refused, not fork_reversible" do
    r = classify(Fx.place(stage: :snapshot_image, digest: Fx::DIGEST),
                 authority: { role: :authoritative, reconstructable_from: "cursor:1" })
    expect(r).to include(ok: false, reason: :sole_authority_store, classification: :refused)
  end

  it "refuses a store whose authority role was never declared" do
    r = classify(Fx.place(stage: :snapshot_image, digest: Fx::DIGEST), authority: {})
    expect(r).to include(ok: false, reason: :unclassified_store_authority)
  end

  it "refuses a replayable store with no retained authority cursor" do
    r = classify(Fx.place(stage: :snapshot_image, digest: Fx::DIGEST), authority: { role: :projection })
    expect(r).to include(ok: false, reason: :domain_truth_not_retained)
  end

  it "A09: fork_reversible only with a replayable role AND a retained cursor" do
    r = classify(Fx.place(stage: :snapshot_image, digest: Fx::DIGEST))
    expect(r[:classification]).to eq(:fork_reversible)
    expect(r[:rollback]).to eq(:fork_and_activate)
    expect(r[:conditions_required]).to eq(%i[C1 C2 C3 C4 C5 C6 C7 C8 C9])
  end

  it "refuses when an external effect lacks closure" do
    r = classify(Fx.place(stage: :snapshot_image, digest: Fx::DIGEST),
                 external: [{ id: "email-send", closure: nil }])
    expect(r).to include(ok: false, reason: :external_effect_unclosed)
    expect(r[:because]).to include("email-send")
  end

  it "refuses to classify an unplaced target" do
    expect(classify({ ok: false, reason: :stage_not_evidenced })).to include(ok: false, reason: :unplaced_target)
    expect(classify(nil)).to include(ok: false, reason: :unplaced_target)
  end
end
