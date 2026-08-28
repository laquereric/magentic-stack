# frozen_string_literal: true

# Session scoping for graph entries.
#
# A separate migration rather than an edit to 20260828000001: that one has already
# run against a database, and rewriting an applied migration leaves schema_migrations
# claiming work that no longer matches what was done.
#
# Nullable with no FK constraint. mmg-graph does not depend on vv-base, so the
# database cannot enforce the reference -- Cpcp.publish validates it in Ruby and
# REFUSES an unknown session. A FK here would make the gem's schema depend on a
# table it does not own.
class AddSessionIdToMmgGraphEntries < ActiveRecord::Migration[8.1]
  def change
    add_column :mmg_graph_entries, :session_id, :bigint
    add_index  :mmg_graph_entries, :session_id
  end
end
