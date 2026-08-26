# frozen_string_literal: true
require "spec_helper"

# Runs against the REPOSITORY'S OWN docs/adr, not a fixture. A governance index
# proven only against fixtures is a governance index nobody has pointed at the
# thing it governs.
RSpec.describe Mmg::Adr::Ingest do
  let(:repo_root) { File.expand_path("../../..", __dir__) }
  let(:dir) { File.join(repo_root, "docs/adr") }
  # publish: false -- the graph is a live Oxigraph over HTTP, and a spec suite
  # that needs one is a spec suite that gets skipped.
  let(:result) { described_class.call(dir: dir, repo_root: repo_root, publish: false) }

  it "ingests every ADR in the repository without failing on any of them" do
    expect(result[:failed]).to eq([])
    expect(result[:ok]).to be(true)
    expect(result[:ingested]).to be >= 29
  end

  it "reads every ADR, including the migrated former-legacy ones" do
    expect(result[:records]).to include("0001", "0002", "0003", "0014", "0021")
  end

  it "gives every ADR a row keyed by its id" do
    result
    expect(Mmg::Adr::Record.where(adr_id: "0014").count).to eq(1)
    record = Mmg::Adr::Record.find_by(adr_id: "0014")
    expect(record.subject).to eq("mmg-adr")
    expect(record.subject_kind).to eq("gem")
    expect(record.status).to eq("accepted")
    expect(record.paths).to include("gems/mmg-adr/lib")
  end

  # The query the files alone cannot answer -- and the reason the lifecycle is
  # more than bookkeeping: asking for the ACCEPTED decision returns the one in
  # force, not the superseded one it replaced.
  it "answers which accepted decision governs a given gem, skipping the superseded one" do
    result
    # Two accepted decisions govern mmg-graph: the grounding refusal (0032) and
    # the store behind it (0034, split out of 0003). Neither superseded record
    # is returned.
    expect(Mmg::Adr::Record.where(status: "accepted", subject: "mmg-graph").order(:adr_id).pluck(:adr_id))
      .to eq(%w[0032 0034])
    expect(Mmg::Adr::Record.where(subject: "mmg-graph").order(:adr_id).pluck(:adr_id, :status))
      .to eq([["0011", "superseded"], ["0032", "accepted"], ["0034", "accepted"]])
  end

  # A fitness function, not a claim: every profile shipped under
  # gems/osi-level-8-profiles must have a decision record. A profile whose shapes
  # are in the tree with no ADR is a rule the fleet cannot read.
  it "has an ADR for every profile in the tree" do
    result
    shipped = Dir.glob(File.join(repo_root, "gems/osi-level-8-profiles/profile-*"))
                 .map { |d| "P" + File.basename(d)[/\Aprofile-(\d+)/, 1] }.sort
    recorded = Mmg::Adr::Record.where(subject_kind: "profile").pluck(:subject)

    expect(shipped).not_to be_empty
    expect(shipped - recorded).to eq([]), "profiles with shapes but no ADR: #{(shipped - recorded).join(', ')}"
  end

  # P10 was the one profile with an implementation and no shapes, invisible to
  # Gate 2. ADR 0031 closed that; 0029 records the gap as it stood.
  it "records P10 as no longer the exception -- it has shapes now" do
    result
    live = Mmg::Adr::Record.where(subject: "P10").order(:adr_id).pluck(:adr_id, :status)
    expect(live).to eq([["0029", "superseded"], ["0031", "accepted"]])
    expect(Dir.exist?(File.join(repo_root, "gems/osi-level-8-profiles/profile-10-intent/shapes"))).to be(true)
  end

  # The property that makes the shapes worth having: EVERY profile directory is
  # now validated by the conformance gate, with none left out.
  it "leaves no profile carrying an implementation but no shapes" do
    shipped = Dir.glob(File.join(repo_root, "gems/osi-level-8-profiles/profile-*"))
    unshaped = shipped.reject { |d| Dir.glob(File.join(d, "shapes/*.ttl")).any? }
    expect(unshaped).to eq([]), "profile dirs with no shapes: #{unshaped.map { |d| File.basename(d) }.join(', ')}"
    expect(shipped.size).to eq(11)
  end

  # The Manus-drafted profiles ship shapes but no implementation. Recording them
  # as accepted would claim a settled decision the evidence does not support.
  it "keeps unimplemented draft profiles proposed rather than accepted" do
    result
    proposed = Mmg::Adr::Record.where(subject_kind: "profile", status: "proposed").pluck(:subject).sort
    expect(proposed).to eq(%w[P2 P3 P5 P6 P7 P8])
  end

  it "reports the chain breaks it finds rather than raising on them" do
    breaks = result[:chain_breaks].to_h { |b| [b[:adr_id], b[:missing]] }

    # The legacy three are migrated now: frontmatter, paths, enforced_by.
    expect(breaks).not_to have_key("0001")
    # 0011 and 0017 are gone too: 0011 was closed by specs (superseded by 0032),
    # and 0017's break was never real -- the survey that found it globbed only
    # the top level of spec/ and missed vv-graph's 38 nested files (ADR 0033).
    expect(breaks).not_to have_key("0011")
    expect(breaks).not_to have_key("0017")

    # 0020 is NOT here. It was superseded by 0030 once the boundary became
    # mechanical, and a superseded record is history -- reporting a missing
    # enforcement link on it would grow the finding list forever.
    expect(breaks).not_to have_key("0020")

    # An ADR that names real tests and real code has no break.
    expect(breaks).not_to have_key("0014")
    expect(breaks).not_to have_key("0007")

    # Every remaining break is a legacy ADR. A new one appearing here is the
    # signal this whole apparatus exists to give.
    # NOTHING is broken. Every ADR in force names what enforces it and what it
    # governs. A new break appearing here is the signal this apparatus exists for.
    expect(breaks).to be_empty
  end

  it "walks the supersession edge, so a replaced decision leads to its replacement" do
    result
    old = Mmg::Adr::Record.find_by(adr_id: "0020")
    expect(old.status).to eq("superseded")
    expect(old.superseded_by).to eq(["0030"])
    expect(Mmg::Adr::Record.find_by(adr_id: "0030").supersedes).to eq(["0020"])

    # And the edge is an IRI in the graph, not a string, so the ledger is walkable.
    expect(old.triples).to include(
      "<urn:mm:adr:0020> <urn:mm:vocab/adr#supersededBy> <urn:mm:adr:0030> ."
    )
  end

  # ADR 0003 bundled a settled decision with an open one under a single
  # "Accepted". Split: each half now carries the status it has earned, and BOTH
  # successors are reachable from the record they replaced.
  it "walks a split to both successors, with their real statuses" do
    result
    old = Mmg::Adr::Record.find_by(adr_id: "0003")
    expect(old.status).to eq("superseded")
    expect(old.superseded_by).to eq(%w[0034 0035])

    successors = Mmg::Adr::Record.where(adr_id: old.superseded_by).order(:adr_id)
    expect(successors.pluck(:adr_id, :status)).to eq([["0034", "accepted"], ["0035", "proposed"]])
    expect(successors.map(&:supersedes)).to all(eq(["0003"]))

    expect(old.triples.grep(/supersededBy/).size).to eq(2)
  end

  # The open question stays open until someone answers it. A `proposed` record
  # silently becoming `accepted` is the false confidence this index exists to
  # prevent, and this is the one decision in the tree with live consumers on
  # both sides of an unresolved vocabulary.
  it "keeps the ACIA convergence proposed, not accepted" do
    result
    expect(Mmg::Adr::Record.find_by(adr_id: "0035").status).to eq("proposed")
  end

  # Every path and every enforcing mechanism an ADR names must resolve. This is
  # the check that catches a decision still in an agent's search reach after the
  # code it governs has moved.
  it "finds no ADR pointing at a path that does not exist" do
    expect(result[:dangling]).to eq([])
  end

  it "is idempotent -- re-reading unchanged files writes nothing new" do
    result
    before = Mmg::Adr::Record.count
    described_class.call(dir: dir, repo_root: repo_root, publish: false)
    expect(Mmg::Adr::Record.count).to eq(before)
  end

  it "refuses a directory that is not there, instead of raising" do
    out = described_class.call(dir: "/nope/not/here", publish: false)
    expect(out[:ok]).to be(false)
    expect(out[:reason]).to eq(:no_such_dir)
  end
end
