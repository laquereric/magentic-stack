# frozen_string_literal: true

module Vv
  module Frame
    # Where a decision sits on the frame's four axes, and whether that position
    # is legal.
    #
    # The axes are one ordinal three times over: the layer a change lands in,
    # the freeze rung it commits at, and the evidence tier that licenses it all
    # run in the same direction. A placement is legal when they agree.
    class Placement
      # `repo` is boundary doctrine -- the charter, the closed tree, the tier
      # rule. `tooling` is the machinery that serves it: the executable surface,
      # the build wiring, the record corrections. They were one layer once, and
      # the checks below disagreed with themselves because a charter and a
      # bin/ layout do not cost the same to reverse.
      LAYERS      = %w[overlay gems runtimes grammar repo tooling upstreams].freeze
      PHASES      = %w[explore expand extract].freeze
      EVIDENCE    = %w[bronze silver gold].freeze
      INSTRUMENTS = %w[pin rung refusal operate ledger].freeze
      RUNGS       = (0..4).freeze

      # Evidence tier gates rung climb: you may not freeze above what your
      # evidence supports. Rung 0-1 is Bronze work, rung 2 wants Silver, rung
      # 3-4 wants Gold.
      RUNG_REQUIRES = { 0 => "bronze", 1 => "bronze", 2 => "silver", 3 => "gold", 4 => "gold" }.freeze

      # The rung a layer's own work is expected to freeze at.
      LAYER_HOME_RUNG = {
        "overlay" => (0..1), "gems" => (2..3), "runtimes" => (2..3),
        "grammar" => (3..4), "repo" => (3..4), "tooling" => (1..2),
        "upstreams" => (0..4)
      }.freeze

      LAYER_HOME_PHASE = {
        "overlay" => %w[explore expand], "gems" => %w[expand extract],
        "runtimes" => %w[expand extract], "grammar" => %w[extract],
        "repo" => %w[expand extract], "tooling" => %w[expand extract],
        "upstreams" => %w[explore expand extract]
      }.freeze

      attr_reader :layer, :phase, :rung, :evidence, :instrument, :holds_open, :gated

      def initialize(layer:, phase:, rung:, evidence:, instrument:,
                     holds_open: false, gated: false)
        @layer = layer.to_s
        @phase = phase.to_s
        @rung = rung.to_i
        @evidence = evidence.to_s
        @instrument = instrument.to_s
        @holds_open = holds_open == true
        @gated = gated == true
      end

      def self.from(hash, gated: false)
        h = hash || {}
        new(layer: h["layer"], phase: h["phase"], rung: h["freezes_at_rung"],
            evidence: h["evidence"], instrument: h["instrument"],
            holds_open: h["holds_open"], gated: gated)
      end

      # A declared exception: Explore work deliberately held inside a substrate
      # layer, at a rung below that layer's home, by a gate of its own.
      #
      # This is the legal form of the fourth failure mode, and it is the pattern
      # the corpus already uses -- a contract that ships its own refusal until
      # its plants are green. It suppresses the two home findings and nothing
      # else. The evidence rule still applies, because holding a question open
      # is not a licence to freeze on a guess.
      #
      # It is only accepted with a gate. A declaration nothing enforces is the
      # excuse the finding existed to surface, so an ungated `holds_open` is
      # itself a finding.
      def holds_open? = holds_open && gated
      def holds_open_ungated? = holds_open && !gated

      def known?
        LAYERS.include?(layer) && PHASES.include?(phase) && RUNGS.include?(rung) &&
          EVIDENCE.include?(evidence) && INSTRUMENTS.include?(instrument)
      end

      # Position in the closed evidence set, and the position the rung wants.
      # Deliberately not named `rank`: an ordinal in a closed set is a
      # structural fact, and the gem refuses the vocabulary of scoring so that
      # nothing here can quietly start ranking. See Vv::Frame::REFUSED_OPERATIONS.
      def evidence_ordinal = EVIDENCE.index(evidence).to_i
      def required_ordinal = EVIDENCE.index(RUNG_REQUIRES.fetch(rung, "gold")).to_i

      def evidence_supports_rung? = evidence_ordinal >= required_ordinal
      def rung_at_home?  = LAYER_HOME_RUNG.fetch(layer, RUNGS).include?(rung)
      def phase_at_home? = LAYER_HOME_PHASE.fetch(layer, PHASES).include?(phase)

      # Every way this placement disagrees with itself. A list, never a verdict:
      # a finding is something an author acts on, and a boolean is not.
      def findings
        f = []
        f << { test: :axes_known, finding: "an axis value is outside its closed set" } unless known?
        return f unless known?

        unless evidence_supports_rung?
          f << { test: :evidence_gates_rung,
                 finding: "rung #{rung} wants #{RUNG_REQUIRES[rung]} evidence; this holds #{evidence}",
                 suggested_resolution: "gather the evidence, or freeze lower" }
        end
        if holds_open_ungated?
          f << { test: :holds_open_without_a_gate,
                 finding: "holds_open is declared, but no gate holds the question open",
                 suggested_resolution: "name the check in enforced_by, or drop the declaration" }
        end

        return f if holds_open?

        unless rung_at_home?
          f << { test: :rung_at_home,
                 finding: "layer #{layer} freezes at rung #{LAYER_HOME_RUNG[layer]}; this freezes at #{rung}",
                 suggested_resolution: "move the work, not the gate" }
        end
        unless phase_at_home?
          f << { test: :phase_at_home,
                 finding: "layer #{layer} is a #{LAYER_HOME_PHASE[layer].join('/')} layer; this is #{phase} work",
                 suggested_resolution: "move the work, not the gate" }
        end
        f
      end

      def legal? = findings.empty?

      def to_h
        h = { layer: layer, phase: phase, rung: rung, evidence: evidence, instrument: instrument }
        holds_open ? h.merge(holds_open: true) : h
      end
    end
  end
end
