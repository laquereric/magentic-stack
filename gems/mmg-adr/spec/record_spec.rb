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
    expect(r.errors[:superseded_by].join).to match(/name the ADR/)
  end

  it "supersedes when the successor is named" do
    r = build(status: "accepted"); r.save!
    r.status = "superseded"
    r.superseded_by = ["0099"]
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

RSpec.describe Mmg::Adr::Record, "succession by more than one ADR" do
  def build(**over)
    described_class.new({ adr_id: "0003", title: "bundled", status: "accepted", body_digest: "aaa" }.merge(over))
  end

  # A SPLIT. An ADR that bundled a settled decision with an open one is replaced
  # by two, each carrying the status it has actually earned. Naming one successor
  # and dropping the other would be the ledger lying to keep its schema.
  it "accepts two successors" do
    r = build; r.save!
    r.status = "superseded"
    r.superseded_by = %w[0034 0035]

    expect(r.save).to be(true)
    expect(r.reload.superseded_by).to eq(%w[0034 0035])
  end

  it "leaves BOTH edges in the graph, so neither half is unreachable" do
    r = build(status: "superseded"); r.superseded_by = %w[0034 0035]; r.save!

    expect(r.triples).to include(
      "<urn:mm:adr:0003> <urn:mm:vocab/adr#supersededBy> <urn:mm:adr:0034> .",
      "<urn:mm:adr:0003> <urn:mm:vocab/adr#supersededBy> <urn:mm:adr:0035> ."
    )
  end

  it "still refuses an empty successor list" do
    r = build; r.save!
    r.status = "superseded"
    r.superseded_by = []

    expect(r.save).to be(false)
    expect(r.errors[:superseded_by].join).to match(/name the ADR/)
  end

  it "reads a single successor as a one-element list, so old records still parse" do
    r = build(status: "superseded"); r.superseded_by = "0034"; r.save!
    expect(r.reload.superseded_by).to eq(["0034"])
  end
end

RSpec.describe Mmg::Adr::Vocabulary, "what an ADR can be about" do
  it "admits a decision about the repository itself" do
    # ADR 0038 (magentic-stack is closed) is scoped to the repo, not to any gem,
    # profile, protocol or tool inside it. Without this kind the decision could
    # only be recorded by mislabelling its subject.
    expect(described_class.subject_kind?("repo")).to be(true)
  end

  it "stays closed, so \"which subjects have no decision record\" has an answer" do
    expect(described_class::SUBJECT_KINDS).to eq(
      %w[protocol profile gem tooling repo topology doctrine data]
    )
    expect(described_class.subject_kind?("topology")).to be(true)
    expect(described_class.subject_kind?("doctrine")).to be(true)
    expect(described_class.subject_kind?("data")).to be(true)
    expect(described_class.subject_kind?("whatever")).to be(false)
  end
end
