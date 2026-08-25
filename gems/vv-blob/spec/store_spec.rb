# frozen_string_literal: true
require "spec_helper"

RSpec.describe Vv::Blob::Store do
  around do |ex|
    Dir.mktmpdir { |d| @dir = d; ex.run }
  end

  def store = @store ||= described_class.open(path: File.join(@dir, "blobs.sqlite3"))

  describe "content addressing" do
    it "names a blob by the sha256 of its bytes" do
      r = store.put("hello", date: "2026-08-24", name: "n", description: "d")
      expect(r[:ok]).to be true
      expect(r[:digest]).to eq("sha256:#{Digest::SHA256.hexdigest('hello')}")
      expect(r[:size]).to eq(5)
    end

    it "is idempotent: the same bytes twice is ONE row, and reports that it stored nothing" do
      a = store.put("same", date: "2026-08-24", name: "n", description: "d")
      b = store.put("same", date: "2026-08-24", name: "n", description: "d")
      expect(a[:digest]).to eq(b[:digest])
      expect(a[:stored]).to be true
      expect(b[:stored]).to be false
      expect(store.count[:count]).to eq(1)
    end

    it "gives different bytes a different name" do
      expect(store.put("a", date: "2026-08-24", name: "n", description: "d")[:digest]).not_to eq(store.put("b", date: "2026-08-24", name: "n", description: "d")[:digest])
    end

    it "does not let a caller name its own blob" do
      expect(described_class.instance_method(:put).parameters.map(&:last)).not_to include(:digest)
    end
  end

  describe "round trip" do
    it "returns the exact bytes, binary intact" do
      raw = "\x00\x01\xfe\xff binary \xc3\xa9".dup.force_encoding(Encoding::BINARY)
      d = store.put(raw, content_type: "application/octet-stream", date: "2026-08-24", name: "n", description: "d")[:digest]
      got = store.get(d)
      expect(got[:ok]).to be true
      expect(got[:bytes]).to eq(raw)
      expect(got[:content_type]).to eq("application/octet-stream")
      expect(got[:size]).to eq(raw.bytesize)
    end

    it "stores an empty blob, because empty is content and nil is not" do
      r = store.put("", date: "2026-08-24", name: "n", description: "d")
      expect(r[:ok]).to be true
      expect(store.get(r[:digest])[:bytes]).to eq("")
    end
  end

  describe "refusals, never exceptions" do
    it "refuses nil rather than inventing an empty blob" do
      r = store.put(nil, date: "2026-08-24", name: "n", description: "d")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:content_required)
    end

    it "refuses an unknown digest by name" do
      r = store.get("sha256:nope")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:not_found)
      expect(r[:because]).to include("sha256:nope")
    end

    it "answers the envelope contract even when the database cannot be opened" do
      s = described_class.open(path: File.join(@dir, "no", "such", "dir", "b.sqlite3"))
      expect(s.put("x", date: "2026-08-24", name: "n", description: "d")[:ok]).to be false
      expect(s.get("y")[:reason]).to eq(:store_unavailable)
    end
  end

  describe "delete" do
    it "reports whether anything was actually removed" do
      d = store.put("gone", date: "2026-08-24", name: "n", description: "d")[:digest]
      expect(store.delete(d)[:deleted]).to be true
      expect(store.delete(d)[:deleted]).to be false
      expect(store.has?(d)).to be false
    end
  end

  describe "listing" do
    it "lists digests newest first" do
      3.times { |i| store.put("blob-#{i}", date: "2026-08-24", name: "n", description: "d") }
      expect(store.digests[:digests].size).to eq(3)
      expect(store.count[:count]).to eq(3)
    end
  end

  describe "persistence" do
    it "survives reopening the same file" do
      path = File.join(@dir, "persist.sqlite3")
      s1 = described_class.open(path: path)
      d = s1.put("durable", date: "2026-08-24", name: "n", description: "d")[:digest]
      s1.close
      s2 = described_class.open(path: path)
      expect(s2.get(d)[:bytes]).to eq("durable")
    end
  end

  describe "an entry must account for itself" do
    it "refuses bytes with no date, name or description" do
      r = store.put("anonymous")
      expect(r[:ok]).to be false
      expect(r[:reason]).to eq(:entry_incomplete)
      expect(r[:because]).to include("date, name, description")
    end

    it "names exactly which parts are missing" do
      r = store.put("partial", date: "2026-08-24", name: "n")
      expect(r[:because]).to include("missing description")
    end

    it "treats blank as missing, not as given" do
      r = store.put("blank", date: "2026-08-24", name: "  ", description: "d")
      expect(r[:reason]).to eq(:entry_incomplete)
    end

    it "records the entry alongside the content" do
      r = store.put("filed", date: "2026-08-24", name: "minutes", description: "harbour board")
      expect(r[:entry][:name]).to eq("minutes")
      e = store.entries(r[:digest])
      expect(e[:entries].first[:description]).to eq("harbour board")
    end

    it "files the SAME bytes twice under different names without storing them twice" do
      a = store.put("same", date: "2026-08-24", name: "first", description: "one")
      b = store.put("same", date: "2026-08-25", name: "second", description: "two")
      expect(a[:digest]).to eq(b[:digest])
      expect(a[:stored]).to be true
      expect(b[:stored]).to be false
      expect(store.count[:count]).to eq(1)
      expect(store.entries(a[:digest])[:entries].map { |x| x[:name] }).to contain_exactly("first", "second")
    end
    it "takes the entries with the bytes, so no filing outlives what it files" do
      r = store.put("gone", date: "2026-08-24", name: "first", description: "one")
      store.put("gone", date: "2026-08-25", name: "second", description: "two")
      expect(store.entries(r[:digest])[:entries].size).to eq(2)

      d = store.delete(r[:digest])
      expect(d[:deleted]).to be true
      expect(d[:entries_deleted]).to eq(2)
      expect(store.has?(r[:digest])).to be false
      expect(store.entries(r[:digest])[:entries]).to be_empty
    end

    it "reports a delete that removed nothing as exactly that" do
      d = store.delete("sha256:nothing")
      expect(d[:ok]).to be true
      expect(d[:deleted]).to be false
      expect(d[:entries_deleted]).to eq(0)
    end
  end
end
