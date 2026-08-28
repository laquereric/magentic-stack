# frozen_string_literal: true

# THE SESSION CYCLE at the seam.
#
#   session.open     mint a Session and its graph
#   session.context  a BOUNDED, by-reference look at that session's graph
#   session.observe  MIND's cognitive effect, PROPOSED; BACK commits it
#   session.close    seal it; the graph persists
#
# MIND reaches GRAPH only through here. There is no second socket: the boundary
# rule (Gate 1 Part C, test/mind_boundary_test.py) is that MIND may only produce
# an Effect through this seam, and a direct write path would break it.
#
# WHY THESE ARE PLAIN LAMBDAS. note.list/note.create are wrapped in
# RailsOsiLevel8::CpcpAdapter, but every other operation here -- all of l8.*,
# ux.*, meaning.*, intent.* -- registers plainly. The property Gate 1 Part C
# actually tests comes from rails-cpcp's Dispatcher, which refuses any :push
# lacking an operationId (:operation_id_required) regardless of wrapping. Closed
# SHACL shapes for these four are follow-up work, and are NOT claimed here.
Rails.application.config.to_prepare do
  next unless ENV.fetch("ROLE", "back") == "back"

  RailsCpcp.project(model: "Session") do
    operation "session.open",
      direction: :push, params: %w[actor_kind],
      summary: "Mint a cyborg session and the named graph it owns",
      via: ->(p, _c) { SessionCycle.open(p) }

    operation "session.latest",
      direction: :pull,
      summary: "Which session is in force -- the newest open one, human or agent",
      via: ->(p, _c) { SessionCycle.latest(p) }

    operation "session.context",
      direction: :pull, params: %w[session_id], result: :collection,
      summary: "Bounded by-reference preview of ONE session's graph",
      via: ->(p, _c) { SessionCycle.context(p) }

    operation "session.observe",
      direction: :push, params: %w[session_id title body],
      summary: "Commit a cognitive record into the session's graph (MIND proposes, BACK commits)",
      via: ->(p, _c) { SessionCycle.observe(p) }

    # Whole-store replay: the procedure that makes reconstructable_from real.
    # A PULL, deliberately -- it asserts nothing new, it re-derives what the
    # relational store already says.
    operation "graph.replay",
      direction: :pull,
      summary: "Re-project every Storable record; the backfill GRAPH could not be rebuilt without",
      via: ->(p, _c) { GraphReplay.run(p || {}) }

    operation "session.close",
      direction: :push, params: %w[session_id],
      summary: "Seal the session; its graph persists, append-only",
      via: ->(p, _c) { SessionCycle.close(p) }
  end
end
