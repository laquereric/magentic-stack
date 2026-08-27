# frozen_string_literal: true
require "ar_spec_helper"

RSpec.describe Mmg::Acia::Node, "previews that name their affordances" do
  def node(**over)
    described_class.create!({ tree_key: "arc:34", kind: "entity_token", position: 0 }.merge(over))
  end

  def affordance(label, action, tree_key: "arc:34")
    node(tree_key: tree_key, kind: "action", value: label,
         semantic_role: "mcb_action", entity_iri: "urn:mm:action:#{action}")
  end

  def brief(tree_key: "arc:34")
    node(tree_key: tree_key, value: "brf_1", semantic_role: "brief",
         entity_iri: "urn:mm:brief:brf_1")
  end

  describe ".affordances_for" do
    it "lists what the pane offers, in materialized order" do
      affordance("review", "arc_flow_run_show")
      affordance("approve", "arc_sign_off")
      affordance("decline", "arc_sign_off")

      expect(described_class.affordances_for("arc:34")).to eq(%w[review approve decline])
    end

    it "excludes an action node bound to nothing -- it is not on offer" do
      affordance("review", "arc_flow_run_show")
      node(kind: "action", value: "ghost", entity_iri: nil)
      node(kind: "action", value: "also-ghost", entity_iri: "urn:mm:brief:not-an-action")

      expect(described_class.affordances_for("arc:34")).to eq(%w[review])
    end

    it "does not leak affordances across panes" do
      affordance("review", "arc_flow_run_show")
      affordance("merge", "brief_arc_merge_approve", tree_key: "arc:39")

      expect(described_class.affordances_for("arc:39")).to eq(%w[merge])
    end

    it "is empty for a pane with no actions, rather than raising" do
      expect(described_class.affordances_for("arc:nope")).to eq([])
    end
  end

  describe "#composed_preview" do
    it "folds the pane's affordances into an entity's preview" do
      affordance("review", "arc_flow_run_show")
      affordance("approve", "arc_sign_off")

      expect(brief.composed_preview)
        .to include("The brief brf_1", "the pane affords review, approve.")
    end

    it "names the bound action for an affordance node itself" do
      a = affordance("review", "arc_flow_run_show")

      expect(a.composed_preview).to include("it invokes the MCB action arc_flow_run_show")
      expect(a.composed_preview).not_to include("affords")
    end
  end

  describe "#compose_preview!" do
    it "writes the composed sentence" do
      affordance("review", "arc_flow_run_show")
      b = brief

      expect(b.compose_preview!).to be(true)
      expect(b.reload.preview_text).to include("the pane affords review.")
    end

    it "NEVER overwrites what a human decided to say" do
      b = brief(tree_key: "arc:34")
      b.update_column(:preview_text, "The brief that unblocked the coordinator.")

      expect(b.compose_preview!).to be(false)
      expect(b.reload.preview_text).to eq("The brief that unblocked the coordinator.")
    end

    it "overwrites only when asked to" do
      b = brief
      b.update_column(:preview_text, "stale")

      expect(b.compose_preview!(force: true)).to be(true)
      expect(b.reload.preview_text).to include("The brief brf_1")
    end

    it "writes nothing for a node with no referent" do
      n = node(value: "just a label", entity_iri: "")

      expect(n.compose_preview!).to be(false)
      expect(n.reload.preview_text).to be_blank
    end
  end

  describe ".compose_previews!" do
    it "backfills only nodes that stand for something" do
      affordance("review", "arc_flow_run_show")
      brief
      node(value: "decoration", entity_iri: nil)

      expect(described_class.compose_previews!).to eq(2)
      expect(described_class.where.not(preview_text: [nil, ""]).count).to eq(2)
    end

    it "can be scoped to one pane" do
      affordance("review", "arc_flow_run_show")
      brief(tree_key: "arc:39")

      expect(described_class.compose_previews!(tree_key: "arc:39")).to eq(1)
    end

    it "is idempotent -- a second pass writes nothing" do
      affordance("review", "arc_flow_run_show")
      brief
      described_class.compose_previews!

      expect(described_class.compose_previews!).to eq(0)
    end
  end
end
