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
    expect(attrs["stand_in"]).to eq([])
    expect(attrs["unenforced"]).to be(false)
    expect(attrs["sections"].keys).to include("context", "decision", "consequences")
    expect(attrs["legacy"]).to be(false)
  end

  it "reads explicit unenforced and a stand_in list as distinct from enforced_by" do
    text = frontmatter("stand_in:\n  - docs/architecture/ROLE_SHAPE.md\nunenforced: true\nunenforced_because: ROLE=shape is unbuilt")
    attrs = described_class.parse(text)[:attributes]
    expect(attrs["unenforced"]).to be(true)
    expect(attrs["unenforced_because"]).to eq("ROLE=shape is unbuilt")
    expect(attrs["stand_in"]).to eq(["docs/architecture/ROLE_SHAPE.md"])
    expect(attrs["enforced_by"]).to eq(["gems/mmg-graph/spec/execute_spec.rb"])
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

  # MIGRATING AN ACCEPTED ADR TO FRONTMATTER.
  #
  # Without this the ledger's own immutability rule would freeze the legacy
  # records forever in a format the index can barely read -- immutability
  # protecting a typography choice rather than a decision. The digest excludes
  # the preamble metadata, so the equality below IS the evidence that migration
  # moved metadata and nothing else.
  it "digests a legacy ADR and its migrated frontmatter form identically" do
    prose = <<~MD

      ## Context

      Frontier AI churns on a 90-day loop.

      ## Decision

      Make ownership legible from the path.
    MD
    legacy = "# ADR 0001 — Ownership boundary\n\n- Status: Accepted\n- Date: 2026-08-18\n" + prose
    migrated = "---\nid: \"0001\"\ntitle: Ownership boundary\nstatus: accepted\ndate: 2026-08-18\n---\n" + prose

    a = described_class.parse(legacy, path: "docs/adr/0001-x.md")[:attributes]
    b = described_class.parse(migrated, path: "docs/adr/0001-x.md")[:attributes]

    expect(a["body_digest"]).to eq(b["body_digest"])
    expect(a["legacy"]).to be(true)
    expect(b["legacy"]).to be(false)
  end

  # Scoped to the preamble. A "- Date:" inside Consequences is decision text.
  it "digests a Date line inside a section, because there it is prose" do
    base = "---\nid: \"9\"\nstatus: accepted\n---\n\n## Consequences\n\nSomething.\n"
    with = "---\nid: \"9\"\nstatus: accepted\n---\n\n## Consequences\n\n- Date: matters here\n\nSomething.\n"

    expect(described_class.parse(base)[:attributes]["body_digest"])
      .not_to eq(described_class.parse(with)[:attributes]["body_digest"])
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

  it "refuses genuinely unparsable YAML instead of treating it as empty fields" do
    text = "---\nfoo: [unterminated\n---\n\n## Context\n\nx\n"
    r = described_class.parse(text)
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:unparsable_frontmatter)
    expect(r[:because]).to be_a(Hash)
    expect(r[:because]["detail"]).to eq("YAML did not parse")
  end

  it "treats empty frontmatter as no fields, not as unparsable" do
    r = described_class.parse("---\n\n---\n\n## Context\n\nx\n")
    expect(r[:ok]).to be(true)
    expect(r[:attributes]["title"]).to be_nil
    expect(r[:attributes]["legacy"]).to be(false)
  end

  it "refuses a YAML scalar or list in the --- block as not a mapping" do
    r = described_class.parse("---\njust-a-string\n---\n\n## Context\n\nx\n")
    expect(r[:ok]).to be(false)
    expect(r[:reason]).to eq(:frontmatter_not_a_mapping)
  end

  it "falls back to the filename for an id, and reports none when there is none" do
    expect(described_class.parse("# no heading", path: "docs/adr/0007-x.md")[:attributes]["adr_id"]).to eq("0007")
    expect(described_class.parse("# no heading", path: "docs/adr/notes.md")[:attributes]["adr_id"]).to be_nil
  end
end
