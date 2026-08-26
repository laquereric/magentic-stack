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

  it "reads the legacy bullet ADRs alongside the frontmatter ones" do
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

  # The query the files alone cannot answer.
  it "answers which accepted decisions govern a given gem" do
    result
    governing = Mmg::Adr::Record.where(status: "accepted", subject: "mmg-graph").pluck(:adr_id)
    expect(governing).to eq(["0011"])
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

  # P10 is implemented in Ruby with no shapes directory, so the check above
  # cannot see it. Named explicitly rather than left to be noticed.
  it "records P10, which has an implementation but no shapes" do
    result
    expect(Mmg::Adr::Record.find_by(subject: "P10")&.adr_id).to eq("0029")
    expect(Dir.exist?(File.join(repo_root, "gems/osi-level-8-profiles/profile-10"))).to be(false)
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

    # The three legacy ADRs declare no paths and no enforcing mechanism.
    expect(breaks["0001"]).to eq(:constraint)
    # Recorded honestly in the ADRs themselves: these gems have no spec suite.
    expect(breaks["0011"]).to eq(:constraint)
    expect(breaks["0017"]).to eq(:constraint)
    expect(breaks["0020"]).to eq(:constraint)

    # An ADR that names real tests and real code has no break.
    expect(breaks).not_to have_key("0014")
    expect(breaks).not_to have_key("0007")
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
