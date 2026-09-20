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
    #
    # Primitive 1 adds the branch plane: branches, proposals, merge
    # records, per-writer merge/reject stats (the poisoning detector),
    # the merged-subject set (the VectorPort merge gate reads this), and
    # the sensitivity list (subjects whose changes always need review).
    # Facts carry branch_id (nil = canonical); reads default to canonical
    # unless a branch is named.
    class Store
      attr_reader :facts, :derivations, :journal_position,
                  :branches, :proposals, :merge_records,
                  :agent_stats, :merged_subjects, :sensitive_subjects

      def initialize
        @facts = []
        @derivations = []
        @journal_position = 0
        @fact_seq = 0
        @branches = []
        @proposals = []
        @merge_records = []
        @agent_stats = Hash.new { |h, k| h[k] = { merged: 0, rejected: 0 } }
        @merged_subjects = {}
        @sensitive_subjects = []
        @branch_seq = 0
        @proposal_seq = 0
        @merge_seq = 0
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

      def next_branch_id
        @branch_seq += 1
        "br_#{@branch_seq}"
      end

      def next_proposal_id
        @proposal_seq += 1
        "prop_#{@proposal_seq}"
      end

      def next_merge_id
        @merge_seq += 1
        "merge_#{@merge_seq}"
      end

      def mark_merged(subject_iri)
        @merged_subjects[subject_iri.to_s] = current_position
      end

      def merged?(subject_iri) = @merged_subjects.key?(subject_iri.to_s)

      def record_merge(agent_id)
        @agent_stats[agent_id.to_s][:merged] += 1
      end

      def record_reject(agent_id)
        @agent_stats[agent_id.to_s][:rejected] += 1
      end

      def rejection_rate(agent_id)
        s = @agent_stats[agent_id.to_s]
        total = s[:merged] + s[:rejected]
        return 0.0 if total.zero?

        s[:rejected].to_f / total
      end

      def decisions(agent_id)
        s = @agent_stats[agent_id.to_s]
        s[:merged] + s[:rejected]
      end

      def clear!
        @facts.clear
        @derivations.clear
        @journal_position = 0
        @fact_seq = 0
        @branches.clear
        @proposals.clear
        @merge_records.clear
        @agent_stats.clear
        @merged_subjects.clear
        @sensitive_subjects.clear
        @branch_seq = 0
        @proposal_seq = 0
        @merge_seq = 0
        { ok: true }
      end
    end
  end
end
