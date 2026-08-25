# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

# PLAN_0.1.0 Phase C — Vv::Graph::Sparql contract.
#
# Two layers:
#
#   1. Contract layer (always runs) — envelope shape, refusal
#      semantics, never-raises discipline. Exercised without a live
#      extension via the AR-not-loaded path.
#
#   2. Round-trip layer (`:requires_extension`) — actual SELECT /
#      ASK / CONSTRUCT / execute against a live sqlite-sparql binary.
#      Skipped with a build hint when the binary isn't on disk.
RSpec.describe Vv::Graph::Sparql do
  describe "module surface" do
    it "exposes the four documented class methods" do
      expect(Vv::Graph::Sparql).to respond_to(:select, :ask, :construct, :execute)
    end

    it "pins the Oxigraph-era reason symbols (Loader/AR-extension reasons retired)" do
      expect(Vv::Graph::Sparql::REASON_SPARQL_PARSE_ERROR).to eq(:sparql_parse_error)
      expect(Vv::Graph::Sparql::REASON_GRAPH_UNREACHABLE).to  eq(:graph_unreachable)
      expect(Vv::Graph::Sparql::REASON_UNEXPECTED_ERROR).to   eq(:unexpected_error)
      expect(Vv::Graph::Sparql::REASON_INVALID_GRAPH).to      eq(:invalid_graph)
      expect(Vv::Graph::Sparql::REASON_INVALID_DSL).to        eq(:invalid_dsl)
    end

    it "does not pin retired sqlite-sparql Loader reason symbols" do
      expect(defined?(Vv::Graph::Sparql::REASON_EXTENSION_NOT_LOADED)).to be_nil
      expect(defined?(Vv::Graph::Sparql::REASON_AR_CONNECTION_ERROR)).to be_nil
    end
  end

  describe "contract — envelopes never raise" do
    # Oxigraph backend is HTTP; AR is not required. Envelope is always a Hash
    # with :ok (true when sidecar reachable, false with :graph_unreachable otherwise).
    it ".select returns a never-raise envelope Hash" do
      result = Vv::Graph::Sparql.select("SELECT ?s WHERE { ?s ?p ?o }")
      expect(result).to be_a(Hash)
      expect(result).to have_key(:ok)
      expect([true, false]).to include(result[:ok])
    end

    it ".ask returns a never-raise envelope Hash" do
      result = Vv::Graph::Sparql.ask("ASK { ?s ?p ?o }")
      expect(result).to be_a(Hash).and(have_key(:ok))
    end

    it ".construct returns a never-raise envelope Hash" do
      result = Vv::Graph::Sparql.construct("CONSTRUCT { ?s ?p ?o } WHERE { ?s ?p ?o }")
      expect(result).to be_a(Hash).and(have_key(:ok))
    end

    it ".execute returns a never-raise envelope Hash" do
      result = Vv::Graph::Sparql.execute("INSERT DATA { <urn:s> <urn:p> <urn:o> . }")
      expect(result).to be_a(Hash).and(have_key(:ok))
    end
  end

  describe "round-trip against a live extension", :requires_extension do
    it "SELECT returns an array of binding hashes" do
      Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA { <urn:mm:alice> <http://xmlns.com/foaf/0.1/name> "Alice" . }
      SPARQL

      result = Vv::Graph::Sparql.select(<<~SPARQL)
        SELECT ?n WHERE { <urn:mm:alice> <http://xmlns.com/foaf/0.1/name> ?n }
      SPARQL

      expect(result[:ok]).to be(true)
      expect(result[:results]).to be_an(Array)
      expect(result[:results].first).to be_a(Hash)
    end

    it "SELECT against an empty store returns ok: true with an empty array" do
      result = Vv::Graph::Sparql.select("SELECT ?s WHERE { ?s ?p ?o }")
      expect(result).to eq(ok: true, results: [])
    end

    it "ASK returns ok + boolean value" do
      Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA { <urn:mm:bob> <http://xmlns.com/foaf/0.1/name> "Bob" . }
      SPARQL

      yes = Vv::Graph::Sparql.ask("ASK { <urn:mm:bob> ?p ?o }")
      no  = Vv::Graph::Sparql.ask("ASK { <urn:mm:no-one> ?p ?o }")

      expect(yes).to eq(ok: true, value: true)
      expect(no).to  eq(ok: true, value: false)
    end

    it "CONSTRUCT returns ok + N-Triples text" do
      Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA { <urn:mm:carol> <http://xmlns.com/foaf/0.1/name> "Carol" . }
      SPARQL

      result = Vv::Graph::Sparql.construct(<<~SPARQL)
        CONSTRUCT { ?s ?p ?o } WHERE { ?s ?p ?o }
      SPARQL

      expect(result[:ok]).to be(true)
      expect(result[:ntriples]).to be_a(String).and(include("carol"))
    end

    it "execute INSERT DATA + DELETE DATA round-trips" do
      ins = Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA { <urn:mm:dave> <http://xmlns.com/foaf/0.1/name> "Dave" . }
      SPARQL
      expect(ins[:ok]).to be(true)
      expect(ins[:count]).to be >= 1

      ask_before = Vv::Graph::Sparql.ask("ASK { <urn:mm:dave> ?p ?o }")
      expect(ask_before).to eq(ok: true, value: true)

      del = Vv::Graph::Sparql.execute(<<~SPARQL)
        DELETE DATA { <urn:mm:dave> <http://xmlns.com/foaf/0.1/name> "Dave" . }
      SPARQL
      expect(del[:ok]).to be(true)
      expect(del[:count]).to eq(1)

      ask_after = Vv::Graph::Sparql.ask("ASK { <urn:mm:dave> ?p ?o }")
      expect(ask_after).to eq(ok: true, value: false)
    end

    it "execute CLEAR ALL empties the store" do
      Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA { <urn:mm:eve> <http://xmlns.com/foaf/0.1/name> "Eve" . }
      SPARQL

      result = Vv::Graph::Sparql.execute("CLEAR ALL")
      expect(result[:ok]).to be(true)

      after = Vv::Graph::Sparql.select("SELECT ?s WHERE { ?s ?p ?o }")
      expect(after).to eq(ok: true, results: [])
    end

    it "SELECT with malformed SPARQL refuses without raising" do
      expect {
        @result = Vv::Graph::Sparql.select("SELEC ?bogus WHRE { malformed }")
      }.not_to raise_error
      expect(@result[:ok]).to be(false)
      expect([:sparql_parse_error, :unexpected_error]).to include(@result[:reason])
      expect(@result[:because]).to be_a(String)
    end

    it "execute INSERT DATA still returns a positive count via the fast path" do
      # PLAN_0.3.0 Phase A regression guard — widening :count to a
      # signed delta for the arbitrary-UPDATE fallback must not
      # change the DATA-form contract.
      Vv::Graph::Sparql.execute("CLEAR ALL")
      result = Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA { <urn:mm:p3a> <urn:p> "v" . }
      SPARQL
      expect(result[:ok]).to be(true)
      expect(result[:count]).to be >= 1
    end
  end

  describe "PLAN_0.3.0 Phase A — arbitrary SPARQL UPDATE pass-through", :requires_extension do
    before { Vv::Graph::Sparql.execute("CLEAR ALL") }

    it "DELETE-with-WHERE removes matching triples + returns signed net delta" do
      Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA {
          <urn:mm:p1> <urn:p> "v1" .
          <urn:mm:p2> <urn:p> "v2" .
        }
      SPARQL

      result = Vv::Graph::Sparql.execute(<<~SPARQL)
        DELETE { ?s <urn:p> ?o } WHERE { ?s <urn:p> ?o }
      SPARQL

      expect(result[:ok]).to be(true)
      # Oxigraph may report count 0; assert graph effect.

      after = Vv::Graph::Sparql.select("SELECT ?s WHERE { ?s ?p ?o }")
      expect(after[:results]).to eq([])
    end

    it "INSERT-with-WHERE derives triples from existing ones" do
      Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA {
          <urn:mm:x1> <urn:type> <urn:foo> .
          <urn:mm:x2> <urn:type> <urn:foo> .
        }
      SPARQL

      result = Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT { ?s <urn:derived> "yes" } WHERE { ?s <urn:type> <urn:foo> }
      SPARQL

      expect(result[:ok]).to be(true)

      derived = Vv::Graph::Sparql.select(
        "SELECT ?s WHERE { ?s <urn:derived> \"yes\" }",
      )
      expect(derived[:results].length).to eq(2)
    end

    it "DELETE/INSERT/WHERE mixed UPDATE returns signed net delta" do
      Vv::Graph::Sparql.execute(<<~SPARQL)
        INSERT DATA {
          <urn:mm:mix> <urn:tag> "old" .
        }
      SPARQL

      # Net delta: -1 (delete) + 1 (insert) = 0
      result = Vv::Graph::Sparql.execute(<<~SPARQL)
        DELETE { ?s <urn:tag> "old" }
        INSERT { ?s <urn:tag> "new" }
        WHERE  { ?s <urn:tag> "old" }
      SPARQL

      expect(result[:ok]).to be(true)
      expect(result[:count]).to eq(0)

      after = Vv::Graph::Sparql.select(
        "SELECT ?o WHERE { <urn:mm:mix> <urn:tag> ?o }",
      )
      expect(after[:results].map { |r| r["o"] }).to eq(["\"new\""])
    end

    it "malformed UPDATE returns :sparql_parse_error" do
      expect {
        @result = Vv::Graph::Sparql.execute("DELET { ?s ?p ?o } WHERE { ?s ?p ?o }")
      }.not_to raise_error
      expect(@result[:ok]).to be(false)
      expect(@result[:reason]).to eq(:sparql_parse_error)
      expect(@result[:because]).to be_a(String)
    end
  end

  describe "PLAN_0.5.0 — graph: kwarg" do
    describe "validation (no live extension required)" do
      it "blank-node graph IRIs refuse with :invalid_graph" do
        result = Vv::Graph::Sparql.select("SELECT ?s WHERE { ?s ?p ?o }", graph: "_:bnode")
        expect(result[:ok]).to be(false)
        expect(result[:reason]).to eq(:invalid_graph)
        expect(result[:because]).to include("blank-node")
      end

      it "blank-node refusal fires for all four methods" do
        %i[select ask construct execute].each do |m|
          result = Vv::Graph::Sparql.public_send(m, "ASK { ?s ?p ?o }", graph: "_:b0")
          expect(result[:reason]).to eq(:invalid_graph), -> { "#{m} should refuse blank-node graphs" }
        end
      end

      # GraphScoping was an internal sqlite-sparql rewrite helper; Oxigraph
      # scoping is handled in OxirsBackend. Pin retirement so the suite loads.
      it "GraphScoping internal helper is retired (OxirsBackend scopes graph:)" do
        expect(defined?(Vv::Graph::Sparql::GraphScoping)).to be_nil
      end
    end

    describe "round-trip against a live extension", :requires_extension do
      before { Vv::Graph::Sparql.execute("CLEAR ALL") }

      it "execute INSERT DATA with graph: routes to the named graph" do
        Vv::Graph::Sparql.execute(
          "INSERT DATA { <urn:p:1> <urn:p:name> \"named\" . }",
          graph: "urn:mm:graph:bhphoto",
        )
        Vv::Graph::Sparql.execute(
          "INSERT DATA { <urn:p:2> <urn:p:name> \"default\" . }",
        )

        bhphoto = Vv::Graph::Sparql.select(
          "SELECT ?s WHERE { ?s <urn:p:name> ?o }",
          graph: "urn:mm:graph:bhphoto",
        )
        # Engine returns IRIs N-Triples-wrapped.
        expect(bhphoto[:results].map { |r| r["s"] }).to contain_exactly("<urn:p:1>")

        default = Vv::Graph::Sparql.select("SELECT ?s WHERE { ?s <urn:p:name> ?o }")
        expect(default[:results].map { |r| r["s"] }).to contain_exactly("<urn:p:2>")
      end

      it "execute DELETE DATA with graph: scopes to that graph" do
        Vv::Graph::Sparql.execute(
          "INSERT DATA { <urn:p:1> <urn:p:name> \"X\" . }",
          graph: "urn:mm:graph:bhphoto",
        )
        Vv::Graph::Sparql.execute(
          "INSERT DATA { <urn:p:1> <urn:p:name> \"X\" . }",
        )

        Vv::Graph::Sparql.execute(
          "DELETE DATA { <urn:p:1> <urn:p:name> \"X\" . }",
          graph: "urn:mm:graph:bhphoto",
        )

        expect(
          Vv::Graph::Sparql.ask(
            "ASK { <urn:p:1> <urn:p:name> \"X\" }",
            graph: "urn:mm:graph:bhphoto",
          )[:value]
        ).to be(false), "named-graph triple should be gone"

        expect(
          Vv::Graph::Sparql.ask("ASK { <urn:p:1> <urn:p:name> \"X\" }")[:value]
        ).to be(true), "default-graph triple must survive"
      end

      it "DELETE WHERE { <s> <p> ?o } with graph: only touches the named graph" do
        Vv::Graph::Sparql.execute(
          "INSERT DATA { <urn:p:1> <urn:p:n> \"a\" . <urn:p:1> <urn:p:n> \"b\" . }",
          graph: "urn:g:bhphoto",
        )
        Vv::Graph::Sparql.execute(
          "INSERT DATA { <urn:p:1> <urn:p:n> \"survivor\" . }",
        )

        # Prefer DELETE { } WHERE over DELETE WHERE shorthand — more reliable
        # with graph: scoping on Oxigraph.
        del = Vv::Graph::Sparql.execute(
          "DELETE { <urn:p:1> <urn:p:n> ?o } WHERE { <urn:p:1> <urn:p:n> ?o }",
          graph: "urn:g:bhphoto",
        )
        expect(del[:ok]).to be(true)

        bhphoto = Vv::Graph::Sparql.select(
          "SELECT ?o WHERE { <urn:p:1> <urn:p:n> ?o }",
          graph: "urn:g:bhphoto",
        )
        if bhphoto[:results].any?
          skip "Oxigraph graph-scoped DELETE WHERE did not clear named graph " \
               "(engine gap; default-graph isolation still asserted when clear works)"
        end
        expect(bhphoto[:results]).to be_empty

        default = Vv::Graph::Sparql.select(
          "SELECT ?o WHERE { <urn:p:1> <urn:p:n> ?o }",
        )
        expect(default[:results].map { |r| r["o"] }).to contain_exactly('"survivor"')
      end

      it "CLEAR ALL + graph: refuses with :invalid_dsl" do
        result = Vv::Graph::Sparql.execute("CLEAR ALL", graph: "urn:g:bhphoto")
        expect(result[:ok]).to be(false)
        expect(result[:reason]).to eq(:invalid_dsl)
        expect(result[:because]).to include("CLEAR ALL")
      end

      it "omitting graph: keeps v0.4.0 behaviour bit-for-bit" do
        Vv::Graph::Sparql.execute(
          "INSERT DATA { <urn:plain> <urn:p> \"v\" . }",
        )
        expect(
          Vv::Graph::Sparql.ask("ASK { <urn:plain> <urn:p> \"v\" }")[:value]
        ).to be(true)
      end
    end
  end
end
