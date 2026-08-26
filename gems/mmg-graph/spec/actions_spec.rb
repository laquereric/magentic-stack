# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Graph do
  describe "mcb_actions (the legacy surface)" do
    let(:actions) { described_class.mcb_actions }

    it "registers exactly the four documented actions" do
      expect(actions.map { |a| a[:name] })
        .to contain_exactly("graphdb_query", "graphdb_publish", "graphdb_update", "graphdb_federate")
    end

    it "falls back to a permissive schema when the grammar deriver is not mounted" do
      expect(described_class.schema_for("query")).to eq({ type: "object" })
    end

    it "points at a grammar file that exists, since the schema derives from it" do
      expect(File.file?(described_class::GRAMMAR)).to be(true)
    end

    # ADR 0011 records that the MCB publish path still accepts what CPCP refuses.
    # Asserting it here means the day it is closed, this spec fails and says so --
    # rather than the gap being closed silently or persisting unnoticed.
    it "still passes a bare graph name through -- the known gap, pinned so it cannot drift quietly" do
      publish = actions.find { |a| a[:name] == "graphdb_publish" }
      received = nil
      allow(Mmg::Graph::Execute).to receive(:publish) { |_t, **kw| received = kw; { ok: true } }

      publish[:handler].call({ triples: [], graph: "urn:mmg:graph:default" }, nil)

      expect(received).to eq({ graph: "urn:mmg:graph:default" }),
                          "MCB publish now grounds its writes -- update ADR 0011/its successor and this spec"
    end
  end
end
