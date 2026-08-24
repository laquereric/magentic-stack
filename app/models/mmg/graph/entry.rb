# frozen_string_literal: true

module Mmg
  module Graph
    # THE MODEL THAT GROUNDS AD-HOC GRAPH STORAGE.
    #
    # Every node in this graph references a Rails model -- a class or an instance
    # -- and node identity is (model class, primary key). That is what makes the
    # graph a PROJECTION of the relational store rather than a second authority.
    #
    # Ad-hoc triples had nothing to reference. `publish` took raw triples and a
    # named-graph string, so anything could write nodes no model could reproduce
    # and nothing would catch it. The invariant held by discipline, which is to
    # say it did not hold.
    #
    # An Entry IS that missing record. Ad-hoc triples are published into the named
    # graph OF an Entry, so the node is grounded by construction: the graph name
    # resolves to a row, and the row says when it was made, what it is called, and
    # why it exists. Nothing anonymous can be written, because there is nowhere
    # anonymous to write it.
    class Entry < ::ActiveRecord::Base
      self.table_name = "mmg_graph_entries"

      # Required. The triples say what was asserted; they never say why it is
      # here, and the why is what a later reader needs. A store of unattributed
      # assertions cannot be audited, and the cost of asking is one line.
      validates :date,        presence: true
      validates :name,        presence: true
      validates :description, presence: true

      # The named graph this entry owns. Derived from the primary key, never
      # supplied: a caller that could name its own graph could write into someone
      # else's, or into one that resolves to no record at all.
      def graph_name
        raise "unsaved entry has no graph" if id.nil?

        "urn:mmg:graph:entry:#{id}"
      end

      # The ref that makes this node grounded, in the same shape vv-graph uses
      # for every other projected record.
      def ref
        "Mmg::Graph::Entry:#{id}"
      end

      def self.schema_sql
        <<~SQL
          CREATE TABLE IF NOT EXISTS mmg_graph_entries (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            date        TEXT NOT NULL,
            name        TEXT NOT NULL,
            description TEXT NOT NULL,
            created_at  TEXT NOT NULL,
            updated_at  TEXT NOT NULL
          );
        SQL
      end
    end
  end
end
