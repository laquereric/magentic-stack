# frozen_string_literal: true
require "spec_helper"

# ADR 0035 -- the constraint that holds while the ACIA vocabulary question is open.
#
# rails-osi-level-8 is a baseline gem: the rails-base image builds it in, and two
# production sites consume it (stewardshiptranslation.com, magenticmarket.ai).
# Removing Profile 9's ACIA before the repin sequence completes is a half-cut --
# the image still builds and the sites do not boot, which is the worst ordering
# of those two facts.
#
# Deleting it already breaks six other spec files. This one exists so that when
# it happens the failure SAYS WHY, instead of leaving someone to infer it from a
# handful of unrelated errors.
RSpec.describe "Profile 9 ACIA stays in rails-osi-level-8 until the repin lands" do
  it "still defines the ACIA document surface" do
    expect(defined?(RailsOsiLevel8::Profile9::Acia)).to eq("constant"),
      "Profile 9 ACIA was removed from rails-osi-level-8. If the ACIA convergence " \
      "decision (ADR 0035) has been taken, complete the repin sequence -- Gemfile " \
      "ref in rails-base + both sites, rebuild, redeploy -- and update ADR 0035. " \
      "If it has not been taken, this is a half-cut: the image builds, the sites do not boot."
  end

  it "still carries the closed vocabulary the sites render against" do
    expect(RailsOsiLevel8::Profile9::Acia::SEMANTIC_ROLES).to be_an(Array)
    expect(RailsOsiLevel8::Profile9::Acia::LAYOUT_KINDS).to be_an(Array)
    expect(RailsOsiLevel8::Profile9::Acia::FORBIDDEN_PROP_KEYS).to include("html")
  end

  it "still renders, which is what the two sites actually call" do
    expect(defined?(RailsOsiLevel8::Profile9::Renderer)).to eq("constant")
  end
end
