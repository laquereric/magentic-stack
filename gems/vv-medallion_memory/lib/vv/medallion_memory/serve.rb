# frozen_string_literal: true

require_relative "assemble"
require_relative "activations_port"
require_relative "refusal"

module Vv
  module MedallionMemory
    # Serve: Assemble, then MeaningActivations partition (Primitive 3).
    #
    #   Serve.call(store:, cue:, seeds:, node_budget:, token_ceiling:,
    #              as_of_tx: nil, branch_id: nil, vector: nil,
    #              weights: {}, activations: nil)
    #
    # as_of_tx defaults to the current journal position here (ordinary
    # serve); audit replays name it. The assembled pack is partitioned by
    # activation weight, assemble order preserved inside each bucket:
    #   injected    weight > 0 (the only thing a turn may consume)
    #   inspectable weight <= 0 (suppressed, still visible -- a 0-weight
    #               activation remains inspectable, it is just not injected;
    #               negative weights land here too)
    #   unmodeled   nil (absent is not zero: never scored, tracked apart
    #               rather than conflated with considered-and-rejected)
    module Serve
      module_function

      def call(store:, cue: nil, seeds: [], node_budget:, token_ceiling:,
               as_of_tx: nil, branch_id: nil, vector: nil,
               weights: {}, activations: nil)
        tx = as_of_tx.nil? ? store.current_position : as_of_tx
        asm = Assemble.call(
          store: store, cue: cue, seeds: seeds, node_budget: node_budget,
          token_ceiling: token_ceiling, as_of_tx: tx,
          branch_id: branch_id, vector: vector, weights: weights
        )
        return asm unless asm[:ok]

        port = activations || NullActivations.new
        injected = []
        inspectable = []
        unmodeled = []
        asm[:subjects].each do |s|
          w = port.weight_for(s[:subject_iri])
          if w.nil?
            unmodeled << s
          elsif w > 0
            injected << s.merge(weight: w)
          else
            inspectable << s.merge(weight: w)
          end
        end

        Refusal.ok(
          injected: injected, inspectable: inspectable, unmodeled: unmodeled,
          tokens: asm[:tokens], truncated: asm[:truncated], as_of_tx: tx
        )
      end
    end
  end
end
