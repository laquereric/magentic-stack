# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Adr::Document do
  def frontmatter(extra = "")
    <<~MD
      ---
      id: "0042"
      title: Pin the graph by digest
      status: accepted
      date: 2026-08-26
      subject_kind: gem
      subject: mmg-graph
      components: [mmg-graph]
      paths:
        - gems/mmg-graph/lib
      enforced_by:
        - gems/mmg-graph/spec/execute_spec.rb
      #{extra}
      ---

      ## Context

      Ad-hoc triples had nothing to reference.

      ## Decision

      Publish requires a grounded entry.

      ## Consequences

      Nothing anonymous can be written.
    MD
  end

  it "reads the metadata a machine needs and the body a human reads" do
    attrs = described_class.parse(frontmatter, path: "docs/adr/0042-x.md")[:attributes]

    expect(attrs["adr_id"]).to eq("0042")
    expect(attrs["status"]).to eq("accepted")
    expect(attrs["subject"]).to eq("mmg-graph")
    expect(attrs["paths"]).to eq(["gems/mmg-graph/lib"])
    expect(attrs["enforced_by"]).to eq(["gems/mmg-graph/spec/execute_spec.rb"])
    expect(attrs["sections"].keys).to include("context", "decision", "consequences")
    expect(attrs["legacy"]).to be(false)
  end

  it "ignores blank-line and trailing-whitespace changes, which are invisible when rendered" do
    a = described_class.parse(frontmatter)[:attributes]["body_digest"]
    b = described_class.parse(frontmatter.gsub("\n\n", "\n\n\n") + "   \n")[:attributes]["body_digest"]
    expect(a).to eq(b)
  end

  # This is what lets an ACCEPTED ADR stay alive. Code moves; an ADR whose paths
  # can never be corrected points at nothing soon after, and a dead ADR is worse
  # than none. So the DECISION TEXT is immutable and the METADATA THAT POINTS AT
  # CODE is maintainable -- the digest covers only the former.
  it "does not digest the frontmatter, so paths stay correctable on an accepted ADR" do
    before = described_class.parse(frontmatter)[:attributes]["body_digest"]
    moved  = frontmatter.sub("  - gems/mmg-graph/lib", "  - gems/mmg-graph/lib\n  - gems/mmg-graph/app")
    after  = described_class.parse(moved)[:attributes]

    expect(after["paths"]).to eq(["gems/mmg-graph/lib", "gems/mmg-graph/app"])
    expect(after["body_digest"]).to eq(before)
  end

  it "digests a changed decision differently" do
    a = described_class.parse(frontmatter)[:attributes]["body_digest"]
    b = described_class.parse(frontmatter.sub("grounded entry", "any entry"))[:attributes]["body_digest"]
    expect(a).not_to eq(b)
  end

  # The three pre-existing ADRs predate the frontmatter convention. Refusing them
  # would leave three ACCEPTED decisions outside the index -- the exact failure.
  it "reads the legacy bullet form and flags it rather than normalising it away" do
    legacy = <<~MD
      # ADR 0001 — Make the ownership boundary visible in the tree

      - Status: Accepted
      - Date: 2026-08-18

      ## Context

      Frontier AI churns on a 90-day loop.
    MD

    attrs = described_class.parse(legacy, path: "docs/adr/0001-ownership-boundary.md")[:attributes]
    expect(attrs["adr_id"]).to eq("0001")
    expect(attrs["title"]).to eq("Make the ownership boundary visible in the tree")
    expect(attrs["status"]).to eq("accepted")
    expect(attrs["date"]).to eq("2026-08-18")
    expect(attrs["legacy"]).to be(true)
    expect(attrs["paths"]).to be_empty
  end

  it "reads 'Supersedes nothing; extends ADR 0001' as a status, not a sentence" do
    legacy = "# ADR 0002 — Self-referential consolidation\n\n- Status: Accepted\n- Date: 2026-08-18\n"
    expect(described_class.parse(legacy)[:attributes]["status"]).to eq("accepted")
  end

  it "falls back to the filename for an id, and reports none when there is none" do
    expect(described_class.parse("# no heading", path: "docs/adr/0007-x.md")[:attributes]["adr_id"]).to eq("0007")
    expect(described_class.parse("# no heading", path: "docs/adr/notes.md")[:attributes]["adr_id"]).to be_nil
  end
end
