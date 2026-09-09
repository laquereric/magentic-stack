# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

# The point of this file is one claim: a declaration generated from LinkML is
# indistinguishable from the hand-written block it replaces. Anything less and
# migrating the mind-pod models would write new triples beside the 384 already
# in the store instead of over them.
RSpec.describe "Vv::Graph::Storable.triples_from_linkml" do
  # The real constants from runtimes/mind-pod/app/app/lib/pod_graph.rb.
  STATE    = "urn:mm:pod:state"
  VOCAB    = "urn:mm:vocab/pod#"
  RDF_TYPE = "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

  let(:fixture) { File.expand_path("../../fixtures/linkml/pod_note.yaml", __dir__) }
  let(:derived) { Vv::Linkml.derive(Vv::Linkml.load_file(fixture)) }

  # What the model declares today, by hand.
  let(:handwritten) do
    Class.new do
      include Vv::Graph::Storable
      attr_accessor :id, :title, :body, :created_at

      triples do
        graph   STATE
        subject -> { "urn:mm:note:#{id}" }
        triple RDF_TYPE,          "<#{VOCAB}Note>"
        triple "#{VOCAB}title",     -> { title }
        triple "#{VOCAB}body",      -> { body }, if: -> { body.present? }
        triple "#{VOCAB}createdAt", -> { created_at&.iso8601 }
      end
    end
  end

  # The same shape, from the schema.
  let(:generated) do
    schema = derived
    Class.new do
      include Vv::Graph::Storable
      attr_accessor :id, :title, :body, :created_at

      triples_from_linkml "Note",
                          schema: schema,
                          graph: STATE,
                          subject: -> { "urn:mm:note:#{id}" },
                          type_predicate: RDF_TYPE
    end
  end

  let(:record) do
    generated.new.tap do |r|
      r.id = 7
      r.title = "A title"
      r.body = "A body"
      r.created_at = Time.utc(2026, 9, 9, 12, 0, 0)
    end
  end

  it "names the same predicates, in the same order" do
    expect(generated.semantica_triples_declaration.predicates.map(&:iri))
      .to eq(handwritten.semantica_triples_declaration.predicates.map(&:iri))
  end

  it "targets the same named graph" do
    expect(generated.semantica_triples_declaration.graph_iri)
      .to eq(handwritten.semantica_triples_declaration.graph_iri)
  end

  it "computes the same subject IRI" do
    expect(record.instance_exec(&generated.semantica_triples_declaration.subject_lambda))
      .to eq "urn:mm:note:7"
  end

  it "carries rdf:type as an IRI object, not a literal" do
    type_pred = generated.semantica_triples_declaration.predicates.first
    expect(type_pred.iri).to eq RDF_TYPE
    # The Recorder wraps a literal in a lambda, so this reads the same way a
    # value lambda does -- and must equal what the hand-written block yields.
    expect(record.instance_exec(&type_pred.value_lambda)).to eq "<#{VOCAB}Note>"
  end

  it "serializes a temporal range through iso8601, as the hand block does" do
    created = generated.semantica_triples_declaration.predicates.find { |p| p.iri.end_with?("createdAt") }
    expect(record.instance_exec(&created.value_lambda)).to eq "2026-09-09T12:00:00Z"
  end

  it "reads plain values straight off the record" do
    title = generated.semantica_triples_declaration.predicates.find { |p| p.iri.end_with?("title") }
    expect(record.instance_exec(&title.value_lambda)).to eq "A title"
  end

  it "guards an optional slot and leaves a required one unguarded" do
    preds = generated.semantica_triples_declaration.predicates.each_with_object({}) { |p, h| h[p.iri] = p }
    expect(preds["#{VOCAB}body"].if_lambda).to be_a(Proc)
    expect(preds["#{VOCAB}title"].if_lambda).to be_nil
  end

  it "suppresses an absent optional value and keeps a present one" do
    guard = generated.semantica_triples_declaration.predicates.find { |p| p.iri.end_with?("body") }.if_lambda
    expect(record.instance_exec(&guard)).to be true
    record.body = nil
    expect(record.instance_exec(&guard)).to be false
  end

  it "puts the identifier in the subject and not beside it" do
    expect(generated.semantica_triples_declaration.predicates.map(&:iri)).not_to include(/\bid\b/)
  end

  it "honours skip:" do
    schema = derived
    trimmed = Class.new do
      include Vv::Graph::Storable
      attr_accessor :id, :title, :body, :created_at
      triples_from_linkml "Note", schema: schema, subject: -> { "urn:s" }, skip: %w[body]
    end
    expect(trimmed.semantica_triples_declaration.predicates.map(&:iri)).not_to include("#{VOCAB}body")
  end

  describe "refusals" do
    it "refuses without a schema rather than declaring an empty shape" do
      expect {
        Class.new do
          include Vv::Graph::Storable
          triples_from_linkml "Note", subject: -> { "urn:s" }
        end
      }.to raise_error(ArgumentError, /needs a LinkML schema/)
    end

    it "refuses a class the schema does not describe" do
      schema = derived
      expect {
        Class.new do
          include Vv::Graph::Storable
          triples_from_linkml "Nonexistent", schema: schema, subject: -> { "urn:s" }
        end
      }.to raise_error(ArgumentError, /describes no class/)
    end
  end
end
