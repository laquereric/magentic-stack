# frozen_string_literal: true
RSpec.describe Mmg::EffectPlane::Fork do
  it "A15: the event names branch, parent, selected, cursor, and volume disposition" do
    e = Fx.event[:event]
    expect(e[:type]).to eq(:EffectForkActivated)
    expect(e.keys).to include(:branch, :parent_snapshot, :selected_snapshot, :authority_cursor, :volume_disposition)
    expect(e[:selected_snapshot]).to eq(Fx::DIGEST)
    expect(e[:parent_snapshot]).to eq(Fx::DIGEST2)
  end

  it "does not stamp its own time -- activated_at belongs to the event owner" do
    expect(Fx.event[:event]).not_to have_key(:activated_at)
  end

  it "A14: refuses an activation that leaves the writable volume attached" do
    expect(Fx.event(volume_disposition: nil)).to include(ok: false, reason: :unresolved_writable_volume)
    r = Fx.event(volume_disposition: :existing_rw_attached)
    expect(r).to include(ok: false, reason: :unresolved_writable_volume)
    expect(r[:because]).to include("is not a rollback")
  end

  it "refuses an activation with no retained authority cursor" do
    expect(Fx.event(authority_cursor: "")).to include(ok: false, reason: :domain_truth_not_retained)
  end

  it "refuses a no-op activation onto the already-active snapshot" do
    expect(Fx.event(selected_snapshot: Fx::DIGEST2)).to include(ok: false, reason: :no_op_activation)
  end

  it "refuses an unknown activation reason" do
    expect(Fx.event(reason: :because_i_said_so)).to include(ok: false, reason: :unknown_reason)
  end

  describe ".verify_activation" do
    def receipt(**over)
      { branch: "branch:prod", parent_snapshot: Fx::DIGEST2, selected_snapshot: Fx::DIGEST,
        event_ref: "evt-1" }.merge(over)
    end

    it "accepts a receipt matching the proposed activation" do
      r = described_class.verify_activation(event: Fx.event, append_receipt: receipt)
      expect(r).to include(ok: true, activated: true, event_ref: "evt-1")
    end

    it "A16: refuses a valid payload with no append receipt" do
      expect(described_class.verify_activation(event: Fx.event, append_receipt: nil))
        .to include(ok: false, reason: :fork_not_recorded)
    end

    it "refuses a receipt that does not match the activation" do
      r = described_class.verify_activation(event: Fx.event, append_receipt: receipt(selected_snapshot: "sha256:other"))
      expect(r).to include(ok: false, reason: :fork_not_recorded)
      expect(r[:because]).to include("selected_snapshot")
    end

    it "refuses a receipt with no event reference" do
      expect(described_class.verify_activation(event: Fx.event, append_receipt: receipt(event_ref: nil)))
        .to include(ok: false, reason: :fork_not_recorded)
    end
  end

  describe ".activatable? -- addressable is not activatable" do
    let(:good) { { path: :rebuilt_release, release_packet_verified: true, binds_to_digest: Fx::DIGEST } }

    it "is both when retained with admissible provenance" do
      r = described_class.activatable?(snapshot: Fx::DIGEST, retention: { retained: true }, provenance: good)
      expect(r).to include(addressable: true, activatable: true)
    end

    it "stays ADDRESSABLE for audit while ceasing to be ACTIVATABLE" do
      r = described_class.activatable?(snapshot: Fx::DIGEST, retention: { retained: true },
                                       provenance: { path: :attested_packet, attestation: "sig" })
      expect(r[:addressable]).to be(true)
      expect(r[:activatable]).to be(false)
      expect(r[:because]).to include("addressable for audit")
    end

    it "is neither once collected" do
      r = described_class.activatable?(snapshot: Fx::DIGEST, retention: { retained: false }, provenance: good)
      expect(r).to include(addressable: false, activatable: false, reason: :snapshot_collected)
    end
  end
end
