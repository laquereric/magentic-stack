# frozen_string_literal: true
# MagenticMarket-Copyright-Notice: begin v1
# SPDX-FileCopyrightText: 2026 CBI Business Transactions, LLC
# SPDX-License-Identifier: LicenseRef-DataYoursSoftwareMine-1.0
# SPDX-FileComment: License-URL: https://github.com/laquereric/DataYoursSoftwareMine
# MagenticMarket-Copyright-Notice: end v1

module Mmg
  module Acia
    # A TERM IN THE SPECIFIED VOCABULARY.
    #
    # Profile 9's normative shapes define 13 closed enumerations over 98 slots and
    # 96 distinct terms, all in one namespace. This is that namespace as rows, so
    # the substrate can join and query against a value the spec already made
    # addressable.
    #
    # ONE TABLE, not one per enumeration. `table` and `timeline` each appear in
    # both semanticRole and layoutKind -- 2 of 98 slots -- and the spec resolves
    # that by using ONE resource, ux:table, constrained by the property it sits
    # on. Five tables would have made two rows where the specification has one.
    #
    # Which enumerations admit a term is a fact about the SPEC, carried on the row
    # so `fetch` can refuse a term that is not legal in the position asked for.
    class AciaTerm < ::ActiveRecord::Base
      self.table_name = "acia_terms"

      VOCAB = "https://w3id.org/cpcp/osi8/ux#"

      validates :token, presence: true, uniqueness: true

      scope :ordered, -> { order(:ordinal, :token) }
      scope :in_enumeration, ->(name) { where("enumerations LIKE ?", "%|#{name}|%") }

      def enumeration_names = enumerations.to_s.split("|").reject(&:empty?)
      def in?(name) = enumeration_names.include?(name.to_s)

      # DERIVED, NEVER STORED -- and it is the specification's own IRI, not a
      # name of ours that agrees in spelling. A consumer resolving ux:heading
      # finds this term.
      def iri = "#{VOCAB}#{token}"

      def to_s = token.to_s

      def self.iri_for(token) = "#{VOCAB}#{token}"

      # Refuse a term that is not legal in the position asked for. The
      # vocabularies are closed and position-sensitive: ux:table is a legal
      # semanticRole and a legal layoutKind, and nothing else.
      def self.fetch!(enumeration, token)
        row = find_by(token: token.to_s)
        raise ArgumentError, "#{token.inspect} is not a term in the Profile 9 vocabulary" if row.nil?
        unless row.in?(enumeration)
          raise ArgumentError,
                "#{token.inspect} is not a legal #{enumeration} (it is: #{row.enumeration_names.join(', ')})"
        end

        row
      end

      def self.schema_sql
        <<~SQL
          CREATE TABLE IF NOT EXISTS acia_terms (
            id           INTEGER PRIMARY KEY AUTOINCREMENT,
            token        TEXT NOT NULL,
            enumerations TEXT NOT NULL DEFAULT '',
            ordinal      INTEGER NOT NULL DEFAULT 0,
            created_at   TEXT NOT NULL,
            updated_at   TEXT NOT NULL
          );
          CREATE UNIQUE INDEX IF NOT EXISTS idx_acia_terms_token ON acia_terms (token);
        SQL
      end
    end
  end
end
