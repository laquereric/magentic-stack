# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# MagenticMarket-Copyright-Notice: end v1

# Converted from Minitest on promotion into magentic-stack. The assertions are
# unchanged; only the framework moved.
#
# WHY IT HAD TO MOVE. This file sat in spec/ next to RSpec specs and opened with
# `require "minitest/autorun"`, which installs Minitest's own ARGV parser. This
# gem has no Gemfile, so bin/spec-all runs it in the ROOT workspace group -- one
# `bundle exec rspec` over every no-Gemfile gem at once. Loading this file made
# Minitest eat the command line and rspec printed its option help instead of
# running anything, for the whole group, silently passing nothing.
#
# Renaming it to _test.rb would have fixed the collision by making a working
# test never run again. Converting keeps the coverage, including the Platinum
# refusal, which is the medallion's cardinal rule.

# require_relative, not require: this gem has no Gemfile and no .rspec, so
# bin/spec-all runs it from the repo root with no -I. The sibling specs do the
# same.
require_relative "spec_helper"
require_relative "../lib/mmg/medallion/actionable"
require_relative "../lib/mmg/medallion/semantic_model"
require_relative "../lib/mmg/medallion/contract"

RSpec.describe "data layer fold" do
  purpose = Mmg::Medallion::Purpose
  actionable = Mmg::Medallion::Actionable

  it "keeps Purpose a closed vocabulary" do
    expect(purpose.valid?("build")).to be_truthy
    expect(purpose.valid?("CONSUME")).to be_truthy
    expect(purpose.valid?("nope")).to be_falsey
    expect(purpose.normalize!("Operate")).to eq("operate")
    expect(purpose.coerce("bogus")).to be_nil
    expect { purpose.normalize!("bogus") }.to raise_error(ArgumentError)
  end

  it "carries the Actionable registry, and does not know Platinum" do
    expect(actionable.for_tier("bronze")[:primary]).to eq("landing")
    expect(actionable.for_tier("gold")[:state_change]).to eq("conformed_to_governed_product")
    expect(actionable.evidence_for("gold").size).to eq(6)
    expect(actionable.evidence_for("gold")).to include("contract")
    expect(actionable.known?("platinum")).to be_falsey
    actionable::REGISTRY.each_value { |v| expect(v[:purpose]).to eq(purpose::BUILD) }
  end

  it "builds the value objects" do
    sm = Mmg::Medallion::SemanticModel.new(
      iri: "urn:sm", version: "1", status: "governed", owner: "o", definition: {}
    )
    expect(sm.governed?).to be_truthy

    c = Mmg::Medallion::Contract.new(
      iri: "urn:c", semantic_model_iri: "urn:sm", freshness_sla: "P1D"
    )
    expect(c.semantic_model_iri).to eq("urn:sm")
  end
end
