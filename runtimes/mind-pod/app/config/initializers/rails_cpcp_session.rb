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
# SHAPE-GATED. Each operation names a closed shape from Profile 1
# (osi-level-8-profiles/profile-1-cyborg-channel/shapes/session-operations.shacl.ttl,
# exercised by pyshacl with valid/invalid fixtures in CI). The shapes carry the
# two rules this cycle depends on: a PUSH names its intent, and the client does
# not supply server-authoritative fields -- MIND proposes, BACK commits, so a
# proposal that could stamp its own status would be deciding what it is asking.
#
# The TTL is NOT executed in-process; RailsOsiLevel8::Grounding carries the
# runtime twin that does the refusing. A shape with no such twin now REFUSES
# rather than validating clean, so this wrapping cannot become decoration.
Rails.application.config.to_prepare do
  next unless ENV.fetch("ROLE", "back") == "back"

  RailsCpcp.project(model: "Session") do
    operation "session.open",
      direction: :push, params: %w[actor_kind], summary: "Mint a cyborg session and the named graph it owns",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "session.open", direction: :push,
        profiles: %w[osi-l8/p1/cyborg-channel@1 osi-l8/p2/reference-passing@1],
        request_shape: "P1::SessionOpenEffectShape", response_shape: "P1::SessionOpenContextShape"
      ) { |p, _c| SessionCycle.open(p) }

    operation "session.latest",
      direction: :pull, summary: "Which session is in force -- the newest open one, human or agent",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "session.latest", direction: :pull,
        profiles: %w[osi-l8/p1/cyborg-channel@1 osi-l8/p2/reference-passing@1],
        request_shape: "P1::SessionLatestPullShape", response_shape: "P1::SessionLatestContextShape"
      ) { |p, _c| SessionCycle.latest(p) }

    operation "session.context",
      direction: :pull, params: %w[session_id], summary: "Bounded by-reference preview of ONE session's graph",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "session.context", direction: :pull,
        profiles: %w[osi-l8/p1/cyborg-channel@1 osi-l8/p2/reference-passing@1],
        request_shape: "P1::SessionContextPullShape", response_shape: "P1::SessionContextContextShape"
      ) { |p, _c| SessionCycle.context(p) }

    operation "session.observe",
      direction: :push, params: %w[session_id title], summary: "Commit a cognitive record into the session's graph (MIND proposes, BACK commits)",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "session.observe", direction: :push,
        profiles: %w[osi-l8/p1/cyborg-channel@1 osi-l8/p2/reference-passing@1],
        request_shape: "P1::SessionObserveEffectShape", response_shape: "P1::SessionObserveContextShape"
      ) { |p, _c| SessionCycle.observe(p) }

    # Whole-store replay: the procedure that makes reconstructable_from real.
    # A PULL, deliberately -- it asserts nothing new, it re-derives what the
    # relational store already says.
    operation "graph.replay",
      direction: :pull,
      summary: "Re-project every Storable record; the backfill GRAPH could not be rebuilt without",
      via: ->(p, _c) { GraphReplay.run(p || {}) }

    operation "session.close",
      direction: :push, params: %w[session_id], summary: "Seal the session; its graph persists, append-only",
      via: RailsOsiLevel8::CpcpAdapter.wrap(
        operation: "session.close", direction: :push,
        profiles: %w[osi-l8/p1/cyborg-channel@1 osi-l8/p2/reference-passing@1],
        request_shape: "P1::SessionCloseEffectShape", response_shape: "P1::SessionCloseContextShape"
      ) { |p, _c| SessionCycle.close(p) }
  end
end
