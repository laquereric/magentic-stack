# frozen_string_literal: true

require "json"

# GATE: attestations are not platforms.
#
# buildx adds an attestation manifest that reports as `unknown/unknown`, and it
# reads like a second platform to anyone who does not know. Shape measured
# against docker.io/library/hello-world on 2026-09-13: 19 manifests, 8 of them
# attestations, both markers present -- the `vnd.docker.reference.type`
# annotation and the unknown/unknown platform.
RSpec.describe Vv::DependencyOrch::Adapters::Registry do
  subject(:registry) { described_class.new }

  def raw(doc) = JSON.generate(doc)

  let(:single_platform_with_attestation) do
    raw(
      "mediaType" => "application/vnd.oci.image.index.v1+json",
      "schemaVersion" => 2,
      "manifests" => [
        { "digest" => "sha256:#{'1' * 64}",
          "mediaType" => "application/vnd.oci.image.manifest.v1+json",
          "platform" => { "architecture" => "arm64", "os" => "linux" },
          "size" => 1027 },
        { "digest" => "sha256:#{'2' * 64}",
          "mediaType" => "application/vnd.oci.image.manifest.v1+json",
          "annotations" => { "vnd.docker.reference.type" => "attestation-manifest",
                             "vnd.docker.reference.digest" => "sha256:#{'1' * 64}" },
          "platform" => { "architecture" => "unknown", "os" => "unknown" },
          "size" => 566 }
      ]
    )
  end

  # PLANT: an index with one platform plus an attestation reports ONE.
  it "reports one platform for a single-platform image carrying an attestation" do
    parsed = registry.send(:parse_raw, single_platform_with_attestation)

    expect(parsed[:platforms].length).to eq(1)
    expect(parsed[:attestations].length).to eq(1)
    expect(parsed[:platforms].first).to include(os: "linux", architecture: "arm64")
  end

  it "catches an attestation that lost its annotation but kept unknown/unknown" do
    doc = JSON.parse(single_platform_with_attestation)
    doc["manifests"][1].delete("annotations")
    parsed = registry.send(:parse_raw, raw(doc))

    expect(parsed[:platforms].length).to eq(1)
    expect(parsed[:attestations].length).to eq(1)
  end

  it "catches an attestation whose platform was normalised away but kept its annotation" do
    doc = JSON.parse(single_platform_with_attestation)
    doc["manifests"][1]["platform"] = { "architecture" => "arm64", "os" => "linux" }
    parsed = registry.send(:parse_raw, raw(doc))

    expect(parsed[:platforms].length).to eq(1)
  end

  # The index/manifest distinction, which the plan calls the most expensive
  # mistake available here.
  it "carries the index digest for an index" do
    parsed = registry.send(:parse_raw, single_platform_with_attestation)
    expect(parsed[:index_digest]).to eq(parsed[:digest])
    expect(parsed[:index_digest]).to match(/\Asha256:[0-9a-f]{64}\z/)
  end

  it "says index_digest is false -- not nil -- for a lone manifest" do
    lone = raw("mediaType" => "application/vnd.oci.image.manifest.v1+json",
               "schemaVersion" => 2, "layers" => [])
    parsed = registry.send(:parse_raw, lone)

    expect(parsed[:index_digest]).to be(false)
    expect(parsed[:platforms]).to be_empty
  end

  # The digest of a manifest IS the sha256 of its bytes -- verified against a
  # live registry rather than assumed, and asserted here so a future change to
  # buffering (BINARY -> UTF-8, say) fails loudly instead of silently producing
  # digests that match nothing.
  it "derives the digest from the exact bytes" do
    body = single_platform_with_attestation
    expected = "sha256:#{Digest::SHA256.hexdigest(body)}"
    expect(registry.send(:parse_raw, body)[:digest]).to eq(expected)
  end

  describe "#resolve" do
    before { allow(registry).to receive(:available?).and_return(true) }

    it "treats a 401 as unreachable, never as absent" do
      allow(registry).to receive(:run)
        .and_return([:failed, "", "unexpected status from HEAD request: 401 Unauthorized"])

      result = registry.resolve("ghcr.io/private/thing:x")
      expect(result[:ok]).to be false
      expect(result[:reason]).to eq("unreachable")
    end

    it "treats a manifest-unknown as a completed answer of not-found" do
      allow(registry).to receive(:run)
        .and_return([:failed, "", "failed to resolve reference: not found"])

      result = registry.resolve("ghcr.io/laquereric/nope@sha256:#{'0' * 64}")
      expect(result[:ok]).to be true
      expect(result[:found]).to be false
    end

    it "reports a timeout as unreachable" do
      allow(registry).to receive(:run).and_return([:timeout, "", ""])
      expect(registry.resolve("whatever")).to include(ok: false, reason: "unreachable")
    end
  end
end
