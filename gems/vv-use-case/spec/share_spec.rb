# frozen_string_literal: true

require "spec_helper"

RSpec.describe Vv::UseCase::Share do
  DIGEST = "sha256:" + ("ab" * 32)

  def fabric_bytes(objects)
    json = { "width" => 900, "height" => 1200, "objects" => objects }.to_json
    [json].pack("m0")
  end

  def actor_blob
    {
      "ok" => true,
      "bytes" => fabric_bytes([
        { "type" => "Group", "ucKind" => "actor", "ucId" => "act_1", "left" => 80, "top" => 360,
          "objects" => [{ "type" => "IText", "text" => "A" }] },
        { "type" => "Group", "ucKind" => "usecase", "ucId" => "uc_1", "left" => 400, "top" => 300,
          "width" => 200, "height" => 80, "objects" => [{ "type" => "IText", "text" => "G" }] }
      ]),
      "digest" => DIGEST
    }
  end

  class FakeMiro
    attr_reader :effects, :name

    def initialize
      @effects = []
      @name = nil
    end

    def create_board(name:)
      @name = name
      { ok: true, data: { "id" => "b1", "viewLink" => "https://miro.com/app/board/b1/" } }
    end

    def apply_effect(_board_id, effect)
      @effects << effect
      n = @effects.size
      { ok: true, data: { "id" => "i#{n}" } }
    end
  end

  it "refuses a non-digest name" do
    r = described_class.call("blobDigest" => "cid:acia:nope")
    expect(r["ok"]).to be false
    expect(r["reason"]).to eq("blob_digest_required")
  end

  it "refuses graph_iri" do
    r = described_class.call("blobDigest" => DIGEST, "graph_iri" => "urn:ex")
    expect(r["ok"]).to be false
    expect(r["reason"]).to eq("graph_iri_refused")
  end

  it "refuses an empty diagram" do
    Vv::UseCase.blob_get = ->(_d) { { "ok" => true, "bytes" => fabric_bytes([]) } }
    r = described_class.call("blobDigest" => DIGEST, "title" => "T")
    expect(r["ok"]).to be false
    expect(r["reason"]).to eq("empty_use_case")
  end

  it "refuses token_required when no client and no env token" do
    Vv::UseCase.blob_get = ->(_d) { actor_blob }
    old = ENV["MIRO_ACCESS_TOKEN"]
    ENV["MIRO_ACCESS_TOKEN"] = nil
    ENV["MIRO_TOKEN"] = nil
    r = described_class.call("blobDigest" => DIGEST, "title" => "Care")
    expect(r["ok"]).to be false
    expect(r["reason"]).to eq("token_required")
  ensure
    ENV["MIRO_ACCESS_TOKEN"] = old
  end

  it "pushes Effects through the injected Miro client and returns a viewLink" do
    fake = FakeMiro.new
    Vv::UseCase.blob_get = ->(_d) { actor_blob }
    Vv::UseCase.miro_client = fake
    r = described_class.call("blobDigest" => DIGEST, "title" => "Care")
    expect(r["ok"]).to be true
    expect(r["viewLink"]).to eq("https://miro.com/app/board/b1/")
    expect(r["boardId"]).to eq("b1")
    expect(r["digest"]).to eq(DIGEST)
    expect(r["slice_key"]).to eq("S3")
    expect(fake.name).to start_with("Care (sha256:")
    expect(fake.effects.size).to eq(2)
  end

  it "extracts from inline json without a blob" do
    r = described_class.extract(
      "json" => { "objects" => [{ "ucKind" => "actor", "ucId" => "act_1", "text" => "A" }] },
      "title" => "T"
    )
    expect(r["ok"]).to be true
    expect(r["actors"][0]["id"]).to eq("act_1")
  end
end
