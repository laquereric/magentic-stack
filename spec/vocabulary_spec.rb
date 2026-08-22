# frozen_string_literal: true
RSpec.describe Mmg::EffectPlane::Vocabulary do
  it "closes the stage set at five" do
    expect(described_class::STAGES.keys).to eq(%i[source oci_image container_layer snapshot_image host_volume])
  end

  it "gives a host volume a rollback that is NOT image selection" do
    expect(described_class.stage(:host_volume)[:rollback]).to eq(:not_by_image_selection)
  end

  it "gives a snapshot image fork-and-activate, never a rewind verb" do
    expect(described_class.stage(:snapshot_image)[:rollback]).to eq(:fork_and_activate)
  end

  it "refuses an unknown stage rather than coercing to the nearest match" do
    expect(described_class.stage(:volume)).to include(ok: false, reason: :unknown_stage)
  end

  it "carries C1-C9 with a distinct refusal each" do
    refusals = described_class::CONDITIONS.values.map { |c| c[:refusal] }
    expect(described_class::CONDITION_IDS.size).to eq(9)
    expect(refusals.uniq.size).to eq(9)
  end

  it "keeps :authoritative out of the replayable roles" do
    expect(described_class::STORE_ROLES).to include(:authoritative)
    expect(described_class::REPLAYABLE_ROLES).not_to include(:authoritative)
  end

  it "names the forbidden snapshot content classes" do
    expect(described_class::FORBIDDEN_CONTENT).to include(:secrets, :private_homes, :user_uploads, :logs, :queues)
  end
end
