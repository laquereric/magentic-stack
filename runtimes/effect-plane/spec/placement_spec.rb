# frozen_string_literal: true
RSpec.describe Mmg::EffectPlane::Placement do
  it "A01: places a source target with a git SHA, and calls it select_revision" do
    r = Fx.place(stage: :source, target: "app/models/order.rb", source_ref: "abc1234")
    expect(r[:ok]).to be(true)
    expect(r[:placement][:stage]).to eq(:source)
    expect(r[:placement][:rollback]).to eq(:select_revision)
  end

  it "A02: places a verified release digest as oci_image / reinstantiate_verified_image" do
    r = Fx.place(stage: :oci_image, digest: Fx::DIGEST, release_verified: true)
    expect(r[:placement][:stage]).to eq(:oci_image)
    expect(r[:placement][:rollback]).to eq(:reinstantiate_verified_image)
  end

  it "A02b: refuses an oci_image digest with no verified release evidence" do
    r = Fx.place(stage: :oci_image, digest: Fx::DIGEST)
    expect(r).to include(ok: false, reason: :release_evidence_missing)
  end

  it "A03: places a container writable layer" do
    r = Fx.place(stage: :container_layer, target: "/tmp/scratch")
    expect(r[:placement][:stage]).to eq(:container_layer)
    expect(r[:placement][:rollback]).to eq(:discard_and_recreate)
  end

  it "A04: refuses a target claimed image-resident AND covered by an unresolved RW mount" do
    r = described_class.declare(
      effect_id: "e1", target: "/app/state.db",
      topology_evidence: { stage: :snapshot_image, digest: Fx::DIGEST, image_paths: ["/app"] },
      mount_inventory: [{ path: "/app", writable: true, disposition: nil }]
    )
    expect(r).to include(ok: false, reason: :ambiguous_mount)
    expect(r[:because]).to include("unresolved writable mount")
  end

  it "accepts the same target once the mount is explicitly disposed of" do
    r = described_class.declare(
      effect_id: "e1", target: "/app/state.db",
      topology_evidence: { stage: :snapshot_image, digest: Fx::DIGEST, image_paths: ["/app"] },
      mount_inventory: [{ path: "/app", writable: true, disposition: :branch_seeded }]
    )
    expect(r[:ok]).to be(true)
    expect(r[:placement][:stage]).to eq(:snapshot_image)
  end

  it "never infers a stage from the path when evidence declares none" do
    r = described_class.declare(effect_id: "e1", target: "/var/lib/postgresql/data",
                                topology_evidence: {}, mount_inventory: [])
    expect(r).to include(ok: false, reason: :stage_not_evidenced)
  end

  it "requires a covering writable mount before believing a :host_volume claim" do
    expect(Fx.place(stage: :host_volume, target: "/data/x")).to include(ok: false, reason: :volume_not_in_inventory)

    r = described_class.declare(
      effect_id: "e1", target: "/data/x", topology_evidence: { stage: :host_volume },
      mount_inventory: [{ path: "/data", writable: true, disposition: :excluded }]
    )
    expect(r[:placement][:stage]).to eq(:host_volume)
  end

  it "refuses a non-volume stage while an unresolved writable mount covers the target" do
    r = described_class.declare(
      effect_id: "e1", target: "/data/x", topology_evidence: { stage: :container_layer },
      mount_inventory: [{ path: "/data", writable: true, disposition: nil }]
    )
    expect(r).to include(ok: false, reason: :unresolved_writable_volume)
  end

  it "does not treat a sibling prefix as covering" do
    expect(described_class.covers?("/app", "/application/x")).to be(false)
    expect(described_class.covers?("/app", "/app/x")).to be(true)
    expect(described_class.covers?("/app", "/app")).to be(true)
  end
end
