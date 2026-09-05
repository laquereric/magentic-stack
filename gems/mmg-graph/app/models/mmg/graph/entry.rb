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

      # The named graph this entry writes into. Derived from a primary key, never
      # supplied: a caller that could name its own graph could write into someone
      # else's, or into one that resolves to no record at all.
      #
      # TWO DERIVATIONS, ONE RULE. An entry normally owns a private graph keyed by
      # its own id. A SESSION-scoped entry writes into the graph of the session it
      # names, so everything one session saw and proposed accumulates in ONE place
      # and "what happened in this session" is a query rather than a reconstruction.
      #
      # The rule is unchanged either way: the name comes from a primary key and
      # resolves to a row. session_id is a foreign key, not a string a caller hands
      # us -- an unknown session cannot be written into, because the reference has
      # to exist before the name does.
      #
      # Grounding is untouched. Each publish still mints its OWN entry carrying its
      # own date/name/description, still accounting for exactly what it asserted.
      # Only the destination is shared. ADR 0011 requires an assertion to be
      # grounded; it does not require it to be alone.
      # NAMESPACED WHEN ASKED, legacy otherwise. The id is unique in this
      # database; the STORE may be shared, and two databases both counting from 1
      # will name the same graph. MMG_GRAPH_NAMESPACE adds a segment the other
      # database cannot accidentally share. See Mmg::Graph.namespace for why the
      # default has to stay legacy -- renaming an existing deployment's graphs
      # would orphan every triple it has already asserted.
      def graph_name
        return session_graph_name if session_id.present?
        raise "unsaved entry has no graph" if id.nil?

        ns = ::Mmg::Graph.namespace
        ns ? "urn:mmg:graph:#{ns}:entry:#{id}" : "urn:mmg:graph:entry:#{id}"
      end

      # Kept in step with Vv::Base::Session#session_iri. mmg-graph does not depend
      # on vv-base, so the shape is duplicated rather than required -- but if the
      # session class IS loaded, ask it instead of guessing.
      def session_graph_name
        if defined?(::Vv::Base::Session)
          session = ::Vv::Base::Session.find_by(id: session_id)
          return session.session_iri if session
        end
        "urn:mm:session:#{session_id}"
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
            session_id  INTEGER,
            created_at  TEXT NOT NULL,
            updated_at  TEXT NOT NULL
          );
        SQL
      end
    end
  end
end
