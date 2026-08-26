# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Graph::Execute do
  let(:entry) do
    e = Mmg::Graph::Entry.new(date: "2026-08-26", name: "n", description: "why these triples exist")
    e.save!
    e
  end
  let(:triples) { ['<urn:a> <urn:b> "c" .'] }

  # THE INVARIANT THIS GEM EXISTS FOR (ADR 0011).
  #
  # publish used to default to urn:mmg:graph:default -- a named graph resolving
  # to no record. Anything could write nodes no model could reproduce, and
  # nothing would catch it. These are the refusals that make it structural.
  describe "grounding" do
    it "refuses a bare graph name rather than honouring it" do
      out = described_class.publish(triples, graph: "urn:mmg:graph:default")

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:ungrounded_graph)
      expect(out[:because]).to match(/resolves to no record/)
    end

    it "refuses when no entry is given at all" do
      out = described_class.publish(triples)

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:entry_required)
    end

    it "refuses an unsaved entry, which owns no named graph yet" do
      out = described_class.publish(triples, entry: Mmg::Graph::Entry.new(date: "d", name: "n", description: "x"))

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:entry_unsaved)
    end

    # The refusal must come BEFORE the store is touched. If a bare graph name
    # reached the HTTP call and only failed there, the rule would depend on the
    # store being unreachable rather than on the rule.
    it "refuses without attempting a write" do
      expect(described_class).not_to receive(:update)
      described_class.publish(triples, graph: "urn:mmg:graph:default")
    end
  end

  describe "empty input" do
    it "skips rather than writing an empty INSERT, and names the graph it would have used" do
      expect(described_class).not_to receive(:update)
      out = described_class.publish([], entry: entry)

      expect(out[:ok]).to be(true)
      expect(out[:skipped]).to be(true)
      expect(out[:graph]).to eq(entry.graph_name)
    end

    it "treats whitespace-only triples as empty" do
      out = described_class.publish(["  ", "\n"], entry: entry)
      expect(out[:skipped]).to be(true)
    end
  end

  describe "a grounded publish" do
    it "targets the entry's graph and reports the ref that accounts for it" do
      allow(described_class).to receive(:update).and_return({ ok: true })
      out = described_class.publish(triples, entry: entry)

      expect(out[:ok]).to be(true)
      expect(out[:graph]).to eq(entry.graph_name)
      expect(out[:ref]).to eq(entry.ref)
    end

    it "wraps the triples in INSERT DATA against that named graph" do
      sent = nil
      allow(described_class).to receive(:update) { |sparql| sent = sparql; { ok: true } }
      described_class.publish(triples, entry: entry)

      expect(sent).to include("INSERT DATA")
      expect(sent).to include("GRAPH <#{entry.graph_name}>")
      expect(sent).to include('<urn:a> <urn:b> "c" .')
    end

    it "passes a store failure back rather than reporting a write that did not happen" do
      allow(described_class).to receive(:update).and_return({ ok: false, reason: :update_failed, because: "HTTP 500" })
      out = described_class.publish(triples, entry: entry)

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:update_failed)
    end
  end

  # Never-raise, proven against a dead endpoint rather than a stub -- the point
  # is that a real connection failure returns an envelope.
  describe "never raises" do
    it "returns an envelope when the store cannot be reached on query" do
      out = described_class.query("SELECT * WHERE { ?s ?p ?o }")

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:query_error)
      expect(out[:because]).to be_a(String)
    end

    it "returns an envelope when the store cannot be reached on update" do
      out = described_class.update("INSERT DATA { <urn:a> <urn:b> <urn:c> }")

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:update_error)
    end
  end

  # An anticipated seam that returns :not_implemented is honest; one that returns
  # empty results would be a silent wrong answer.
  describe "federation" do
    it "refuses explicitly instead of pretending to federate" do
      out = described_class.federate("SELECT * WHERE { ?s ?p ?o }", endpoints: %w[a b])

      expect(out[:ok]).to be(false)
      expect(out[:reason]).to eq(:not_implemented)
      expect(out[:because]).to include("2 endpoint")
    end
  end

  describe "endpoint" do
    it "reads MM_OXIGRAPH_URL, the variable the client actually uses" do
      expect(described_class.endpoint).to eq("http://127.0.0.1:9")
    end
  end
end
