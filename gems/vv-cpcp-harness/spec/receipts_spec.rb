# frozen_string_literal: true

RSpec.describe Vv::CpcpHarness::Receipts do
  let(:iri) { "https://w3id.org/cpcp/osi8/harness#notes.write" }
  let(:envelope) { { ok: true, result: { "id" => "note:1" }, reason: nil, operation_id: "notes-write-1" } }

  describe Vv::CpcpHarness::Receipts::FileStore do
    it "returns the first result for a repeated operationId, across processes" do
      Dir.mktmpdir do |dir|
        described_class.new(dir).store(iri, "notes-write-1", envelope)
        # A second store object stands in for a later process.
        hit = described_class.new(dir).fetch(iri, "notes-write-1")

        expect(hit.hit?).to be true
        expect(hit.envelope[:result]).to eq({ "id" => "note:1" })
        expect(described_class.new(dir).durable?).to be true
      end
    end

    it "keeps symbol-valued members symbols on the way back" do
      Dir.mktmpdir do |dir|
        store = described_class.new(dir)
        store.store(iri, "n-2", { ok: false, reason: :grounding_refused, failure_layer: :domain })

        hit = store.fetch(iri, "n-2")
        expect(hit.envelope[:reason]).to eq :grounding_refused
        expect(hit.envelope[:failure_layer]).to eq :domain
      end
    end

    it "treats an unreadable store as not-cached rather than failing the call" do
      Dir.mktmpdir do |dir|
        store = described_class.new(dir)
        store.store(iri, "n-3", envelope)
        path = Dir.glob(File.join(dir, "*.json")).first
        File.write(path, "{ not json")

        hit = store.fetch(iri, "n-3")
        expect(hit.hit?).to be false
        expect(hit.warning).to eq :idempotency_store_unavailable
      end
    end

    it "does not mix two operations that share an id" do
      Dir.mktmpdir do |dir|
        store = described_class.new(dir)
        store.store(iri, "shared", envelope)

        expect(store.fetch("#{iri}.other", "shared").hit?).to be false
      end
    end
  end

  describe Vv::CpcpHarness::Receipts::MemoryStore do
    it "replays, but never claims to be durable" do
      store = described_class.new
      expect(store.store(iri, "n-1", envelope)).to eq :idempotency_not_durable
      expect(store.durable?).to be false

      hit = store.fetch(iri, "n-1")
      expect(hit.hit?).to be true
      expect(hit.warning).to eq :idempotency_not_durable
    end
  end

  describe Vv::CpcpHarness::Receipts::NullStore do
    it "makes no replay promise at all" do
      store = described_class.new

      expect(store.durable?).to be false
      expect(store.fetch(iri, "n-1").hit?).to be false
      expect(store.fetch(iri, "n-1").warning).to eq :idempotency_not_durable
    end
  end
end
