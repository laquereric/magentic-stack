# frozen_string_literal: true

RSpec.describe Vv::Canvas do
  before { Vv::Canvas.reset! }

  describe "BlobGate" do
    it "refuses graph_iri" do
      r = Vv::Canvas::BlobGate.graph_iri_refusal("graph_iri" => "urn:ex")
      expect(r["reason"]).to eq("graph_iri_refused")
    end

    it "refuses a non-digest" do
      r = Vv::Canvas::BlobGate.digest_refusal("cid:acia:x")
      expect(r["reason"]).to eq("blob_digest_required")
    end

    it "put without mmg-blob is unavailable, not a hang" do
      r = Vv::Canvas::BlobGate.put("bytes" => "e30=")
      expect(r["ok"]).to be(false)
      expect(r["reason"]).to eq("blob_store_unavailable")
    end
  end

  describe "Boards without AR" do
    it "puts and lists in memory" do
      d = "sha256:" + ("a" * 64)
      r = Vv::Canvas::Boards.put("title" => "T", "blobDigest" => d)
      expect(r["ok"]).to be(true)
      list = Vv::Canvas::Boards.list
      expect(list["@graph"].size).to eq(1)
    end

    it "refuses graph_iri on put" do
      r = Vv::Canvas::Boards.put("title" => "T", "blobDigest" => "sha256:" + ("a" * 64), "graph_iri" => "urn:x")
      expect(r["reason"]).to eq("graph_iri_refused")
    end
  end

  describe "CPCP" do
    it "is absent without rails-cpcp" do
      expect(Vv::Canvas::Cpcp.register![:reason]).to eq(:cpcp_absent)
    end
  end
end
