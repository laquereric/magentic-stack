# frozen_string_literal: true

module Mmg
  module Adr
    # THE ROW THAT MAKES A DECISION QUERYABLE.
    #
    # An ADR file is prose an agent reads. That is necessary and not sufficient:
    # prose cannot answer "which accepted decisions govern gems/mmg-graph", or
    # "which of them names no enforcing test", and a question with no answer is a
    # question nobody asks. The row exists to make the ledger queryable; the file
    # remains the thing a human and a model read.
    #
    # The file is the source of truth. This row is a projection of it, keyed by
    # adr_id and carrying body_digest, so drift between the two is detectable
    # rather than assumed away.
    class Record < ::ActiveRecord::Base
      self.table_name = "mmg_adr_records"

      LIST_ATTRIBUTES = %w[components paths enforced_by].freeze
      # Stored in their own TEXT columns rather than *_csv ones, but read and
      # written as lists all the same: a split names two successors.
      LINK_ATTRIBUTES = %w[supersedes superseded_by].freeze

      validates :adr_id, presence: true, uniqueness: true
      validates :title, presence: true
      validates :status, presence: true,
                         inclusion: { in: Vocabulary::STATUSES, message: "must be proposed, accepted or superseded" }
      validates :subject_kind, inclusion: { in: Vocabulary::SUBJECT_KINDS, allow_nil: true }
      validates :body_digest, presence: true

      validate :accepted_body_is_immutable
      validate :lifecycle_moves_forward
      validate :superseded_names_its_successor

      # -- lifecycle ---------------------------------------------------------
      #
      # Proposed -> Accepted -> Superseded, one direction only. Decision history
      # is a ledger, not a document that is live in the editable sense; an
      # accepted record that can quietly become proposed again is a ledger that
      # can be rewritten, which is no ledger.

      def accepted? = status == "accepted"
      def superseded? = status == Vocabulary::TERMINAL

      def subject_iri = Vocabulary.subject_iri(adr_id)

      LIST_ATTRIBUTES.each do |name|
        define_method(name) { split_list(self["#{name}_csv"]) }
        define_method("#{name}=") { |value| self["#{name}_csv"] = Array(value).map(&:to_s).reject(&:empty?).join("\n") }
      end

      LINK_ATTRIBUTES.each do |name|
        define_method(name) { split_list(self[name]) }
        define_method("#{name}=") { |value| self[name] = Array(value).map(&:to_s).reject(&:empty?).join("\n") }
      end

      # The attribute view the projection consumes. Same keys the parser emits,
      # so a round trip through the row cannot silently rename a field.
      def attributes_for_projection
        {
          "adr_id" => adr_id, "title" => title, "status" => status, "date" => date,
          "subject_kind" => subject_kind, "subject" => subject,
          "components" => components, "paths" => paths, "enforced_by" => enforced_by,
          "supersedes" => supersedes, "superseded_by" => superseded_by,
          "source_path" => source_path, "body_digest" => body_digest
        }
      end

      def triples = Projection.triples(attributes_for_projection)

      def chain_break(exists: ->(_p) { true })
        Chain.break_at(attributes_for_projection, exists: exists)
      end

      # The named graph this record's attributes live in. Grounded: it is the
      # graph of a Mmg::Graph::Entry row, so the triples resolve to a record that
      # says when they were asserted and why. Nothing anonymous can be written
      # because there is nowhere anonymous to write it.
      def graph_entry
        return nil unless defined?(::Mmg::Graph::Entry)

        ::Mmg::Graph::Entry.find_by(id: graph_entry_id)
      end

      def ref = "Mmg::Adr::Record:#{id}"

      def self.schema_sql
        <<~SQL
          CREATE TABLE IF NOT EXISTS mmg_adr_records (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            adr_id          TEXT NOT NULL,
            title           TEXT NOT NULL,
            status          TEXT NOT NULL,
            date            TEXT,
            subject_kind    TEXT,
            subject         TEXT,
            components_csv  TEXT,
            paths_csv       TEXT,
            enforced_by_csv TEXT,
            supersedes      TEXT,
            superseded_by   TEXT,
            source_path     TEXT,
            body_digest     TEXT NOT NULL,
            legacy          INTEGER NOT NULL DEFAULT 0,
            graph_entry_id  INTEGER,
            created_at      TEXT NOT NULL,
            updated_at      TEXT NOT NULL
          );
          CREATE UNIQUE INDEX IF NOT EXISTS idx_mmg_adr_records_adr_id ON mmg_adr_records (adr_id);
          CREATE INDEX IF NOT EXISTS idx_mmg_adr_records_subject ON mmg_adr_records (subject_kind, subject);
        SQL
      end

      private

      def split_list(value) = value.to_s.split("\n").map(&:strip).reject(&:empty?)

      # Once accepted, an ADR is never edited. Superseding it is the supported
      # move, and it is a different one: it leaves the original standing and adds
      # a record that points back. Editing in place destroys the reason the
      # ledger was worth keeping.
      def accepted_body_is_immutable
        return if new_record?
        return unless body_digest_changed?

        was = status_changed? ? status_was : status
        return unless %w[accepted superseded].include?(was)

        errors.add(:body_digest,
                   "cannot change on a #{was} ADR -- supersede it with a new record instead of editing it")
      end

      def lifecycle_moves_forward
        return if new_record? || !status_changed?

        from = Vocabulary::STATUSES.index(status_was.to_s)
        to   = Vocabulary::STATUSES.index(status.to_s)
        return if from.nil? || to.nil? || to >= from

        errors.add(:status, "cannot move backwards from #{status_was} to #{status}")
      end

      # A superseded record with no successor is the worst state in the ledger:
      # it announces that it no longer holds without saying what does, leaving a
      # reader with a rule they cannot replace.
      def superseded_names_its_successor
        return unless status == Vocabulary::TERMINAL
        return if superseded_by.any?

        errors.add(:superseded_by, "is required when status is superseded -- name the ADR(s) that replace this one")
      end
    end
  end
end
