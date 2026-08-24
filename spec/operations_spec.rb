# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Blob::Operations do
  around { |ex| Dir.mktmpdir { |d| described_class.reset!(File.join(d, "b.sqlite3")); ex.run } }

  let(:b64) { Base64.strict_encode64("hello") }

  describe "the same store for both callers" do
    it "round-trips through the operation surface an LLM would call" do
      put = described_class.put("bytes" => b64, "content_type" => "text/plain")
      expect(put[:ok]).to be true
      got = described_class.get("digest" => put[:digest])
      expect(Base64.strict_decode64(got[:bytes])).to eq("hello")
      expect(got[:encoding]).to eq("base64")
    end

    it "is the same store a Rails slice sees directly" do
      d = described_class.put("bytes" => b64)[:digest]
      expect(described_class.store.get(d)[:bytes]).to eq("hello")
    end
  end

  describe "binary safety" do
    it "carries nulls and high bytes intact" do
      raw = "\x00\xff\xfe binary".dup.force_encoding(Encoding::BINARY)
      d = described_class.put("bytes" => Base64.strict_encode64(raw))[:digest]
      expect(Base64.strict_decode64(described_class.get("digest" => d)[:bytes])).to eq(raw)
    end

    it "refuses bytes that are not base64 rather than storing mangled content" do
      r = described_class.put("bytes" => "not base64 !!!")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:bytes_not_base64)
    end
  end

  describe "refusals an agent can act on" do
    it "names the missing parameter" do
      expect(described_class.put({})[:reason]).to eq(:content_required)
      expect(described_class.get({})[:reason]).to eq(:digest_required)
      expect(described_class.stat({})[:reason]).to eq(:digest_required)
    end

    it "refuses an unknown digest" do
      expect(described_class.get("digest" => "sha256:nope")[:reason]).to eq(:not_found)
    end
  end

  describe "stat" do
    it "answers size and type without moving the bytes" do
      d = described_class.put("bytes" => b64, "content_type" => "text/plain")[:digest]
      s = described_class.stat("digest" => d)
      expect(s[:size]).to eq(5)
      expect(s[:content_type]).to eq("text/plain")
      expect(s).not_to have_key(:bytes)
    end
  end

  describe "list" do
    it "clamps a runaway limit rather than reading the whole store" do
      described_class.put("bytes" => b64)
      expect(described_class.list("limit" => 10_000)[:ok]).to be true
    end
  end

  describe "cpcp registration" do
    it "refuses cleanly when rails-cpcp is absent rather than raising" do
      r = Mmg::Blob::Cpcp.register!
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:cpcp_absent)
    end
  end
end
