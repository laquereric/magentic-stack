# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "time"
require "vv-decision-object"

module DecisionHelpers
  DO = Vv::DecisionObject

  # A frozen clock so traces are byte-stable in specs.
  def fixed_clock(start = "2026-09-20T12:00:00Z")
    ticks = 0
    -> { (Time.parse(start) + (ticks += 1)).utc.iso8601 }
  end

  def route_question
    DO::Choice.new(
      :route,
      instructions: "Which handler should process `request`?",
      criteria: {
        deterministic_code: "A fixed lookup, rule or calculation is sufficient",
        fast_llm: "Short language generation with limited reasoning",
        reasoning_llm: "Multi-step interpretation or synthesis is required",
        human_review: "Ambiguous, sensitive, or outside the declared routes"
      }
    )
  end

  def severity_question
    DO::Score.new(
      :severity,
      instructions: "How severe is the reported defect?",
      rubric: {
        low: "Cosmetic",
        medium: "Degraded but usable",
        high: "Blocked workflow",
        critical: "Data loss or outage"
      }
    )
  end

  def refund_question
    DO::Noul.new(:refund_requested, instructions: "Does `body` request a refund?")
  end

  # A complete six-layer definition used across the specs.
  def triage_definition(version: 1)
    result = DO.define(:route_ticket, version: version) do |d|
      d.intent "Route the ticket to the handler that can close it",
               tradeoffs: ["speed over precision below $500 exposure"],
               owner: "support-platform"
      d.constraint(:no_pii_to_vendor, because: "DPA forbids vendor PII") { |s| !s[:contains_pii] }
      d.signal :subject, :body, :tier, :contains_pii
      d.ask route_question
      d.ask refund_question
      d.thresholds floors: { route: 0.80, refund_requested: 0.0 },
                   option_floors: { route: { deterministic_code: 0.90, human_review: 0.0 } }
      d.commit_to :assign_handler
      d.track :resolved, :reopened
    end
    result[:data]
  end

  def clean_state(pii: false)
    { subject: "Charged twice", body: "Please refund me", tier: "premium", contains_pii: pii }
  end

  def confident_adapter(route: "fast_llm", confidence: 0.94, refund: 0.97)
    DO::Adapters::Static.new(
      route: { value: route, confidence: confidence,
               probabilities: { route => confidence, "human_review" => (1 - confidence).round(4) } },
      refund_requested: { value: refund, confidence: 0.9 }
    )
  end
end

RSpec.configure do |c|
  c.disable_monkey_patching!
  c.order = :random
  c.include DecisionHelpers
end
