# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    # THE SHARED BASE FOR THE FIVE SLT DIMENSIONS.
    #
    # An SLT dimension value -- "heading", "stack", "navigate" -- used to be a
    # bare string checked against a frozen Ruby array. A string cannot be
    # described, ordered, deprecated or pointed at: nothing can say what
    # "disclose" means, which registry version admitted it, or that a node uses
    # it. Making each value a ROW makes it addressable, and an addressable value
    # can be referenced by IRI in the graph instead of repeated as a literal.
    #
    # Five near-identical models would drift apart one edit at a time. One base
    # cannot: the subclasses carry a table name and a dimension key, nothing else.
    class Dimension < ::ActiveRecord::Base
      self.abstract_class = true

      VOCAB = "urn:mm:vocab/acia#"

      # A token IS the closed-vocabulary string, so it must be unique within its
      # dimension -- two rows for "heading" is two answers to one question.
      validates :token, presence: true, uniqueness: true
      validates :token, format: { with: /\A[a-z][a-z0-9_]*\z/,
                                  message: "must be lower_snake_case (the vocabulary is closed; a new spelling is a new term)" }

      scope :ordered, -> { order(:ordinal, :token) }

      # THE DIMENSION KEY, and the reason these are five tables rather than one
      # polymorphic table: "table" is a legal semanticRole AND a legal layoutKind,
      # and they are not the same thing. One table keyed by token alone would
      # make them one row.
      def self.dimension_key = raise(NotImplementedError, "#{name} must declare a dimension_key")

      def self.for_token(token) = find_by(token: token.to_s)

      # Refuse rather than create. These are CLOSED vocabularies; a lookup table
      # that grows by typo is not one.
      def self.fetch_token!(token)
        for_token(token) ||
          raise(ArgumentError, "#{token.inspect} is not a #{dimension_key}; the vocabulary is closed " \
                               "(known: #{ordered.pluck(:token).join(', ')})")
      end

      def self.iri_for(token) = "#{VOCAB}#{dimension_key}/#{token}"

      # DERIVED, NEVER STORED.
      #
      # Same reasoning as Mmg::Graph::Entry#graph_name: a row that can name its
      # own IRI can name someone else's, and then two rows claim one identity.
      # The IRI is a function of (dimension, token) or it is not an identity.
      def iri = self.class.iri_for(token)

      def to_s = token.to_s

      def self.schema_sql(table = table_name)
        <<~SQL
          CREATE TABLE IF NOT EXISTS #{table} (
            id               INTEGER PRIMARY KEY AUTOINCREMENT,
            token            TEXT NOT NULL,
            ordinal          INTEGER NOT NULL DEFAULT 0,
            registry_version TEXT NOT NULL DEFAULT 'ghis-19@1',
            description      TEXT,
            created_at       TEXT NOT NULL,
            updated_at       TEXT NOT NULL
          );
          CREATE UNIQUE INDEX IF NOT EXISTS idx_#{table}_token ON #{table} (token);
        SQL
      end
    end
  end
end
