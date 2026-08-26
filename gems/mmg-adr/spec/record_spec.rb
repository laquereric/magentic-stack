# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Adr::Record do
  def build(**overrides)
    described_class.new({
      adr_id: "0042", title: "Pin the graph by digest", status: "proposed",
      date: "2026-08-26", subject_kind: "gem", subject: "mmg-graph", body_digest: "aaa"
    }.merge(overrides))
  end

  it "stores list attributes so they read back as lists" do
    r = build
    r.paths = ["gems/mmg-graph/lib", "gems/mmg-graph/app"]
    r.save!
    expect(r.reload.paths).to eq(["gems/mmg-graph/lib", "gems/mmg-graph/app"])
  end

  it "refuses a status outside the lifecycle" do
    r = build(status: "draft")
    expect(r).not_to be_valid
    expect(r.errors[:status].join).to match(/proposed, accepted or superseded/)
  end

  # The ledger property. Editing an accepted decision in place destroys the
  # reason the ledger was worth keeping.
  it "refuses to edit the body of an accepted ADR" do
    r = build(status: "accepted"); r.save!
    r.body_digest = "bbb"

    expect(r.save).to be(false)
    expect(r.errors[:body_digest].join).to match(/supersede it with a new record/)
  end

  it "allows editing a proposed ADR, which is not yet a ledger entry" do
    r = build(status: "proposed"); r.save!
    r.body_digest = "bbb"
    expect(r.save).to be(true)
  end

  it "refuses to walk the lifecycle backwards" do
    r = build(status: "accepted"); r.save!
    r.status = "proposed"

    expect(r.save).to be(false)
    expect(r.errors[:status].join).to match(/backwards/)
  end

  it "lets a proposed ADR be accepted" do
    r = build(status: "proposed"); r.save!
    r.status = "accepted"
    expect(r.save).to be(true)
  end

  # A superseded record with no successor announces that it no longer holds
  # without saying what does.
  it "refuses to supersede without naming the successor" do
    r = build(status: "accepted"); r.save!
    r.status = "superseded"

    expect(r.save).to be(false)
    expect(r.errors[:superseded_by].join).to match(/name the ADR that replaces/)
  end

  it "supersedes when the successor is named" do
    r = build(status: "accepted"); r.save!
    r.status = "superseded"
    r.superseded_by = "0099"
    expect(r.save).to be(true)
  end

  it "keeps adr_id unique -- one decision, one row" do
    build.save!
    expect(build(body_digest: "ccc")).not_to be_valid
  end
end

RSpec.describe Mmg::Adr::Record, "metadata on an accepted ADR" do
  it "accepts a path correction, because the decision text has not changed" do
    r = described_class.new(adr_id: "0007", title: "P9", status: "accepted", body_digest: "aaa")
    r.paths = ["gems/rails-osi-level-8/lib/rails_osi_level_8/profile9"]
    r.save!

    # The shapes moved from grammar/ to gems/ (ADR 0022). The decision did not.
    r.paths = r.paths + ["gems/osi-level-8-profiles/profile-9-governed-human-interaction-surface"]
    expect(r.save).to be(true)
    expect(r.reload.paths.size).to eq(2)
  end
end
