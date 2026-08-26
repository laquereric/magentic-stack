# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Graph::Entry do
  def build(**over)
    described_class.new({ date: "2026-08-26", name: "n", description: "d" }.merge(over))
  end

  # Triples say what was asserted; they never say why it is here, and the why is
  # what a later reader needs.
  it "requires a date, a name and a description" do
    expect(build).to be_valid
    %i[date name description].each do |field|
      e = build(field => nil)
      expect(e).not_to be_valid, "#{field} should be required"
      expect(e.errors[field]).not_to be_empty
    end
  end

  it "refuses a blank description as firmly as a missing one" do
    expect(build(description: "")).not_to be_valid
  end

  # Derived from the primary key, never supplied: a caller that could name its
  # own graph could write into someone else's.
  it "derives the graph name from its id" do
    e = build; e.save!
    expect(e.graph_name).to eq("urn:mmg:graph:entry:#{e.id}")
  end

  it "has no graph before it is saved, and says so instead of inventing one" do
    expect { build.graph_name }.to raise_error(/unsaved entry has no graph/)
  end

  it "exposes the ref shape vv-graph uses for every projected record" do
    e = build; e.save!
    expect(e.ref).to eq("Mmg::Graph::Entry:#{e.id}")
  end

  it "gives each entry its own graph, so two assertions cannot collide" do
    a = build(name: "a"); a.save!
    b = build(name: "b"); b.save!
    expect(a.graph_name).not_to eq(b.graph_name)
  end
end
