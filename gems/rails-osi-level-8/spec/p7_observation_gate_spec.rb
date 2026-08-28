# frozen_string_literal: true

require "spec_helper"
require "time"
require_relative "../lib/rails_osi_level_8/p7_commands"

# l8.observation.record was the one write on the seam with NO refusal path.
# Observation validates presence of observation_kind, measured_at, observer_iri
# and value_json, and the handler defaulted every one of them -- so the validation
# could never fire and any input was recorded as evidence.
#
# These refusals all happen BEFORE ActiveRecord is reached, which is why they can
# be exercised without a database. A call that gets PAST them fails later on AR,
# and that difference is what the last example asserts.
RSpec.describe RailsOsiLevel8::P7Commands do
  def record(params)
    described_class.observation_record!(params)
  end

  def refusal_for(params)
    record(params)
    nil
  rescue RailsOsiLevel8::KnownRefusal => e
    e
  rescue StandardError
    nil # got past the guards and died at the database
  end

  it "refuses a supplied-but-empty observationKind rather than recording 'metric'" do
    e = refusal_for("observationKind" => "  ", "value" => { "n" => 1 })
    expect(e).not_to be_nil
    expect(e.because["missing"]).to eq("observationKind")
  end

  it "refuses a supplied-but-empty observerIri rather than attributing to mind:backjob" do
    e = refusal_for("observationKind" => "metric", "observerIri" => "", "value" => { "n" => 1 })
    expect(e&.because&.dig("missing")).to eq("observerIri")
  end

  it "refuses an observation with no value -- a measurement of nothing" do
    e = refusal_for("observationKind" => "metric")
    expect(e&.because&.dig("missing")).to eq("value")
  end

  it "refuses a non-object quality rather than silently replacing it with {}" do
    e = refusal_for("observationKind" => "metric", "value" => { "n" => 1 }, "quality" => "high")
    expect(e&.because&.dig("invalid")).to eq("quality")
  end

  it "refuses an unparseable measuredAt instead of raising ArgumentError at the seam" do
    e = refusal_for("observationKind" => "metric", "value" => { "n" => 1 },
                    "measuredAt" => "not-a-time")
    expect(e&.because&.dig("invalid")).to eq("measuredAt")
  end

  # The defaults that REMAIN are the ones a legitimate caller relies on:
  # execution_complete! omits measuredAt on purpose, and the CPCP seam already
  # requires observationKind from external callers.
  it "still admits a well-formed observation that omits measuredAt" do
    expect(refusal_for("observationKind" => "metric", "value" => { "n" => 1 })).to be_nil
  end

  it "still admits the shape execution_complete! sends internally" do
    expect(refusal_for("observationKind" => "execution_complete",
                       "observedSubjectCid" => "cid:sha256:abc",
                       "observerIri" => "mind:backjob",
                       "value" => { "status" => "succeeded" })).to be_nil
  end
end
