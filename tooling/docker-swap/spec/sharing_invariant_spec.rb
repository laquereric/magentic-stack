# frozen_string_literal: true
RSpec.describe Vv::DockerSwap::SharingInvariant do
  Img = Vv::DockerSwap::SharingInvariant::Image
  DIGEST  = "sha256:#{'a' * 64}"
  DIGEST2 = "sha256:#{'b' * 64}"

  def pair(a_parent: DIGEST, b_parent: DIGEST, a_commons: { "rails" => "7.2.1" }, b_commons: { "rails" => "7.2.1" })
    [Img.new(name: "billing", parent: a_parent, commons: a_commons),
     Img.new(name: "ledger",  parent: b_parent, commons: b_commons)]
  end

  it "shares when both halves of the invariant hold" do
    r = described_class.verify(pair)
    expect(r[:shares]).to be(true)
    expect(r[:violations]).to be_empty
  end

  it "names a parent digest mismatch" do
    r = described_class.verify(pair(b_parent: DIGEST2))
    expect(r[:shares]).to be(false)
    expect(r[:violations].map { |v| v[:rule] }).to include(:parent_digest_mismatch)
  end

  it "rejects a floating tag even when every image agrees on it" do
    tag = "registry.example.com/acme/rails-common:latest"
    r = described_class.verify(pair(a_parent: tag, b_parent: tag))
    expect(r[:shares]).to be(false)
    expect(r[:violations].map { |v| v[:rule] }).to eq(%i[floating_parent_tag floating_parent_tag])
  end

  it "accepts a registry-qualified digest reference" do
    ref = "registry.example.com/acme/rails-common@#{DIGEST}"
    expect(described_class.verify(pair(a_parent: ref, b_parent: ref))[:shares]).to be(true)
  end

  it "catches common-gem drift even when the parent is identical" do
    r = described_class.verify(pair(a_commons: { "rails" => "7.2.1", "pg" => "1.5.4" },
                                    b_commons: { "rails" => "7.2.2", "pg" => "1.5.4" }))
    expect(r[:shares]).to be(false)
    drift = r[:violations].find { |v| v[:rule] == :common_gem_version_drift }
    expect(drift[:gem]).to eq("rails")
    expect(drift[:versions]).to contain_exactly("7.2.1", "7.2.2")
  end

  it "treats a gem only one image declares as a delta gem, not drift" do
    r = described_class.verify(pair(a_commons: { "rails" => "7.2.1", "stripe" => "12.0.0" },
                                    b_commons: { "rails" => "7.2.1" }))
    expect(r[:shares]).to be(true)
  end

  it "refuses to answer for fewer than two images" do
    r = described_class.verify([Img.new(name: "solo", parent: DIGEST, commons: {})])
    expect(r).to include(ok: false, reason: :not_enough_images)
  end

  it "recognizes a bare digest and rejects a bare tag" do
    expect(described_class.digest?(DIGEST)).to be(true)
    expect(described_class.digest?("rails-common:gemset-abc123")).to be(false)
  end
end
