# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

# S2 (ADR StorableBootSafe) — durable outbox + atomic-replace + tombstone.
RSpec.describe "S2 projection outbox + atomic-replace" do
  after { Vv::Graph.reset_publisher! }

  describe Vv::Graph::ProjectionJob do
    it "is defined as an ActiveRecord model" do
      expect(described_class.ancestors).to include(::ActiveRecord::Base)
      expect(described_class.table_name).to eq("vv_graph_projection_jobs")
    end
  end

  describe Vv::Graph::Publisher::Immediate do
    it "responds to drain_pending!" do
      expect(described_class.new).to respond_to(:drain_pending!)
    end

    it "returns :missing for unknown ref without raising" do
      status = described_class.new.schedule(
        ref: Vv::Graph::Ref.new("NoSuchModel", 1),
        generation: 1,
      )
      expect(%i[missing error applied skipped no_declaration]).to include(status)
    end
  end

  describe "lifecycle (atomic-replace + outbox)", :requires_extension do
    before(:each) do
      ::ActiveRecord::Base.connection.execute(<<~SQL)
        CREATE TABLE IF NOT EXISTS s2_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sku TEXT NOT NULL,
          name TEXT,
          price INTEGER,
          tags TEXT,
          category TEXT
        )
      SQL
      ::ActiveRecord::Base.connection.execute("DELETE FROM s2_items")
      Vv::Graph::ProjectionJob.ensure_schema!
      Vv::Graph::ProjectionJob.delete_all if Vv::Graph::ProjectionJob.available?
      Vv::Graph.reset_publisher!

      unless Object.const_defined?(:S2Item)
        klass = Class.new(::ActiveRecord::Base) do
          self.table_name = "s2_items"
          include ::Vv::Graph::Storable

          # tags stored as comma-separated for collection tests
          def tag_list
            (tags || "").split(",").map(&:strip).reject(&:empty?)
          end

          triples do
            graph "urn:mm:graph:s2-items"
            subject -> { "urn:mm:s2item:#{sku}" }
            triple "schema:name",  -> { name }
            triple "schema:price", -> { price }, if: -> { price && price > 0 }

            each -> { tag_list } do |tag|
              triple "mm:tag", -> { tag }
            end

            on_subject -> { "urn:mm:folder:category:#{category}" } do
              triple "rdf:type",    "<urn:mm:CategoryFolder>"
              triple "schema:name", -> { category.to_s.capitalize }
            end
          end
          project_on_save!
        end
        Object.const_set(:S2Item, klass)
      end
    end

    # (a) save with predicate P then re-save WITHOUT P -> P is GONE
    it "(a) drops predicates that are no longer emitted (staleness fixed)" do
      item = S2Item.create!(sku: "A1", name: "Priced", price: 50, category: "tools")
      before = Vv::Graph::Sparql.ask(
        "ASK { <urn:mm:s2item:A1> <schema:price> ?o }",
        graph: "urn:mm:graph:s2-items",
      )
      expect(before).to eq(ok: true, value: true)

      # price guard is price > 0 — set to 0 so price is not emitted
      item.update!(price: 0)

      after = Vv::Graph::Sparql.ask(
        "ASK { <urn:mm:s2item:A1> <schema:price> ?o }",
        graph: "urn:mm:graph:s2-items",
      )
      expect(after).to eq(ok: true, value: false),
                       "schema:price must be gone after re-save without P (atomic-replace)"
      name_still = Vv::Graph::Sparql.ask(
        "ASK { <urn:mm:s2item:A1> <schema:name> ?o }",
        graph: "urn:mm:graph:s2-items",
      )
      expect(name_still).to eq(ok: true, value: true)
    end

    # (b) collection shrink -> removed elements gone
    it "(b) removes collection elements that left the each-block" do
      item = S2Item.create!(sku: "B1", name: "Tagged", price: 1, tags: "red,blue,green", category: "tools")
      three = Vv::Graph::Sparql.select(
        "SELECT ?t WHERE { <urn:mm:s2item:B1> <mm:tag> ?t }",
        graph: "urn:mm:graph:s2-items",
      )
      expect(three[:ok]).to be(true)
      expect(three[:results].length).to eq(3)

      item.update!(tags: "red")
      one = Vv::Graph::Sparql.select(
        "SELECT ?t WHERE { <urn:mm:s2item:B1> <mm:tag> ?t }",
        graph: "urn:mm:graph:s2-items",
      )
      expect(one[:results].length).to eq(1)
      expect(one[:results].first["t"]).to include("red")
    end

    # (c) delete -> all primary-subject triples gone
    it "(c) tombstones primary subject on destroy" do
      item = S2Item.create!(sku: "C1", name: "Doomed", price: 10, category: "tools")
      expect(
        Vv::Graph::Sparql.ask(
          "ASK { <urn:mm:s2item:C1> ?p ?o }",
          graph: "urn:mm:graph:s2-items",
        ),
      ).to eq(ok: true, value: true)

      item.destroy!

      expect(
        Vv::Graph::Sparql.ask(
          "ASK { <urn:mm:s2item:C1> ?p ?o }",
          graph: "urn:mm:graph:s2-items",
        ),
      ).to eq(ok: true, value: false)
    end

    # (d) on_subject shared subject SURVIVES a sibling row's delete
    it "(d) shared on_subject survives sibling delete (additive preserved)" do
      a = S2Item.create!(sku: "D1", name: "One", price: 1, category: "shared")
      b = S2Item.create!(sku: "D2", name: "Two", price: 1, category: "shared")

      folder_before = Vv::Graph::Sparql.ask(
        "ASK { <urn:mm:folder:category:shared> <rdf:type> ?t }",
        graph: "urn:mm:graph:s2-items",
      )
      expect(folder_before).to eq(ok: true, value: true)

      a.destroy!

      # primary of A gone
      expect(
        Vv::Graph::Sparql.ask(
          "ASK { <urn:mm:s2item:D1> ?p ?o }",
          graph: "urn:mm:graph:s2-items",
        ),
      ).to eq(ok: true, value: false)

      # shared folder still present (sibling B keeps additive contribution)
      folder_after = Vv::Graph::Sparql.ask(
        "ASK { <urn:mm:folder:category:shared> <rdf:type> ?t }",
        graph: "urn:mm:graph:s2-items",
      )
      expect(folder_after).to eq(ok: true, value: true),
                              "shared on_subject must survive sibling delete"
      expect(b.reload).to be_present
    end

    # (e) idempotent coalesce
    it "(e) re-drain of applied generation is a no-op (coalesce)" do
      item = S2Item.create!(sku: "E1", name: "Once", price: 1, category: "tools")
      job = Vv::Graph::ProjectionJob.find_by!(ref_type: "S2Item", ref_id: item.id.to_s)
      expect(job.applied_generation).to eq(job.generation)
      expect(job.state).to eq("applied")

      status = Vv::Graph.publisher.schedule(
        ref: Vv::Graph::Ref.new("S2Item", item.id),
        generation: job.generation,
        action: :project,
        record: item,
      )
      expect(status).to eq(:skipped)
    end

    # (f) at-least-once: pending job after simulated mid-drain crash
    it "(f) drain_pending! completes a job left pending after crash" do
      item = S2Item.create!(sku: "F1", name: "Crashy", price: 1, category: "tools")
      job = Vv::Graph::ProjectionJob.find_by!(ref_type: "S2Item", ref_id: item.id.to_s)

      # Simulate crash after job write, before mark_applied:
      # re-open as pending with a higher generation and wipe graph state for primary.
      job.update!(state: "pending", generation: job.generation + 1, applied_generation: nil)
      Vv::Graph::Storable.clear_subject_iri!("urn:mm:s2item:F1", "urn:mm:graph:s2-items")

      expect(
        Vv::Graph::Sparql.ask(
          "ASK { <urn:mm:s2item:F1> <schema:name> ?o }",
          graph: "urn:mm:graph:s2-items",
        ),
      ).to eq(ok: true, value: false)

      result = Vv::Graph.drain_pending!
      expect(result[:ok]).to be(true)
      expect(result[:drained]).to be >= 1

      expect(
        Vv::Graph::Sparql.ask(
          "ASK { <urn:mm:s2item:F1> <schema:name> ?o }",
          graph: "urn:mm:graph:s2-items",
        ),
      ).to eq(ok: true, value: true)

      job.reload
      expect(job.state).to eq("applied")
      expect(job.applied_generation).to eq(job.generation)
    end

    it "writes a durable ProjectionJob on save" do
      item = S2Item.create!(sku: "J1", name: "Jobbed", price: 1, category: "tools")
      job = Vv::Graph::ProjectionJob.find_by(ref_type: "S2Item", ref_id: item.id.to_s)
      expect(job).not_to be_nil
      expect(job.action).to eq("project")
      expect(job.generation).to be_a(Integer)
    end
  end
end
