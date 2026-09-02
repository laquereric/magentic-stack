# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

# S1 (ADR StorableBootSafe) — Publisher seam + Immediate drain-now.
RSpec.describe Vv::Graph::Publisher do
  after { Vv::Graph.reset_publisher! }

  describe Vv::Graph::Ref do
    it "stores type as a class name string" do
      ref = described_class.new("Widget", 7)
      expect(ref.type).to eq("Widget")
      expect(ref.id).to eq(7)
    end

    it "accepts a Class and freezes" do
      ref = described_class.new(String, 1)
      expect(ref.type).to eq("String")
      expect(ref).to be_frozen
    end

    it "equality is by type+id" do
      a = described_class.new("Widget", 1)
      b = described_class.new("Widget", 1)
      c = described_class.new("Widget", 2)
      expect(a).to eq(b)
      expect(a).not_to eq(c)
    end
  end

  describe Vv::Graph::Publisher::Immediate do
    subject(:publisher) { described_class.new }

    # Drain-path plants: durability is a separate refusal (gap 69). Stub
    # the outbox so these still exercise SPARQL fail-closed, not
    # outbox_not_installed.
    context "when the outbox is available" do
      before do
        allow(publisher).to receive(:outbox_status).and_return(:available)
        allow(Vv::Graph::ProjectionJob).to receive(:enqueue!).and_return(nil)
      end

    it "returns :missing when the row cannot be resolved" do
      ref = Vv::Graph::Ref.new("DefinitelyNotAModel", 1)
      expect(publisher.schedule(ref: ref, generation: 0)).to eq(:missing)
    end

    [
      :graph_unreachable,
      :sparql_parse_error,
      :unexpected_error,
      :invalid_graph,
      :invalid_dsl,
    ].each do |reason|
      it "observes #{reason} with restoration and returns :error (not :applied)" do
        records = []
        stub_const("RailsCpcp", Module.new) unless defined?(RailsCpcp)
        observer = Module.new
        observer.define_singleton_method(:record) do |**kwargs|
          records << kwargs
          true
        end
        stub_const("RailsCpcp::RefusalLog", observer)

        record = Object.new
        record.define_singleton_method(:semantica_emit_triples!) do
          { ok: false, reason: reason, because: "plant #{reason}" }
        end
        record.define_singleton_method(:semantica_primary_subject_iri) { "urn:mm:gap93:1" }
        record.define_singleton_method(:semantica_graph_iri) { "urn:mm:pod:state" }

        status = publisher.schedule(
          ref: Vv::Graph::Ref.new("Gap93Widget", 1),
          generation: 1,
          record: record,
        )
        expect(status).to eq(:error)
        expect(records.length).to eq(1)
        expect(records.first[:reason]).to eq(reason.to_s)
        expect(records.first[:because]).to include("MM_OXIGRAPH_URL")
        rest = records.first[:restoration]
        expect(rest).to be_a(Hash)
        expect(rest.keys).to contain_exactly(
          "state_reached", "inconsistency", "restore_when", "restore_action"
        )
        expect(rest["restore_action"]).to include("drain_pending!")
      end
    end
    end

    it "is the default Vv::Graph.publisher" do
      Vv::Graph.reset_publisher!
      expect(Vv::Graph.publisher).to be_a(described_class)
    end

    context "with a Storable AR model", :requires_extension do
      before(:each) do
        ::ActiveRecord::Base.connection.execute(<<~SQL)
          CREATE TABLE IF NOT EXISTS s1_widgets (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sku TEXT NOT NULL,
            name TEXT
          )
        SQL
        ::ActiveRecord::Base.connection.execute("DELETE FROM s1_widgets")

        unless Object.const_defined?(:S1Widget)
          klass = Class.new(::ActiveRecord::Base) do
            self.table_name = "s1_widgets"
            include ::Vv::Graph::Storable

            triples do
              subject -> { "urn:mm:s1widget:#{sku}" }
              triple "schema:name", -> { name }
            end
            project_on_save!
          end
          Object.const_set(:S1Widget, klass)
        end

        Vv::Graph.reset_publisher!
      end

      it "drains schedule by emitting triples (drain-now == today)" do
        w = S1Widget.create!(sku: "S1", name: "Seam")

        # create already scheduled via after_save; assert graph state
        ask = Vv::Graph::Sparql.ask(
          "ASK { <urn:mm:s1widget:S1> <schema:name> ?o }",
        )
        expect(ask).to eq(ok: true, value: true)

        # higher generation than create's applied_generation must re-apply
        job = Vv::Graph::ProjectionJob.find_by(ref_type: "S1Widget", ref_id: w.id.to_s)
        next_gen = (job&.applied_generation || 0) + 1
        status = Vv::Graph.publisher.schedule(
          ref: Vv::Graph::Ref.new("S1Widget", w.id),
          generation: next_gen,
        )
        expect(status).to eq(:applied)
      end

      it "routes project_on_save through publisher.schedule (spy)" do
        calls = []
        spy = Object.new
        # S2 schedule accepts action:/record: — spy must allow kwargs
        spy.define_singleton_method(:schedule) do |ref:, generation:, **_rest|
          calls << [ref.type, ref.id, generation]
          :applied
        end
        Vv::Graph.publisher = spy

        w = S1Widget.create!(sku: "S2", name: "Spy")
        expect(calls.length).to eq(1)
        expect(calls.first[0]).to eq("S1Widget")
        expect(calls.first[1]).to eq(w.id)
        expect(calls.first[2]).to be_a(Integer)
      end
    end
  end
end
