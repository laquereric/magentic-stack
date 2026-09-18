# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

require "securerandom"
require_relative "result"

module Mmg
  module Medallion
    # A Silver fact: one append-only row on two independent time axes (M5).
    #
    # valid_from / valid_to is WORLD time (when the statement was true).
    # valid_to nil means still true.
    #
    # tx_from / tx_to is ENGINE time (when this row was believed, as a journal
    # position or monotonic commit id). tx_to nil means still believed.
    #
    # The axes are independent on purpose: a supersession closes the world
    # interval (the old statement stopped being true; Gold goes STALE), while
    # a correction closes the belief interval (the old statement was never
    # true; Gold is INVALIDATED). One cascade path for both would make the
    # derivation index unable to tell them apart.
    #
    # Rows are never UPDATED. Close writes a successor. valid_* is caller
    # time (ISO8601 or any mutually comparable); tx_* is engine-stamped and
    # a caller that passes it is refused tx_time_client_set.
    class Fact
      attr_reader :fact_id, :subject_iri, :predicate, :object_value,
                  :valid_from, :valid_to, :tx_from, :tx_to,
                  :supersedes_fact_id, :corrects_fact_id,
                  :evidence_ref, :extractor_version

      def initialize(fact_id:, subject_iri:, predicate:, object_value:,
                     valid_from:, tx_from:, valid_to: nil, tx_to: nil,
                     supersedes_fact_id: nil, corrects_fact_id: nil,
                     evidence_ref: nil, extractor_version: nil)
        @fact_id = fact_id
        @subject_iri = subject_iri
        @predicate = predicate
        @object_value = object_value
        @valid_from = valid_from
        @valid_to = valid_to
        @tx_from = tx_from
        @tx_to = tx_to
        @supersedes_fact_id = supersedes_fact_id
        @corrects_fact_id = corrects_fact_id
        @evidence_ref = evidence_ref
        @extractor_version = extractor_version
      end

      def current? = valid_to.nil? && tx_to.nil?

      def true_on?(date)
        (valid_from.nil? || valid_from <= date) && (valid_to.nil? || date < valid_to)
      end

      def believed_on?(tx)
        (tx_from.nil? || tx_from <= tx) && (tx_to.nil? || tx < tx_to)
      end

      def believed_on_about?(tx, date) = believed_on?(tx) && true_on?(date)

      def to_h
        {
          fact_id: fact_id, subject_iri: subject_iri, predicate: predicate,
          object_value: object_value, valid_from: valid_from, valid_to: valid_to,
          tx_from: tx_from, tx_to: tx_to,
          supersedes_fact_id: supersedes_fact_id, corrects_fact_id: corrects_fact_id,
          evidence_ref: evidence_ref, extractor_version: extractor_version
        }.compact
      end
    end

    # Append-and-close Silver log (M5 data plane). In-memory; the journal
    # position analog is a monotonic integer. A later real journal must keep
    # that type stable (integer position, not wall-clock).
    class FactStore
      attr_reader :facts

      def initialize
        @facts = []
        @tx = 0
        @seq = 0
      end

      def current_tx = @tx

      # The engine clock. admit is the only writer of tx_from / tx_to.
      def admit
        @tx += 1
      end

      def find(fact_id) = @facts.find { |f| f.fact_id == fact_id.to_s }

      def append(subject_iri:, predicate:, object:, valid_from:,
                 evidence_ref: nil, extractor_version: nil, tx_from: nil, tx_to: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused

        return Result.failure(:audit_rejected, "subject_iri is required") if subject_iri.to_s.empty?
        return Result.failure(:audit_rejected, "predicate is required") if predicate.to_s.empty?

        fact = Fact.new(
          fact_id: "fact_#{(@seq += 1)}",
          subject_iri: subject_iri.to_s, predicate: predicate.to_s,
          object_value: object, valid_from: valid_from, tx_from: admit,
          evidence_ref: evidence_ref, extractor_version: extractor_version
        )
        @facts << fact
        Result.success(fact: fact.to_h, tx_from: fact.tx_from)
      end

      # World changed: the old row stopped being true at valid_from. Its
      # belief interval stays open (it WAS true until then). Gold goes STALE.
      def supersede(fact_id:, object:, valid_from:, evidence_ref: nil, tx_from: nil, tx_to: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused

        old = find(fact_id)
        return Result.failure(:audit_rejected, "no Silver fact #{fact_id.inspect}") if old.nil?
        return Result.failure(:audit_rejected, "fact #{fact_id} is already belief-closed (corrected away)") unless old.tx_to.nil?

        old.instance_variable_set(:@valid_to, valid_from)
        fact = Fact.new(
          fact_id: "fact_#{(@seq += 1)}",
          subject_iri: old.subject_iri, predicate: old.predicate,
          object_value: object, valid_from: valid_from, tx_from: admit,
          supersedes_fact_id: old.fact_id,
          evidence_ref: evidence_ref || old.evidence_ref,
          extractor_version: old.extractor_version
        )
        @facts << fact
        Result.success(fact: fact.to_h, superseded: old.fact_id, tx_from: fact.tx_from)
      end

      # Belief changed: the old row was never true. Its world interval is
      # left as written (history of what was believed); belief closes now.
      # Gold is INVALIDATED.
      def correct(fact_id:, object:, evidence_ref: nil, extractor_version: nil, tx_from: nil, tx_to: nil)
        refused = refuse_client_tx(tx_from: tx_from, tx_to: tx_to)
        return refused if refused

        old = find(fact_id)
        return Result.failure(:audit_rejected, "no Silver fact #{fact_id.inspect}") if old.nil?
        return Result.failure(:audit_rejected, "fact #{fact_id} is already belief-closed") unless old.tx_to.nil?

        tx = admit
        old.instance_variable_set(:@tx_to, tx)
        fact = Fact.new(
          fact_id: "fact_#{(@seq += 1)}",
          subject_iri: old.subject_iri, predicate: old.predicate,
          object_value: object, valid_from: old.valid_from, valid_to: old.valid_to,
          tx_from: tx, corrects_fact_id: old.fact_id,
          evidence_ref: evidence_ref || old.evidence_ref,
          extractor_version: extractor_version || old.extractor_version
        )
        @facts << fact
        Result.success(fact: fact.to_h, corrected: old.fact_id, tx_from: fact.tx_from)
      end

      # Four queries, named as methods not comments.

      # Still true and still believed.
      def current = @facts.select(&:current?)

      # True on world date d, at current belief.
      def true_on(date) = @facts.select { |f| f.tx_to.nil? && f.true_on?(date) }

      # Believed at engine position t, whatever the world date.
      def believed_on(tx) = @facts.select { |f| f.believed_on?(tx) }

      # Believed at t about world date d (audit replay).
      def believed_on_about(tx, date) = @facts.select { |f| f.believed_on_about?(tx, date) }

      def clear!
        @facts.clear
        @tx = 0
        @seq = 0
        { ok: true }
      end

      private

      def refuse_client_tx(tx_from:, tx_to:)
        return nil if tx_from.nil? && tx_to.nil?

        Result.failure(
          :tx_time_client_set,
          "tx_from/tx_to are engine-stamped from the journal position, never caller arguments; " \
          "a caller-set tx lets two writers disagree about what was believed when"
        )
      end
    end
  end
end
