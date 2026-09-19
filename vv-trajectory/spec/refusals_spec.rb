# frozen_string_literal: true

require "spec_helper"

RSpec.describe "the refusals" do
  CLASSES = [Vv::Trajectory, Vv::Trajectory::Run, Vv::Trajectory::Gold,
             Vv::Trajectory::GoldStep, Vv::Trajectory::Step,
             Vv::Trajectory::Gradient, Vv::Trajectory::Verdict,
             Vv::Trajectory::Metrics, Vv::Trajectory::DumbZone,
             Vv::Trajectory::Reliability].freeze

  describe "R1 — no summarisation" do
    it "no object and no def answers to a summarising name" do
      allowed = T::JUDGE_RECORDING_ALLOWED.map(&:to_s)
      refused = lambda { |name|
        !allowed.include?(name.to_s) &&
          T::REFUSED_OPERATIONS.any? { |r| name.to_s.include?(r.to_s) }
      }
      offenders = CLASSES.flat_map do |k|
        (k.instance_methods(false) + k.methods(false)).select(&refused).map { |m| "#{k}##{m}" }
      end
      src = Dir[File.expand_path("../lib/**/*.rb", __dir__)].map { |f| File.read(f) }.join("\n")
      defs = src.scan(/^\s*def\s+(?:self\.)?(\w+)/).flatten.select(&refused)
      expect(offenders + defs).to be_empty
    end

    it "a step's text is kept as given" do
      said = "  I should   check for nil  "
      run = T.record(key: "k", aim: Runs::AIM,
                     steps: [{ tool: "read_file", args: {}, reasoning: said,
                               receipt: { tool: "read_file" } }]).fetch(:run)
      expect(run.steps.first.reasoning).to eq(said)
    end
  end

  describe "R2 — no judge" do
    it "the allowlist covers recording a judgement and nothing more" do
      expect(T::JUDGE_RECORDING_ALLOWED).to eq(%i[judge_id judge_version from_judge])
      expect(T::JUDGE_RECORDING_ALLOWED).not_to include(:judge, :score_with_judge)
    end

    it "calls no model: nothing in lib reaches the network" do
      src = Dir[File.expand_path("../lib/**/*.rb", __dir__)].map { |f| File.read(f) }.join("\n")
      expect(src).not_to match(/Net::HTTP|require ["']net\/http|open-uri|URI\.open|Faraday/)
    end

    it "a deterministic verdict may stand alone" do
      v = T.evaluate(run: Runs.clean, gold: Runs.gold, observed_at: "2026-09-19").fetch(:verdict)
      expect(v).to be_deterministic
      expect(v).to be_standalone
    end

    it "a judge's verdict never stands alone, whatever its confidence" do
      v = Vv::Trajectory::Verdict.from_judge(
        run_key: "r", score: 5, judge_id: "big-model", judge_version: "2026-09-01",
        observed_at: "2026-09-19", confidence: 0.99
      ).fetch(:verdict)
      expect(v).not_to be_standalone
      expect(v.to_h).to include(judge_version: "2026-09-01")
    end

    it "PLANT: an unpinned judge is refused" do
      res = Vv::Trajectory::Verdict.from_judge(
        run_key: "r", score: 5, judge_id: "big-model", judge_version: "",
        observed_at: "2026-09-19"
      )
      expect(res).to include(ok: false, reason: :judge_version_unpinned)
    end

    it "no verdict carries a field that could close a slice" do
      v = T.evaluate(run: Runs.clean, observed_at: "2026-09-19").fetch(:verdict)
      expect(v.to_h.keys).not_to include(:pass, :passed, :promote, :released, :done)
      expect(v).not_to respond_to(:promote)
    end
  end

  describe "R3 — the golden set is not the target" do
    it "PLANT: authoring a reference from an observed run is refused" do
      res = Vv::Trajectory::Gold.from_run(Runs.lucky)
      expect(res).to include(ok: false, reason: :golden_set_is_not_the_target)
      expect(res[:because]).to include("against itself")
    end

    it "a gold trajectory is frozen once authored" do
      expect(Runs.gold).to be_frozen
    end
  end

  describe "R4 — a single run is not a pass" do
    it "PLANT: reliability over one run is refused rather than reported" do
      expect(T.reliability([Runs.clean]))
        .to include(ok: false, reason: :single_run_is_not_a_pass)
    end

    it "reports pass^k apart from pass@k, because they disagree" do
      runs = [Runs.clean, Runs.clean, Runs.lucky,
              T.record(key: "f", aim: Runs::AIM, reached_aim: false,
                       steps: [{ tool: "read_file", args: {}, receipt: { tool: "read_file" } }]).fetch(:run)]
      r = T.reliability(runs)
      expect(r[:per_trial]).to eq(0.75)
      expect(r[:pass_at_k]).to be(true)
      expect(r[:pass_pow_k]).to be(false)
    end
  end

  describe "boundary" do
    it "refuses a run with no aim" do
      expect(T.record(key: "k", aim: "  ", steps: []))
        .to include(ok: false, reason: :aim_absent)
    end
  end
end
