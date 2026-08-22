# frozen_string_literal: true
RSpec.describe Mmg::EffectPlane::Snapshot do
  def validate(**over) = described_class.validate_contract(contract: Fx.contract(**over))

  it "accepts a contract satisfying all of C1-C9" do
    r = validate
    expect(r[:ok]).to be(true)
    expect(r[:satisfied]).to eq(%i[C1 C2 C3 C4 C5 C6 C7 C8 C9])
  end

  it "C1: refuses when domain truth is not retained" do
    expect(validate(authority: { retained: false, cursor: "c" })).to include(reason: :domain_truth_not_retained)
    expect(validate(authority: { retained: true })).to include(reason: :domain_truth_not_retained)
  end

  it "A08 / C2: refuses a store declared sole authority" do
    r = validate(stores: [{ name: "site", role: :authoritative, reconstruction: "n/a" }])
    expect(r).to include(reason: :sole_authority_store)
  end

  it "C2 carries TWO distinct refusals -- unclassified is not the same failure as sole-authority" do
    unclassified = validate(stores: [{ name: "site", reconstruction: "x" }])
    sole         = validate(stores: [{ name: "site", role: :authoritative, reconstruction: "n/a" }])
    expect(unclassified[:reason]).to eq(:unclassified_store_authority)
    expect(sole[:reason]).to eq(:sole_authority_store)
    expect(unclassified[:reason]).not_to eq(sole[:reason])
    expect(Mmg::EffectPlane::Vocabulary::CONDITIONS[:C2][:also]).to include(:sole_authority_store)
  end

  it "C2: refuses a store with no declared role or no reconstruction path" do
    expect(validate(stores: [{ name: "site", reconstruction: "x" }])).to include(reason: :unclassified_store_authority)
    expect(validate(stores: [{ name: "site", role: :projection }])).to include(reason: :unclassified_store_authority)
  end

  it "A06 / C3: refuses a store with no writer-fence acknowledgement" do
    r = validate(barrier: { id: "b", fenced: true, writers: %w[puma worker],
                            acknowledgements: %w[puma], receipts: { "site" => "r" } })
    expect(r).to include(reason: :quiescence_unproven)
    expect(r[:because]).to include("worker")
  end

  it "C3: refuses a capture with no store consistency receipt (a raw WAL copy)" do
    r = validate(barrier: { id: "b", fenced: true, writers: %w[puma], acknowledgements: %w[puma], receipts: {} })
    expect(r).to include(reason: :quiescence_unproven)
    expect(r[:because]).to include("consistency-safe capture receipt")
  end

  it "A07: an satisfied barrier still leaves the other conditions to check" do
    r = validate(retention: { owner: "platform" })
    expect(r[:ok]).to be(false)
    expect(r[:satisfied]).to include(:C3)
    expect(r[:reason]).to eq(:retention_undefined)
  end

  it "A14 / C4: refuses an undisposed writable mount" do
    r = validate(mounts: [{ path: "/data", writable: true, disposition: nil }])
    expect(r).to include(reason: :unresolved_writable_volume)
  end

  it "A13 / C6: refuses forbidden content in the payload" do
    r = validate(includes: %i[app_code credentials])
    expect(r).to include(reason: :forbidden_snapshot_content)
    expect(r[:because]).to include("credentials")
  end

  it "C7: refuses an unclosed external effect" do
    r = validate(external_effects: [{ id: "webhook", closure: nil }])
    expect(r).to include(reason: :external_effect_unclosed)
  end

  it "A16 / C8: refuses an activation that was never appended" do
    expect(validate(fork: {})).to include(reason: :fork_not_recorded)
  end

  it "C9: refuses retention with no owner, class, expiry, or hold" do
    expect(validate(retention: { owner: "p", retention_class: :checkpoint })).to include(reason: :retention_undefined)
    expect(validate(retention: { owner: "p", retention_class: :checkpoint, hold: true })[:ok]).to be(true)
  end

  it "is all-or-nothing and reports EVERY failed condition, not just the first" do
    r = validate(authority: {}, retention: {}, fork: {})
    expect(r[:failed].map { |f| f[:condition] }).to eq(%i[C1 C8 C9])
  end

  describe "provenance -- the docker commit ruling" do
    it "A10: a bare committed digest with no packet or attestation is unbound" do
      expect(described_class.admissibility({ digest: Fx::DIGEST })).to include(ok: false, reason: :provenance_unbound)
      expect(described_class.admissibility(nil)).to include(ok: false, reason: :provenance_unbound)
    end

    it "A11: a rebuilt release that verifies AND binds to the digest is admissible" do
      r = described_class.admissibility({ path: :rebuilt_release, release_packet_verified: true,
                                          binds_to_digest: Fx::DIGEST })
      expect(r).to include(ok: true, path: :rebuilt_release, admissible: true)
    end

    it "A11b: a rebuilt release that verifies but does NOT bind is unbound" do
      r = described_class.admissibility({ path: :rebuilt_release, release_packet_verified: true })
      expect(r).to include(ok: false, reason: :provenance_unbound)
    end

    it "A12: an attested packet is well-formed but NOT admissible under the current rule" do
      r = described_class.admissibility({ path: :attested_packet, attestation: "sig" })
      expect(r[:ok]).to be(true)
      expect(r[:admissible]).to be(false)
      expect(r[:requires]).to eq(:control_plane_extension)
      expect(r[:because]).to include("must not be presented as an admitted Revision")
    end
  end

  describe ".manifest" do
    it "refuses to emit a manifest for an invalid contract" do
      r = described_class.manifest(contract: Fx.contract(authority: {}), artifact: {})
      expect(r).to include(ok: false, reason: :contract_invalid)
    end

    it "A17: refuses an unapproved snapshot cadence rather than guessing a cost" do
      r = described_class.manifest(contract: Fx.contract(policy: { snapshot_rate_approved: false }), artifact: {})
      expect(r).to include(ok: false, reason: :snapshot_rate_unapproved)
    end

    it "emits the declarative manifest, marking an absent source_ref :unknown not nil" do
      r = described_class.manifest(contract: Fx.contract,
                                   artifact: { snapshot_id: "s1", snapshot_image_digest: Fx::DIGEST,
                                               base_release_digest: Fx::DIGEST2, layers: { new_layer_ids: %w[l1] } })
      expect(r[:ok]).to be(true)
      expect(r[:manifest][:source_ref]).to eq(:unknown)
      expect(r[:manifest][:authority_cursor]).to eq("urn:mm:res:cursor:8891")
      expect(r[:manifest][:branch]).to eq("branch:prod")
    end
  end
end
