# frozen_string_literal: true

# GATE: tags are never identity.
#
# "A mutable tag is not a pin" is already written into magentic-stack's
# published_images.json. This is that sentence with a checker behind it.
RSpec.describe Vv::DependencyOrch::Identity do
  let(:oci) { "sha256:#{'a' * 64}" }
  let(:git) { "b" * 40 }

  it "accepts a bare OCI digest" do
    result = described_class.parse(oci)
    expect(result[:ok]).to be true
    expect(result[:digest]).to eq(oci)
    expect(result[:kind]).to eq(:oci)
  end

  it "accepts a 40-hex git revision" do
    expect(described_class.parse(git)).to include(ok: true, kind: :git)
  end

  it "keeps the repository name as a label and the digest as the key" do
    result = described_class.parse("ghcr.io/laquereric/rails-base@#{oci}")
    expect(result[:digest]).to eq(oci)
    expect(result[:name]).to eq("ghcr.io/laquereric/rails-base")
  end

  # PLANT: a resource keyed by tag must fail.
  it "refuses a tag, with its own reason rather than a parse failure" do
    result = described_class.parse("rails-base:latest")
    expect(result[:ok]).to be false
    expect(result[:reason]).to eq("tag_is_not_identity")
    expect(result[:because]).to match(/label observed at a time/)
  end

  it "refuses a tag even when it carries a registry host and a path" do
    expect(described_class.parse("ghcr.io/laquereric/rails-base:2026-09-13")[:reason])
      .to eq("tag_is_not_identity")
  end

  # The tag half of name@digest is dropped rather than carried. Carrying it is
  # how it later gets used as a key by something that "just needed a name".
  it "drops the tag from a name@digest reference" do
    result = described_class.parse("rails-base:2026-09@#{oci}")
    expect(result[:name]).to eq("rails-base")
  end

  it "separates a human-typed prefix from an identity" do
    expect(described_class.prefix?("sha256:#{'a' * 12}")).to be true
    expect(described_class.identity?("sha256:#{'a' * 12}")).to be false
  end
end
