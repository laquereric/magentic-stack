# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "spec_helper"

RSpec.describe Mmg::Acia::Markdown do
  let(:nvc_tree) do
    Mmg::Acia::Tree.from_nvc({
      title: "your call",
      observation: "obs-X",
      need: "need-Y",
      request: { ask: "ask-Z?", options: [ { label: "approve", hint: "then merge" }, "decline" ] }
    })
  end

  it "materializes pane as H1 + bullets + checklist actions" do
    md = described_class.markdown(nvc_tree)
    expect(md).to start_with("# your call")
    expect(md).to include("- obs-X")
    expect(md).to include("- need-Y")
    expect(md).to include("- [ ] **approve**")
    expect(md).to include("- [ ] **decline**")
  end

  it "emits file-link + backtick IRI for file entity_tokens" do
    ref = described_class.md_ref(
      kind: "entity_token", value: "f",
      entity_iri: "urn:mm:file:a/b.rb", semantic_role: "file"
    )
    expect(ref).to include("[a/b.rb](/a/b.rb)")
    expect(ref).to include("`urn:mm:file:a/b.rb`")
    expect(ref).to include("_(file)_")
  end

  it "iri_path only resolves urn:mm:file: paths" do
    expect(described_class.iri_path("urn:mm:file:lib/x.rb")).to eq("lib/x.rb")
    expect(described_class.iri_path("urn:mm:epic:alpha")).to be_nil
  end

  it "never-raises on nil / empty" do
    expect(described_class.markdown(nil)).to eq("")
    expect(described_class.markdown({})).to include("-")
  end
end
