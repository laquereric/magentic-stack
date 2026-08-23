# frozen_string_literal: true
# The plane-boundary assertions: A20, A21, A22.
RSpec.describe "Plane boundaries" do
  it "A20: a dsh plugin registration with no durable write stays Plane A" do
    p = Fx.place(stage: :container_layer, target: "/proc/self/registrations")
    r = Mmg::EffectPlane::Classifier.classify(effect: "register:provider", placement: p,
                                              authority: {}, external_effects: [])
    expect(r[:classification]).to eq(:reversible)
    expect(r[:rollback]).to eq(:discard_and_recreate)
    expect(r[:conditions_required]).to be_empty
  end

  it "A21: a transaction with no explicit checkpoint creates no image layer" do
    # Correlation is not a snapshot boundary. With no checkpoint request there is
    # no snapshot contract at all, so nothing can emit a manifest.
    r = Mmg::EffectPlane::Snapshot.manifest(contract: {}, artifact: {})
    expect(r).to include(ok: false, reason: :contract_invalid)
  end

  it "A21b: an unapproved per-transaction cadence is refused, not costed" do
    r = Mmg::EffectPlane::Snapshot.manifest(
      contract: Fx.contract(policy: { snapshot_rate_approved: false }), artifact: {}
    )
    expect(r).to include(ok: false, reason: :snapshot_rate_unapproved)
  end

  it "A22: a fork never deletes the branch it left -- both digests stay named" do
    e = Fx.event[:event]
    expect(e[:parent_snapshot]).not_to be_nil
    expect(e[:selected_snapshot]).not_to be_nil
    expect(e[:parent_snapshot]).not_to eq(e[:selected_snapshot])
    # And the activation is itself an appended fact, not a mutation.
    expect(e[:type]).to eq(:EffectForkActivated)
  end

  it "A22b: forking cannot proceed without naming retained Plane B truth" do
    expect(Fx.event(authority_cursor: nil)).to include(ok: false, reason: :domain_truth_not_retained)
  end

  it "end-to-end: place -> classify -> validate -> manifest -> activate -> verify" do
    p = Mmg::EffectPlane::Placement.declare(
      effect_id: "tx-9", target: "/app/state.db",
      topology_evidence: { stage: :snapshot_image, digest: Fx::DIGEST, image_paths: ["/app"] },
      mount_inventory: [{ path: "/data", writable: true, disposition: :excluded }]
    )
    expect(p[:ok]).to be(true)

    c = Mmg::EffectPlane::Classifier.classify(
      effect: "tx-9", placement: p,
      authority: { role: :materialization, reconstructable_from: "urn:mm:res:cursor:8891" },
      external_effects: [{ id: "stripe", closure: :compensable }]
    )
    expect(c[:classification]).to eq(:fork_reversible)

    expect(Mmg::EffectPlane::Snapshot.validate_contract(contract: Fx.contract)[:ok]).to be(true)

    m = Mmg::EffectPlane::Snapshot.manifest(contract: Fx.contract,
                                            artifact: { snapshot_id: "s1", snapshot_image_digest: Fx::DIGEST })
    expect(m[:ok]).to be(true)

    e = Fx.event
    expect(e[:ok]).to be(true)

    v = Mmg::EffectPlane::Fork.verify_activation(
      event: e, append_receipt: { branch: "branch:prod", parent_snapshot: Fx::DIGEST2,
                                  selected_snapshot: Fx::DIGEST, event_ref: "evt-77" }
    )
    expect(v).to include(ok: true, activated: true)
  end
end
