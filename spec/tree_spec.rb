# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require_relative "spec_helper"

# RSpec LEAVES for Mmg::Acia::Tree builders (ACIA OUT). Pure node-hash contract;
# presentation hosts (mmg-sal unix_tree/dom) are covered separately.
RSpec.describe Mmg::Acia::Tree do
  describe ".from_nvc" do
    let(:message) do
      {
        title: "your call",
        observation: "obs-X",
        need: "need-Y",
        request: {
          ask: "ask-Z?",
          options: [ { label: "approve", hint: "then merge" }, "decline" ]
        }
      }
    end
    subject(:tree) { described_class.from_nvc(message) }

    it "builds pane → text, text, list(action*)" do
      expect(tree[:kind]).to eq("pane")
      expect(tree[:value]).to eq("your call")
      expect(tree[:children].map { |c| c[:kind] }).to eq(%w[text text list])
    end

    it "binds observation / need / ask and action affordances" do
      expect(tree[:children][0][:value]).to eq("obs-X")
      expect(tree[:children][1][:value]).to eq("need-Y")
      list = tree[:children].last
      expect(list[:value]).to eq("ask-Z?")
      expect(list[:children].map { |a| [ a[:kind], a[:value] ] }).to eq(
        [ %w[action approve], %w[action decline] ]
      )
      expect(list[:children].first[:hint]).to eq("then merge")
    end

    it "never-raises on empty / non-hash input" do
      expect { described_class.from_nvc(nil) }.not_to raise_error
      expect(described_class.from_nvc(nil)[:kind]).to eq("pane")
      expect(described_class.from_nvc({})[:children].last[:children]).to eq([])
    end
  end

  describe ".from_arc" do
    subject(:tree) do
      described_class.from_arc(
        arc: "arc/x", epic: "epic_1", epic_iri: "urn:mm:epic:epic_1",
        selected: "sel", completed: "done"
      )
    end

    it "builds a sign-off pane with epic entity_token + affordance list" do
      expect(tree[:kind]).to eq("pane")
      expect(tree[:value]).to include("ARC arc/x")
      kinds = tree[:children].map { |c| c[:kind] }
      expect(kinds).to include("entity_token", "list")
    end

    it "grounds the epic EntityToken" do
      et = tree[:children].find { |c| c[:kind] == "entity_token" }
      expect(et[:semantic_role]).to eq("epic")
      expect(et[:entity_iri]).to eq("urn:mm:epic:epic_1")
      expect(et[:value]).to include("epic_1")
    end

    it "defaults review/approve/decline actions" do
      list = tree[:children].find { |c| c[:kind] == "list" }
      expect(list[:children].map { |a| a[:value] }).to eq(%w[review approve decline])
    end
  end

  describe ".from_acia" do
    subject(:tree) do
      described_class.from_acia(
        arc: "arc_1",
        epic: "epic_1",
        plan: "PLAN_x",
        frictions: [ { slug: "db-lock", detail: "sqlite locked" } ],
        briefs: [ { id: "b1", detail: "do the thing" } ],
        files: [ { path: "lib/foo.rb", classes: [ "Foo" ] } ],
        diffs: [ { path: "lib/foo.rb", patch: "L1\nL2\nL3" } ],
        options: [ { label: "approve", action: "arc_approve" }, "decline" ],
        git_repos: [ { name: "mm", status: "dirty", ahead: 1, behind: 0 } ],
        pr_title: "feat: x",
        pr_body: "body",
        completed: "merged",
        loss: "0.1"
      )
    end

    def walk(node, &blk)
      return unless node.is_a?(Hash)

      yield node
      Array(node[:children]).each { |c| walk(c, &blk) }
    end

    def roles_in(tree)
      found = []
      walk(tree) { |n| found << n[:semantic_role].to_s if n[:semantic_role].to_s != "" }
      found.uniq
    end

    it "emits the lineage entity roles used by selection→ops" do
      expect(roles_in(tree)).to include(
        "friction", "plan", "epic", "arc", "brief", "file", "diff", "repo", "mcb_action"
      )
    end

    it "always appends enter friction to the call list" do
      call = tree[:children].last
      expect(call[:kind]).to eq("list")
      expect(call[:value]).to eq("your call")
      expect(call[:children].map { |a| a[:value] }).to include("enter friction")
    end

    it "grounds mcb_action options with entity_iri" do
      action = tree[:children].last[:children].find { |a| a[:value] == "approve" }
      expect(action[:semantic_role]).to eq("mcb_action")
      expect(action[:entity_iri]).to eq("urn:mm:action:arc_approve")
    end

    it "grounds files, diffs, and class tokens" do
      file = nil
      walk(tree) { |n| file = n if n[:semantic_role] == "file" }
      expect(file[:entity_iri]).to eq("urn:mm:file:lib/foo.rb")
      klass = file[:children].find { |c| c[:semantic_role] == "class" }
      expect(klass[:value]).to eq("Foo")
      expect(klass[:entity_iri]).to eq("urn:mm:class:Foo")
    end

    it "shows clean-git message when total > 0 and list empty" do
      clean = described_class.from_acia(arc: "a", git_repos: [], git_repos_total: 3)
      text = clean[:children].find { |c| c[:kind] == "text" && c[:value].to_s.include?("clean") }
      expect(text[:value]).to include("all 3 repos clean")
    end
  end

  describe ".from_rows" do
    it "maps SPARQL rows to entity_tokens with unquoted IRI/label" do
      rows = [ { "s" => "<urn:mm:epic:alpha>", "label" => "\"Alpha\"^^xsd:string" } ]
      tree = described_class.from_rows(rows, title: "epics", iri_key: "s", label_keys: [ "label" ], role: "epic")
      tok = tree[:children].first
      expect(tree[:kind]).to eq("pane")
      expect(tok[:kind]).to eq("entity_token")
      expect(tok[:entity_iri]).to eq("urn:mm:epic:alpha")
      expect(tok[:value]).to eq("Alpha")
      expect(tok[:semantic_role]).to eq("epic")
    end
  end

  describe ".detail_lines / .diff_node / .unquote" do
    it "caps detail_lines with a remainder marker" do
      lines = described_class.detail_lines("a\nb\nc\nd", 2, 96)
      expect(lines.size).to eq(3)
      expect(lines.last[:value]).to match(/more line/)
    end

    it "builds a capped diff entity_token" do
      node = described_class.diff_node({ path: "a.rb", patch: (1..5).map { |i| "L#{i}" }.join("\n") }, 2)
      expect(node[:semantic_role]).to eq("diff")
      expect(node[:entity_iri]).to eq("urn:mm:file:a.rb")
      expect(node[:children].size).to eq(3)
      expect(node[:children].last[:value]).to include("more")
    end

    it "unquotes IRI and typed/lang literals" do
      expect(described_class.unquote("<urn:mm:x>")).to eq("urn:mm:x")
      expect(described_class.unquote(%q("hi"@en))).to eq("hi")
      expect(described_class.unquote(%q("hi"^^xsd:string))).to eq("hi")
    end
  end
end
