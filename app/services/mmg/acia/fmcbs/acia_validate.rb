# frozen_string_literal: true

module Mmg
  module Acia
    module Fmcbs
      # AciaValidate -- the READ-ONLY MCB action `acia_validate` wrapped as an Fmcb.
      # Validates an ACIA tree (or an explicit triple list) against acia_shapes.ttl via
      # Mmg::Acia::Shapes (vv-graph SHACL Core), returning the CONFORMANCE envelope in the
      # Proposal tree. NON-ENFORCING: it proposes no graph change (triples: []) and never
      # gates McbApply -- the conformance report is the read RESULT, exactly like GemList.
      #
      #   input: { tree_key: "brf_..." }  -> validate a materialized tree
      #   input: { triples: [ "<s> <p> <o> .", ... ] } -> validate a triple list
      #
      # envelope => { ok: true, conforms: <bool>, results: [...] } | { ok: false, reason:, because: }
      class AciaValidate < ::Mmg::Acia::Fmcb
        def compute(input:, surface:)
          triples  = input[:triples] || input["triples"]
          tree_key = (input[:tree_key] || input["tree_key"]).to_s

          result =
            if triples
              ::Mmg::Acia::Shapes.validate(::Kernel.Array(triples))
            elsif !tree_key.empty?
              ::Mmg::Acia::Shapes.validate(tree_key: tree_key)
            else
              { ok: false, reason: :missing_input, because: "provide tree_key or triples" }
            end

          Proposal.new(tree: result, triples: [])
        end

        # The projected ENVELOPE = the conformance report (the delegating handler's return).
        def self.envelope(input:, surface:)
          new.call(input: input, surface: surface).tree
        end
      end
    end
  end
end
