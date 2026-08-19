# Charter - rails-threedot-back

Serve the threedot plugin's live data plane with **CID as the ActiveRecord root**, over the
**single public CPCP seam** (`/_cpcp`) - never a second endpoint family.

**Invariants (from the split design):**
- CID = root AR record; Operations/Capabilities/Shapes/ObjectNodes hang off it; the shell reads the LIVE projection, not the static file.
- Static `.threedot/cid.json` = bootstrap discovery seed ONLY; no live data; disconnected-state + retry if the BACK is unreachable.
- PULL = Context read from the CID; PUSH = typed, closed-shape Effect; idempotent by `operationId`; receipt returned; authority/validation/persistence on the BACK.
- Storable (RDF projection) enabled but DEFERRED; AR-primary first cut.
- Optional `rails-osi-level-8` grounding behind the same seam.

**First-cut build order:** migrate the CID-rooted tables -> `CpcpProjection.install!` on `rails-cpcp`
with one live CID -> prove shell<->back PULL/PUSH -> seed-is-discovery-only -> PUSH receipt + idempotency.
