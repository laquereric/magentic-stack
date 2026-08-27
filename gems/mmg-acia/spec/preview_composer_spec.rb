# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mmg::Acia::PreviewComposer do
  def entity(**over)
    described_class.compose(**{
      kind: "entity_token", semantic_role: "brief",
      entity_iri: "urn:mm:brief:brf_2026-07-11_47802b21",
      value: "brf_2026-07-11_47802b21", tree_key: "arc:34",
      affords: %w[review approve decline]
    }.merge(over))
  end

  def action(**over)
    described_class.compose(**{
      kind: "action", semantic_role: "mcb_action",
      entity_iri: "urn:mm:action:arc_flow_run_show",
      value: "review", tree_key: "arc:34", affords: []
    }.merge(over))
  end

  describe "an entity a model has not dereferenced" do
    it "names the thing, its noun, and where it is shown" do
      expect(entity).to include("The brief brf_2026-07-11_47802b21",
                                "shown on the arc:34 pane")
    end

    it "gives the IRI to dereference, so the preview stays a REFERENCE" do
      expect(entity).to include("Dereference urn:mm:brief:brf_2026-07-11_47802b21")
    end

    it "names what may be DONE with it -- the affordances" do
      expect(entity).to include("the pane affords review, approve, decline")
    end

    it "says nothing about affordances when the pane offers none" do
      text = entity(affords: [])
      expect(text).to end_with("for the record itself.")
      expect(text).not_to include("affords")
    end

    it "de-duplicates and drops blanks rather than emitting a ragged list" do
      expect(entity(affords: ["review", "", "review", nil, "approve"]))
        .to include("affords review, approve.")
    end

    it "carries a repo's label, which holds live state the IRI does not" do
      text = entity(semantic_role: "repo", entity_iri: "urn:mm:repo:8451ba8a14d7",
                    value: "super -- dirty (ahead 1/behind 0)")
      expect(text).to include("The repository 8451ba8a14d7",
                              "(super -- dirty (ahead 1/behind 0))")
    end

    it "does not treat a non-repo value as live state" do
      expect(entity).not_to include("(brf_2026-07-11_47802b21)")
    end

    it "falls back to the raw role rather than inventing a noun" do
      expect(entity(semantic_role: "epic", entity_iri: "urn:mm:epic:88"))
        .to start_with("The epic 88,")
    end
  end

  describe "an affordance node -- it IS the thing that may be done" do
    it "names the label and the MCB action it invokes" do
      expect(action).to include(%(The "review" affordance on the arc:34 pane),
                               "it invokes the MCB action arc_flow_run_show")
    end

    it "describes the effect when the action registry describes it" do
      expect(action).to include("which reads an arc-flow run", "read-only")
    end

    it "REFUSES to characterize an effect the registry does not describe" do
      text = action(value: "approve", entity_iri: "urn:mm:action:arc_sign_off")
      expect(text).to include("it invokes the MCB action arc_sign_off")
      expect(text).to include("Its effect is not described in the action registry.")
    end

    it "does not list the pane's affordances -- it is one of them" do
      expect(action(affords: %w[review approve decline])).not_to include("affords")
    end
  end

  describe "saying nothing" do
    it "returns nil without a referent, because a preview needs something to preview" do
      expect(entity(entity_iri: "")).to be_nil
      expect(entity(entity_iri: nil)).to be_nil
    end
  end
end
