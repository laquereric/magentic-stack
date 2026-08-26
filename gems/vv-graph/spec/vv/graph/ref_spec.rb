# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "spec_helper"

# Ref is what makes the graph a PROJECTION of the relational store rather than a
# peer of it: a node is addressed by (model class, primary key). It is exercised
# through Publisher and the S2 projection, but its own contract had no spec --
# and it is the contract mmg-graph's grounding rule is built on.
RSpec.describe Vv::Graph::Ref do
  it "accepts a class and a class name interchangeably, since both name the same concept" do
    expect(described_class.new("Mm::Thing", 42)).to eq(described_class.new("Mm::Thing", 42))
    expect(described_class.new(String, 1).type).to eq("String")
    expect(described_class.new("String", 1)).to eq(described_class.new(String, 1))
  end

  it "keeps the fully-qualified name, so two models with the same demodulized name stay distinct" do
    expect(described_class.new("A::Thing", 1)).not_to eq(described_class.new("B::Thing", 1))
  end

  it "distinguishes rows of the same type" do
    expect(described_class.new("Mm::Thing", 1)).not_to eq(described_class.new("Mm::Thing", 2))
  end

  # Identity is (type, id). If it were object identity, a ref rebuilt from a
  # queue payload would not match the one that scheduled it.
  it "hashes by value, so an equal ref is the same key" do
    a = described_class.new("Mm::Thing", 7)
    b = described_class.new("Mm::Thing", 7)

    expect(a.hash).to eq(b.hash)
    expect({ a => :v }[b]).to eq(:v)
    expect([a, b].uniq.size).to eq(1)
  end

  it "is frozen, because a mutable identity is not one" do
    expect(described_class.new("Mm::Thing", 1)).to be_frozen
  end

  # THE INVARIANT THE PROJECTION RESTS ON.
  #
  # A ref names a row. When the row is gone the ref resolves to nil rather than
  # raising or inventing a node -- which is why triples about something with no
  # row have nowhere to attach.
  describe "#resolve" do
    it "returns nil for a class that does not exist, instead of raising NameError" do
      expect(described_class.new("No::Such::Model", 1).resolve).to be_nil
    end

    it "returns nil for a class that is not a model" do
      expect(described_class.new("String", 1).resolve).to be_nil
    end

    it "returns nil when the class exists but the row is gone" do
      klass = Class.new do
        def self.name = "GoneRowModel"
        def self.find_by(**) = nil
      end
      stub_const("GoneRowModel", klass)

      expect(described_class.new("GoneRowModel", 99).resolve).to be_nil
    end

    it "returns the row when it is there, looked up by primary key" do
      row = Object.new
      klass = Class.new do
        class << self
          attr_accessor :row, :asked_for
        end
        def self.name = "PresentRowModel"
        def self.find_by(id:)
          self.asked_for = id
          row
        end
      end
      klass.row = row
      stub_const("PresentRowModel", klass)

      expect(described_class.new("PresentRowModel", 5).resolve).to be(row)
      expect(klass.asked_for).to eq(5)
    end
  end

  it "prints in a form that names the row it stands for" do
    expect(described_class.new("Mm::Thing", 42).to_s).to eq("Vv::Graph::Ref(Mm::Thing:42)")
  end

  it "is not equal to a bare tuple that happens to carry the same values" do
    expect(described_class.new("Mm::Thing", 1)).not_to eq(["Mm::Thing", 1])
  end
end
