# frozen_string_literal: true
require "spec_helper"

RSpec.describe Mmg::Adr::Projection do
  let(:attrs) do
    { "adr_id" => "0042", "title" => "Pin the graph", "status" => "accepted",
      "date" => "2026-08-26", "subject_kind" => "gem", "subject" => "mmg-graph",
      "components" => ["mmg-graph"], "paths" => ["gems/mmg-graph/lib", "gems/mmg-graph/app"],
      "enforced_by" => ["gems/mmg-graph/spec/execute_spec.rb"],
      "supersedes" => "0011", "body_digest" => "deadbeef" }
  end

  it "types the subject and keys it by adr id" do
    t = described_class.triples(attrs)
    expect(t).to include("<urn:mm:adr:0042> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <urn:mm:vocab/adr#DecisionRecord> .")
  end

  it "emits one triple per list member" do
    t = described_class.triples(attrs)
    paths = t.grep(/adr#path>/)
    expect(paths.size).to eq(2)
  end

  # An ADR-to-ADR edge points at a subject IRI, so the ledger is walkable.
  it "projects supersedes as an IRI, not a string" do
    t = described_class.triples(attrs)
    expect(t).to include("<urn:mm:adr:0042> <urn:mm:vocab/adr#supersedes> <urn:mm:adr:0011> .")
  end

  it "omits absent attributes rather than emitting empty literals" do
    t = described_class.triples(attrs.merge("superseded_by" => nil, "subject" => ""))
    expect(t.grep(/supersededBy/)).to be_empty
    expect(t.grep(/adr#subject>/)).to be_empty
  end

  it "returns nothing for a record with no id, since there is no subject to speak of" do
    expect(described_class.triples(attrs.merge("adr_id" => nil))).to be_empty
  end

  it "escapes quotes and newlines so a title cannot break the triple" do
    t = described_class.triples(attrs.merge("title" => %(a "quoted" title\nwith a newline)))
    line = t.grep(/adr#title>/).first
    expect(line).to include('\\"quoted\\"')
    expect(line).to include("\\n")
    expect(line.scan("\n")).to be_empty
  end

  it "accepts symbol keys, so a record and a parse result project alike" do
    expect(described_class.triples(adr_id: "0042", title: "t")).to include(
      "<urn:mm:adr:0042> <urn:mm:vocab/adr#title> \"t\" ."
    )
  end
end
