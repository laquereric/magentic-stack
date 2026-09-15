# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "time"

RSpec.describe RailsOsiLevel8::LedgerReport do
  def attempt(op:, direction:, conforms:, reason: nil)
    { "operation_name" => op, "direction" => direction, "conforms" => conforms,
      "refusal_reason" => reason }
  end

  def job(id:, state:, claimed_at: nil, ended_at: nil, due_at: nil, kind: "user",
          element_id: "HumanReview")
    { "id" => id, "kind" => kind, "state" => state, "claimed_at" => claimed_at,
      "ended_at" => ended_at, "due_at" => due_at, "element_id" => element_id }
  end

  let(:now) { Time.utc(2026, 9, 15, 12, 0, 0) }
  let(:started) { "2026-09-15T11:00:00Z" }

  def report(**opts)
    described_class.call(
      now: now,
      admission_attempts: [],
      jobs: [],
      ui_actions: [],
      calls: [],
      writer_started_at: started,
      **opts
    )
  end

  it "names the blob by the digest of the report" do
    Dir.mktmpdir do |dir|
      out = report(dir: dir)
      expect(out[:ok]).to be true
      expect(out[:digest]).to match(/\Asha256:[0-9a-f]{64}\z/)
      expect(File.basename(out[:path])).to eq("#{out[:digest]}.json")
      disk = JSON.parse(File.read(out[:path]))
      expect(disk["digest"]).to eq(out[:digest])
    end
  end

  it "computes latency_human from claimed_at to ended_at on completed HumanReview" do
    out = report(jobs: [
      job(id: 1, state: "completed",
          claimed_at: "2026-09-15T11:00:00Z", ended_at: "2026-09-15T11:00:30Z"),
      job(id: 2, state: "claimed", claimed_at: "2026-09-15T11:00:00Z")
    ])
    expect(out[:report]["latency_human"]["n"]).to eq(1)
    expect(out[:report]["latency_human"]["seconds"]).to eq([30.0])
  end

  it "reports open_past_due as an operator definition, never as expired" do
    out = report(jobs: [
      job(id: 1, state: "open", due_at: "2026-09-15T10:00:00Z"),
      job(id: 2, state: "claimed", due_at: "2026-09-15T13:00:00Z"),
      job(id: 3, state: "completed", due_at: "2026-09-15T10:00:00Z",
          claimed_at: "2026-09-15T09:00:00Z", ended_at: "2026-09-15T09:30:00Z")
    ])
    past = out[:report]["open_past_due"]
    expect(past["n"]).to eq(1)
    expect(past["open_or_claimed"]).to eq(2)
    expect(past["share"]).to eq(0.5)
    expect(past["definition"]).to match(/engine does not expire/)
    expect(JSON.generate(out[:report])).not_to match(/"expired"/)
  end

  it "computes refusal_rate PUSH-only per operation_name and refusal_reason" do
    out = report(admission_attempts: [
      attempt(op: "acia.publish", direction: "push", conforms: false, reason: "grounding_refused"),
      attempt(op: "acia.publish", direction: "push", conforms: true),
      attempt(op: "acia.publish", direction: "push", conforms: true),
      attempt(op: "note.list", direction: "pull", conforms: false, reason: "grounding_refused")
    ])
    rows = out[:report]["refusal_rate"]["rows"]
    expect(rows.map { |r| r["direction"] }.uniq).to eq(["push"])
    pub = rows.find { |r| r["operation_name"] == "acia.publish" }
    expect(pub["attempts"]).to eq(3)
    expect(pub["refused"]).to eq(1)
    expect(pub["rate"]).to be_within(0.01).of(1.0 / 3)
    expect(rows.map { |r| r["operation_name"] }).not_to include("note.list")
    expect(out[:report]).not_to have_key("refusal_rate_overall")
    expect(out[:report]["refusal_rate"]).not_to be_a(Numeric)
  end

  it "keeps reversal_rate absent, never 0" do
    out = report
    rev = out[:report]["reversal_rate"]
    expect(rev["status"]).to eq("absent")
    expect(rev["value"]).to be_nil
    expect(rev).not_to eq(0)
    expect(JSON.generate(out[:report])).not_to match(/"reversal_rate":\s*0/)
  end

  it "names scope as not pod-wide" do
    out = report
    expect(out[:report]["scope"]["coverage"]).to match(/not pod-wide/)
    expect(out[:report]["scope"]["methods"]).to match(/Dispatcher/)
  end

  it "announces the R4 writer start and will not backfill" do
    out = report(
      calls: [
        { "kind" => "call", "method" => "note.list", "direction" => "pull",
          "at" => "2026-09-15T11:30:00Z", "replayed" => false },
        { "kind" => "call", "method" => "note.create", "direction" => "push",
          "at" => "2026-09-15T11:31:00Z", "replayed" => false },
        { "kind" => "call", "method" => "note.create", "direction" => "push",
          "at" => "2026-09-15T11:32:00Z", "replayed" => true }
      ]
    )
    ratio = out[:report]["pull_push_ratio"]
    expect(ratio["status"]).to eq("ok")
    expect(ratio["writer_started_at"]).to eq(started)
    expect(ratio["pull"]).to eq(1)
    expect(ratio["push"]).to eq(2)
    expect(ratio["push_replay"]).to eq(1)
    expect(ratio["methods"]).to include("note.list", "note.create")
    expect(Time.parse(ratio.dig("window", "from"))).to be >= Time.parse(started)
  end

  it "treats a missing call writer as absent, not zero PULL share" do
    out = report(writer_started_at: nil, calls: [])
    expect(out[:report]["pull_push_ratio"]["status"]).to eq("absent")
    expect(out[:report]["pull_push_ratio"]["value"]).to be_nil
  end

  it "pairs catalog accept with job.claimed_at when jobId is present" do
    claimed = "2026-09-15T11:00:00Z"
    acted = "2026-09-15T11:00:12Z"
    out = report(
      jobs: [job(id: 7, state: "claimed", claimed_at: claimed)],
      ui_actions: [{
        "action" => "accept", "at" => acted, "taskKind" => "task.approval",
        "job" => { "jobId" => "7" }
      }]
    )
    cat = out[:report]["latency_catalog"]
    expect(cat["status"]).to eq("process_lifetime")
    expect(cat["durable"]).to be false
    expect(cat["n_with_at"]).to eq(1)
    expect(cat["durations_seconds"]).to eq([12.0])
  end

  describe "plants (zero jobs is a fail)" do
    it "refuses reversal_rate printed as 0" do
      lying = report[:report].merge("reversal_rate" => 0)
      expect(described_class.honest(lying)).to include(ok: false, reason: "absent_rendered_as_zero")
    end

    it "refuses a PULL-skewed refusal denominator" do
      lying = report[:report].merge(
        "refusal_rate" => { "rows" => [{ "operation_name" => "note.list", "direction" => "pull",
                                         "refused" => 1, "attempts" => 1, "rate" => 1.0 }] }
      )
      expect(described_class.honest(lying)).to include(ok: false, reason: "push_only_denominator")
    end

    it "refuses a pod-wide refusal percentage" do
      lying = report[:report].merge("refusal_rate" => 0.12)
      expect(described_class.honest(lying)).to include(ok: false, reason: "rollup_forbidden")
    end

    it "refuses a report that implies pod-wide coverage" do
      lying = report[:report].merge("scope" => { "coverage" => "the whole pod" })
      expect(described_class.honest(lying)).to include(ok: false, reason: "scope_unnamed")
    end

    it "refuses a ratio whose window starts before the writer" do
      lying = report[:report].merge(
        "pull_push_ratio" => {
          "status" => "ok",
          "writer_started_at" => "2026-09-15T11:00:00Z",
          "window" => { "from" => "2026-01-01T00:00:00Z", "to" => "2026-09-15T12:00:00Z" },
          "pull" => 1, "push" => 1
        }
      )
      expect(described_class.honest(lying)).to include(ok: false, reason: "fabricated_history")
    end

    it "does not add expired to JOB_STATES while the engine ignores due_at" do
      src = File.read(File.expand_path("../../vv-bpmn-bbo/lib/vv/bpmn_bbo/run.rb", __dir__))
      expect(src).to include('JOB_STATES = %w[open claimed completed failed cancelled]')
      expect(src).not_to match(/JOB_STATES = %w\[[^\]]*expired/)
      engine = File.read(File.expand_path("../../vv-sdlc/lib/vv/sdlc/engine.rb", __dir__))
      code = engine.lines.grep_v(/^\s*#/).join
      expect(code).not_to match(/\bdue_at\b/)
    end

    it "does not add a reporting EVENT_KINDS entry" do
      src = File.read(File.expand_path("../lib/rails_osi_level_8/models/operation_journal_entry.rb", __dir__))
      expect(src).to include("received grounded authorized refused response_refused routed dispatched completed")
      expect(src).not_to match(/undone|reversed/)
    end

    it "does not journal a successful PULL as an OperationRequest" do
      src = File.read(File.expand_path("../lib/rails_osi_level_8/cpcp_adapter.rb", __dir__))
      pull = src[/def pull!.*?\n    end/m]
      expect(pull).not_to be_nil
      expect(pull).not_to match(/create_operation_request|append_journal/)
    end
  end
end
