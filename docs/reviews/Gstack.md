
gstack Review — Profiles 1–10 (rails-osi-level-8 + mind-pod)

Reviewer lens (correctness/simplification/efficiency/altitude) + CSO lens (OWASP/STRIDE, private_local non-escape, /_cpcp sole seam, never-raise). Single-model pass — the second independent model (grok) is paused, so medium/latent findings go to your judgment per the gstack rule.

CSO — no high-confidence (≥8) security findings. Verified-good:
- private_local non-escaLLs is real:Record.cross_boundary = where(ledger_placement: %w[canonical sync_intent]),
and every *.list uses .cte_scope! additionallyrejects a caller-supplied ledgerScope: private_local non-disclosingly.
Defense-in-depth. The M7classified" stakeholder)is asserted non-escaping.
- /_cpcp stays the sole nownRefusal → never-raiseenvelope.                                                                 
Verified findings (ranked):                                               
1. [medium · correctness/altitude] Canonical Mission/Vision/Persona can't represent private_local,apses every state tocanonical. pulls.rb persona_list/mission_get query the plain              ::Persona/::Mission app r_placement and nocross_boundary filter; Projection.default_placement (projection.rb:91-93) returns canonical for ev"sensitive deliberation →private_local mission/persona" isn't expressible — and if it later is, mission_get by id/cid/slonical. Not an active leak today (the data model can't hold private intent), but a latent gap to close before real intent data
2. [low · efficiency] find_canonical cid lookup is an O(n) full scan
(projection.rb/pulls.rb: return r ifProjection.for(r)["cid"] == cid } recomputes a SHA-256 projection per row.
Fine at demo scale; inde it grows.
3. [low · altitude] Demo-only affordances to revisit before production (grok
flagged these): auth DENprefix (a real policy must not key on user content); Grounding is a Ruby allowlist, not full SHACL
(mm-shacl-reader deferreutside the outer push txnto survive refusal (correct for the requirement, but worth a comment
asserting the invariant)

Clean: the no-duplicatiolmissions/visions/personas/actors/journeys/flows, zero intent_* duplicates, relationships in the gra; app 22/22.

