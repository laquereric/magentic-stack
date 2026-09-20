# frozen_string_literal: true

RSpec.describe Vv::MedallionMemory::Serve do
  let(:store) { Vv::MedallionMemory::Store.new }
  let(:fact) { Vv::MedallionMemory::Fact }

  def land!(subject_iri, predicate, object)
    fact.append(
      store: store, subject_iri: subject_iri, predicate: predicate,
      object: object, valid_from: "2026-01-01", canonical: true
    )[:fact]
  end

  def setup!
    land!("urn:mm:user/1", "mm:role", "manager")
    land!("urn:mm:user/1", "mm:member_of", "urn:mm:team/a")
    land!("urn:mm:team/a", "mm:name", "platform")
    land!("urn:mm:project/x", "mm:status", "active")
  end

  def serve_with(activations, **over)
    setup!
    args = { store: store, cue: "platform manager", node_budget: 6,
             token_ceiling: 1000, as_of_tx: store.current_position,
             activations: activations }.merge(over)
    described_class.call(**args)
  end

  it "injects weight > 0 in assemble order" do
    weights = {
      "urn:mm:user/1" => 0.8, "urn:mm:team/a" => 0.4, "urn:mm:project/x" => 0.9
    }
    r = serve_with(Vv::MedallionMemory::MapActivations.new(weights))
    expect(r[:ok]).to be(true)

    asm = Vv::MedallionMemory::Assemble.call(
      store: store, cue: "platform manager", node_budget: 6,
      token_ceiling: 1000, as_of_tx: store.current_position
    )
    expect(r[:injected].map { |s| s[:subject_iri] }).to eq(
      asm[:subjects].map { |s| s[:subject_iri] } & weights.keys
    )
    expect(r[:injected].map { |s| s[:weight] }).to all(be > 0)
  end

  it "weight == 0 is inspectable and never injected" do
    r = serve_with(Vv::MedallionMemory::MapActivations.new("urn:mm:team/a" => 0.0))
    expect(r[:injected].map { |s| s[:subject_iri] }).not_to include("urn:mm:team/a")
    expect(r[:inspectable].map { |s| s[:subject_iri] }).to include("urn:mm:team/a")
  end

  it "absent activation (nil) is unmodeled, not zero" do
    r = serve_with(Vv::MedallionMemory::MapActivations.new("urn:mm:user/1" => 0.5))
    expect(r[:unmodeled].map { |s| s[:subject_iri] }).to include("urn:mm:team/a")
    expect(r[:inspectable].map { |s| s[:subject_iri] }).not_to include("urn:mm:team/a")
  end

  it "negative weights suppress like zero: evidence, not injected evidence" do
    r = serve_with(Vv::MedallionMemory::MapActivations.new("urn:mm:team/a" => -0.3))
    expect(r[:injected].map { |s| s[:subject_iri] }).not_to include("urn:mm:team/a")
    expect(r[:inspectable].map { |s| s[:subject_iri] }).to include("urn:mm:team/a")
  end

  it "null activations inject the whole assembled pack" do
    r = serve_with(Vv::MedallionMemory::NullActivations.new)
    asm = Vv::MedallionMemory::Assemble.call(
      store: store, cue: "platform manager", node_budget: 6,
      token_ceiling: 1000, as_of_tx: store.current_position
    )
    expect(r[:injected].map { |s| s[:subject_iri] }).to eq(
      asm[:subjects].map { |s| s[:subject_iri] }
    )
    expect(r[:inspectable]).to eq([])
    expect(r[:unmodeled]).to eq([])
  end

  it "ordinary serve defaults as_of_tx to current position" do
    setup!
    r = described_class.call(
      store: store, cue: "platform", node_budget: 4, token_ceiling: 1000,
      activations: Vv::MedallionMemory::NullActivations.new
    )
    expect(r[:ok]).to be(true)
    expect(r[:as_of_tx]).to eq(store.current_position)
  end
end
