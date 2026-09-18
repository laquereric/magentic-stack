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
    # Conflict policy (which successor wins when two writers disagree) is
    # NOT here: that is Branch merge policy, Primitive 1, still pending.
    # These methods take an explicit fact_id target, so there is no
    # last-writer-wins hiding in a helper.
    FactRow = Struct.new(
      :fact_id, :subject_iri, :predicate, :object_value,
      :valid_from, :valid_to, :tx_from, :tx_to,
      :supersedes_fact_id, :corrects_fact_id,
      :evidence_ref, :branch_id,
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
      module_function

      def default_store
        @default_store ||= Store.new
      end

      def reset!
        @default_store = Store.new
        { ok: true }
      end

      def append(store: default_store, subject_iri:, predicate:, object:,
                 valid_from:, evidence_ref: nil, branch_id: nil,
                 tx_from: nil, tx_to: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused
        return Refusal.build(Refusal::AUDIT_REJECTED, "subject_iri is required") if subject_iri.to_s.empty?
        return Refusal.build(Refusal::AUDIT_REJECTED, "predicate is required") if predicate.to_s.empty?

        admission = store.admit(operation_id: "fact-append:#{store.current_position + 1}")
        row = FactRow.new(
          fact_id: store.next_fact_id,
          subject_iri: subject_iri.to_s, predicate: predicate.to_s,
          object_value: object, valid_from: valid_from,
          tx_from: admission[:journal_position],
          evidence_ref: evidence_ref, branch_id: branch_id
        )
        store.facts << row
        Refusal.ok(fact: to_h(row), tx_from: row.tx_from)
      end

      def supersede(store: default_store, fact_id:, object:, valid_from:,
                    evidence_ref: nil, tx_from: nil, tx_to: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused

        old = find(store: store, fact_id: fact_id)
        return Refusal.build(Refusal::AUDIT_REJECTED, "no Silver fact #{fact_id.inspect}") if old.nil?
        return Refusal.build(Refusal::AUDIT_REJECTED, "fact #{fact_id} is already belief-closed (corrected away)") unless old.tx_to.nil?

        old.valid_to = valid_from
        admission = store.admit(operation_id: "fact-supersede:#{old.fact_id}")
        row = FactRow.new(
          fact_id: store.next_fact_id,
          subject_iri: old.subject_iri, predicate: old.predicate,
          object_value: object, valid_from: valid_from,
          tx_from: admission[:journal_position],
          supersedes_fact_id: old.fact_id,
          evidence_ref: evidence_ref || old.evidence_ref,
          branch_id: old.branch_id
        )
        store.facts << row
        walk = Derivation.cascade(store: store, fact_id: old.fact_id, kind: :supersession)
        Refusal.ok(fact: to_h(row), superseded: old.fact_id,
                   tx_from: row.tx_from, derivation: walk)
      end

      def correct(store: default_store, fact_id:, object:,
                  evidence_ref: nil, extractor_version: nil, tx_from: nil, tx_to: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused

        old = find(store: store, fact_id: fact_id)
        return Refusal.build(Refusal::AUDIT_REJECTED, "no Silver fact #{fact_id.inspect}") if old.nil?
        return Refusal.build(Refusal::AUDIT_REJECTED, "fact #{fact_id} is already belief-closed") unless old.tx_to.nil?

        admission = store.admit(operation_id: "fact-correct:#{old.fact_id}")
        tx = admission[:journal_position]
        old.tx_to = tx
        row = FactRow.new(
          fact_id: store.next_fact_id,
          subject_iri: old.subject_iri, predicate: old.predicate,
          object_value: object, valid_from: old.valid_from, valid_to: old.valid_to,
          tx_from: tx, corrects_fact_id: old.fact_id,
          evidence_ref: evidence_ref || old.evidence_ref,
          branch_id: old.branch_id
        )
        store.facts << row
        walk = Derivation.cascade(store: store, fact_id: old.fact_id, kind: :correction)
        Refusal.ok(fact: to_h(row), corrected: old.fact_id,
                   tx_from: row.tx_from, derivation: walk,
                   extractor_flag: extractor_version)
      end

      def find(store: default_store, fact_id:)
        store.facts.find { |f| f.fact_id == fact_id.to_s }
      end

      # Still true and still believed.
      def current(store: default_store) = store.facts.select(&:current?)

      # True on world date d, at current belief.
      def true_on(store: default_store, date:) =
        store.facts.select { |f| f.tx_to.nil? && f.true_on?(date) }

      # Believed at engine position t, whatever the world date.
      def believed_on(store: default_store, tx:) =
        store.facts.select { |f| f.believed_on?(tx) }

      # Believed at t about world date d (audit replay).
      def believed_on_about(store: default_store, tx:, date:) =
        store.facts.select { |f| f.believed_on_about?(tx, date) }

      def to_h(row)
        {
          fact_id: row.fact_id, subject_iri: row.subject_iri,
          predicate: row.predicate, object_value: row.object_value,
          valid_from: row.valid_from, valid_to: row.valid_to,
          tx_from: row.tx_from, tx_to: row.tx_to,
          supersedes_fact_id: row.supersedes_fact_id,
          corrects_fact_id: row.corrects_fact_id,
          evidence_ref: row.evidence_ref, branch_id: row.branch_id
        }.compact
      end

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
