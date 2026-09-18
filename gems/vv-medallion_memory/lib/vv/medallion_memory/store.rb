# frozen_string_literal: true

module Vv
  module MedallionMemory
    # In-memory Store the M5/M9 specs run against (Primitive 2 + 4 home).
    #
    # This is the MEMORY product's working store, not a second engine: no
    # Conformer, no Curator, no projection here (the checker asserts that).
    # Persistence behind ports is follow-on; what matters in this slice is
    # that Fact append-and-close and the Derivation walk are STRUCTURAL --
    # real rows, real queries -- not types with comments.
    #
    # Journal admits: admit returns a monotonic integer position and that
    # position is the only writer of tx_from / tx_to. A write that never
    # journals is not landed.
    class Store
      attr_reader :facts, :derivations, :journal_position

      def initialize
        @facts = []
        @derivations = []
        @journal_position = 0
        @fact_seq = 0
      end

      def admit(operation_id:, payload: nil)
        @journal_position += 1
        { ok: true, operation_id: operation_id, journal_position: @journal_position }
      end

      def current_position = @journal_position

      def next_fact_id
        @fact_seq += 1
        "fact_#{@fact_seq}"
      end

      def clear!
        @facts.clear
        @derivations.clear
        @journal_position = 0
        @fact_seq = 0
        { ok: true }
      end
    end
  end
end
