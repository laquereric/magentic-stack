# frozen_string_literal: true

require_relative "trajectory/version"
require_relative "trajectory/step"
require_relative "trajectory/dumb_zone"
require_relative "trajectory/gradient"
require_relative "trajectory/metrics"
require_relative "trajectory/run"
require_relative "trajectory/verdict"

module Vv
  # vv-trajectory -- the path taken toward a slice's aim, recorded and measured.
  #
  # WHERE IT SITS
  #
  #   ░░░░░░░░░░ DUMB CONTEXT ░░░░░░░░░░   attention spent, constraints lost
  #   ══════════ vv-trajectory ═════════   the edge, and the pump across it
  #   ---------- SMART CONTEXT ---------   the frame, the decisions, the record
  #   ---------- vv-frame       --------
  #   ---------- perch (slices) --------   the aim and its receiver
  #
  # Above perch: a slice says what is being built and for whom; a trajectory is
  # the path actually taken toward it, and the evidence about how that went.
  #
  # At the edge of the smart zone: the symptoms of the dumb zone -- looping on
  # the same fix, answering a slightly different question, redoing finished work
  # -- are all visible in a trajectory. Length is a weak proxy for them.
  # Repetition is evidence.
  #
  # AND IT MOVES THE EDGE
  #
  # RaML's result is that a reasoning trajectory is a pseudo-gradient update to
  # the model's parameters: each token is one inner-loop optimisation step, and
  # longer trajectories mean more adaptation. That sits awkwardly beside the
  # smart-zone result, where longer sessions mean worse attention -- until you
  # notice they are about different objects.
  #
  #   The trajectory is the update.   It should be long.
  #   The conversation is the medium. It decays.
  #
  # Separate them and the contradiction goes away: keep the steps, which are
  # observed and durable, and discard the prose, which was never the record.
  # Then a long trajectory raises the fraction of the working context that
  # survives a reset instead of consuming it. That is what moves a development
  # or production session toward more smart context and less dumb context, and
  # `Gradient` is where the movement is measured.
  #
  # The boundary never raises: `{ ok: true, ... }` or
  # `{ ok: false, reason:, because: }`.
  #
  # FIVE REFUSALS, enforced by the absence of a method wherever one will do:
  #
  #   R1  no summarisation. Steps are verbatim. The prose is not the record, so
  #       compacting it loses nothing -- and rewriting a step would lose the
  #       only thing that is.
  #
  #   R2  no judge. Nothing here calls a model. Every metric is computed from
  #       two records and no judgement. A judge's score may be *recorded*, with
  #       its identity and pinned version, and it never stands alone.
  #
  #   R3  the golden set is not the target. `Gold.from_run` refuses: a reference
  #       written from an observed run measures the run against itself.
  #
  #   R4  a single run is not a pass. Reliability over k < 2 refuses rather than
  #       reporting a number that will be read as one.
  #
  #   R5  no fabricated step. Every claimed call is cross-referenced against the
  #       execution log; a claim with no receipt is critical, because everything
  #       after it reasons over invented data.
  module Trajectory
    REFUSED_OPERATIONS = %i[summarize compact condense paraphrase judge].freeze

    # `judge` is refused as an *operation* -- nothing here computes a judgement.
    # Recording one that happened elsewhere is a different act and is permitted,
    # so the three names that do it are named in an allowlist rather than left
    # to a substring match. The refusal is on computing, not on remembering.
    JUDGE_RECORDING_ALLOWED = %i[judge_id judge_version from_judge].freeze

    # The practical edge of the smart zone, as reported rather than measured
    # here, and named as an estimate because that is what it is.
    SMART_ZONE_TOKENS = 100_000
    CHARS_PER_TOKEN = 4

    module_function

    def record(**kwargs) = Run.record(**kwargs)
    def gold(**kwargs) = Gold.author(**kwargs)

    def evaluate(run:, observed_at:, gold: nil)
      Verdict.deterministic(run: run, gold: gold, observed_at: observed_at)
    end

    def reliability(runs) = Reliability.over(runs)
  end
end
