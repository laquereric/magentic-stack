# frozen_string_literal: true

module RailsOsiLevel8
  # Demo fixture narrative for Milestone 8 — seeds a visible refusal/replay/auth/learn path
  # without inventing a second API.
  module Fixtures
    module_function

    def seed_demo_narrative!
      Learning.record!(
        "learningCycleId" => "cycle:demo",
        "eventKind" => "drift_detected",
        "baselineRef" => "shape:p1@1",
        "observedRef" => "shape:p1@1+closed",
        "severity" => "low",
        "status" => "open",
        "subjectCid" => "mind:pod",
        "evidenceCids" => [],
        "decidedByIri" => "cyborg:operator"
      )
      Learning.record!(
        "learningCycleId" => "cycle:demo",
        "eventKind" => "hypothesis_recorded",
        "status" => "open",
        "subjectCid" => "mind:pod",
        "proposal" => { "hypothesis" => "closed shapes catch empty titles" },
        "decidedByIri" => "cyborg:operator"
      )
      Learning.record!(
        "learningCycleId" => "cycle:demo",
        "eventKind" => "profile_change_proposed",
        "status" => "open",
        "subjectCid" => "mind:pod",
        "proposal" => { "change" => "tighten P1 title MinCount" },
        "decidedByIri" => "cyborg:operator"
      )
      Learning.record!(
        "learningCycleId" => "cycle:demo",
        "eventKind" => "profile_change_accepted",
        "status" => "accepted",
        "subjectCid" => "mind:pod",
        "proposal" => { "change" => "tighten P1 title MinCount" },
        "decidedByIri" => "cyborg:operator"
      )
      true
    end
  end
end
