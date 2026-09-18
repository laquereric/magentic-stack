# frozen_string_literal: true

require_relative "store"
require_relative "refusal"
require_relative "derivation"

module Vv
  module MedallionMemory
    # Append-only bi-temporal Fact (Primitive 2, sharpens M5).
    #
    # Same two axes as the engine's Silver log: valid_* is caller
    # world-time, tx_* is journal-stamped engine time. This is the product
    # face of that log: subject/predicate facts with the four named queries
    # and the cascade wired in -- supersede stales Gold, correct
    # invalidates it. The independence of those two walks is the payoff,
    # and Derivation.cascade is the only walk (no sweeps).
    #
    # Primitive 1: every write names its plane. Agents land on branches
    # (branch_id:); canonical is adopted at merge, never written directly
    # -- a write with neither is canonical_write_refused. The steward key
    # (canonical: true) is the one direct path: steward FRONT land is the
    # human, and agent input must never set it (S1 wires this to
    # HumanReview). Conflict policy lives in Branch, not here.
    #
    # Branch proposals defer the close: a branch supersede/correct writes
    # its successor WITHOUT closing the canonical base row (an unmerged
    # branch must not mutate canonical) and WITHOUT cascading (unmerged
    # text must not invalidate Gold). Merge performs the close, the adopt,
    # and the walk, rebased onto current canonical.
    FactRow = Struct.new(
      :fact_id, :subject_iri, :predicate, :object_value,
      :valid_from, :valid_to, :tx_from, :tx_to,
      :supersedes_fact_id, :corrects_fact_id,
      :evidence_ref, :branch_id, :confidence,
      keyword_init: true
    ) do
      def current? = valid_to.nil? && tx_to.nil?

      def true_on?(date)
        (valid_from.nil? || valid_from <= date) && (valid_to.nil? || date < valid_to)
      end

      def believed_on?(tx)
        (tx_from.nil? || tx_from <= tx) && (tx_to.nil? || tx < tx_to)
      end

      def believed_on_about?(tx, date) = believed_on?(tx) && true_on?(date)
    end

    module Fact
      # M10: evidence-confidence levels. A stamp on the row, never a rank.
      CONFIDENCE_LEVELS = %w[L1 L2 L3].freeze

      module_function

      def default_store
        @default_store ||= Store.new
      end

      def reset!
        @default_store = Store.new
        { ok: true }
      end

      def append(store: default_store, subject_iri:, predicate:, object:,
                 valid_from:, evidence_ref: nil, branch_id: nil, canonical: false,
                 tx_from: nil, tx_to: nil, confidence: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused
        stamp = stamp_confidence(confidence)
        return stamp unless stamp[:ok]
        gate = gate_writer(store: store, branch_id: branch_id, canonical: canonical, op: "append")
        return gate if gate
        return Refusal.build(Refusal::AUDIT_REJECTED, "subject_iri is required") if subject_iri.to_s.empty?
        return Refusal.build(Refusal::AUDIT_REJECTED, "predicate is required") if predicate.to_s.empty?

        admission = store.admit(operation_id: "fact-append:#{store.current_position + 1}")
        row = FactRow.new(
          fact_id: store.next_fact_id,
          subject_iri: subject_iri.to_s, predicate: predicate.to_s,
          object_value: object, valid_from: valid_from,
          tx_from: admission[:journal_position],
          evidence_ref: evidence_ref, branch_id: branch_id&.to_s,
          confidence: stamp[:confidence]
        )
        store.facts << row
        store.mark_merged(row.subject_iri) if branch_id.nil?
        Refusal.ok(fact: to_h(row), tx_from: row.tx_from)
      end

      def supersede(store: default_store, fact_id:, object:, valid_from:,
                    evidence_ref: nil, branch_id: nil, canonical: false,
                    tx_from: nil, tx_to: nil, confidence: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused
        stamp = stamp_confidence(confidence)
        return stamp unless stamp[:ok]
        gate = gate_writer(store: store, branch_id: branch_id, canonical: canonical, op: "supersede")
        return gate if gate

        old = find(store: store, fact_id: fact_id)
        return Refusal.build(Refusal::AUDIT_REJECTED, "no Silver fact #{fact_id.inspect}") if old.nil?
        return Refusal.build(Refusal::AUDIT_REJECTED, "fact #{fact_id} is already belief-closed (corrected away)") unless old.tx_to.nil?

        if branch_id.nil?
          old.valid_to = valid_from
        end
        admission = store.admit(operation_id: "fact-supersede:#{old.fact_id}")
        row = FactRow.new(
          fact_id: store.next_fact_id,
          subject_iri: old.subject_iri, predicate: old.predicate,
          object_value: object, valid_from: valid_from,
          tx_from: admission[:journal_position],
          supersedes_fact_id: old.fact_id,
          evidence_ref: evidence_ref || old.evidence_ref,
          branch_id: branch_id&.to_s,
          confidence: stamp[:confidence]
        )
        store.facts << row
        if branch_id.nil?
          walk = Derivation.cascade(store: store, fact_id: old.fact_id, kind: :supersession)
          store.mark_merged(row.subject_iri)
          return Refusal.ok(fact: to_h(row), superseded: old.fact_id,
                            tx_from: row.tx_from, derivation: walk)
        end
        Refusal.ok(fact: to_h(row), superseded: old.fact_id,
                   tx_from: row.tx_from, deferred: "close-and-walk at merge")
      end

      def correct(store: default_store, fact_id:, object:,
                  evidence_ref: nil, extractor_version: nil,
                  branch_id: nil, canonical: false,
                  tx_from: nil, tx_to: nil, confidence: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused
        stamp = stamp_confidence(confidence)
        return stamp unless stamp[:ok]
        gate = gate_writer(store: store, branch_id: branch_id, canonical: canonical, op: "correct")
        return gate if gate

        old = find(store: store, fact_id: fact_id)
        return Refusal.build(Refusal::AUDIT_REJECTED, "no Silver fact #{fact_id.inspect}") if old.nil?
        return Refusal.build(Refusal::AUDIT_REJECTED, "fact #{fact_id} is already belief-closed") unless old.tx_to.nil?

        admission = store.admit(operation_id: "fact-correct:#{old.fact_id}")
        tx = admission[:journal_position]
        old.tx_to = tx if branch_id.nil?
        row = FactRow.new(
          fact_id: store.next_fact_id,
          subject_iri: old.subject_iri, predicate: old.predicate,
          object_value: object, valid_from: old.valid_from, valid_to: old.valid_to,
          tx_from: tx, corrects_fact_id: old.fact_id,
          evidence_ref: evidence_ref || old.evidence_ref,
          branch_id: branch_id&.to_s,
          confidence: stamp[:confidence]
        )
        store.facts << row
        if branch_id.nil?
          walk = Derivation.cascade(store: store, fact_id: old.fact_id, kind: :correction)
          store.mark_merged(row.subject_iri)
          return Refusal.ok(fact: to_h(row), corrected: old.fact_id,
                            tx_from: row.tx_from, derivation: walk,
                            extractor_flag: extractor_version)
        end
        Refusal.ok(fact: to_h(row), corrected: old.fact_id,
                   tx_from: row.tx_from, deferred: "close-and-walk at merge",
                   extractor_flag: extractor_version)
      end

      def find(store: default_store, fact_id:)
        store.facts.find { |f| f.fact_id == fact_id.to_s }
      end

      # Reads default to canonical (branch_id nil rows). A branch read
      # sees main plus its own -- never another branch's.
      def in_branch(rows, branch_id)
        branch_id.nil? ? rows.select { |f| f.branch_id.nil? } :
          rows.select { |f| f.branch_id.nil? || f.branch_id.to_s == branch_id.to_s }
      end
      private_class_method :in_branch

      # Still true and still believed.
      def current(store: default_store, branch_id: nil) =
        in_branch(store.facts, branch_id).select(&:current?)

      # True on world date d, at current belief.
      def true_on(store: default_store, date:, branch_id: nil) =
        in_branch(store.facts, branch_id).select { |f| f.tx_to.nil? && f.true_on?(date) }

      # Believed at engine position t, whatever the world date.
      def believed_on(store: default_store, tx:, branch_id: nil) =
        in_branch(store.facts, branch_id).select { |f| f.believed_on?(tx) }

      # Believed at t about world date d (audit replay).
      def believed_on_about(store: default_store, tx:, date:, branch_id: nil) =
        in_branch(store.facts, branch_id).select { |f| f.believed_on_about?(tx, date) }

      def to_h(row)
        {
          fact_id: row.fact_id, subject_iri: row.subject_iri,
          predicate: row.predicate, object_value: row.object_value,
          valid_from: row.valid_from, valid_to: row.valid_to,
          tx_from: row.tx_from, tx_to: row.tx_to,
          supersedes_fact_id: row.supersedes_fact_id,
          corrects_fact_id: row.corrects_fact_id,
          evidence_ref: row.evidence_ref, branch_id: row.branch_id,
          confidence: row.confidence
        }.compact
      end

      # M10: nil stamps nothing; L1|L2|L3 (any case) stamps canonical;
      # anything else is refused, never ranked.
      def stamp_confidence(value)
        return Refusal.ok(confidence: nil) if value.nil?

        canonical = value.to_s.strip.upcase
        unless CONFIDENCE_LEVELS.include?(canonical)
          return Refusal.build(
            Refusal::CONFIDENCE_NOT_A_TIER,
            "confidence must be a stamp #{CONFIDENCE_LEVELS.join('|')}, got #{value.inspect}; " \
            "it is never a tier name and never a rank"
          )
        end
        Refusal.ok(confidence: canonical)
      end
      private_class_method :stamp_confidence

      # Every write names its plane: a branch, or the steward key.
      # Returns nil when the write may proceed, a refusal otherwise.
      def gate_writer(store:, branch_id:, canonical:, op:)
        if branch_id.nil?
          unless canonical == true
            return Refusal.build(
              Refusal::CANONICAL_WRITE_REFUSED,
              "Fact.#{op} with no branch_id: agents land on branches, canonical is adopted " \
              "at merge, never written directly. The steward key (canonical: true) is the " \
              "one direct path, and agent input must never set it"
            )
          end
          return nil
        end

        if canonical == true
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "Fact.#{op} names both a branch (#{branch_id}) and the steward key: a write " \
            "lands on one plane, never two"
          )
        end

        branch = Branch.find(store: store, branch_id: branch_id)
        if branch.nil?
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "Fact.#{op} on unknown branch #{branch_id.inspect}: open a branch first, " \
            "or the row would be orphaned"
          )
        end
        unless branch.status == "open"
          return Refusal.build(
            Refusal::AUDIT_REJECTED,
            "Fact.#{op} on branch #{branch_id} which is #{branch.status}: only open " \
            "branches take proposals"
          )
        end

        nil
      end
      private_class_method :gate_writer

      def refuse_client_tx(tx_from:, tx_to:)
        return nil if tx_from.nil? && tx_to.nil?

        Refusal.build(
          Refusal::TX_TIME_CLIENT_SET,
          "tx_from/tx_to are engine-stamped from the journal position, never caller arguments; " \
          "a caller-set tx lets two writers disagree about what was believed when"
        )
      end
      private_class_method :refuse_client_tx
    end
  end
end
