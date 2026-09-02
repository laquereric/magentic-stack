# Gap 20: per-seam authority, counted from the tree

Gap 79 already rewrote the live "only write path" prose (routes.rb,
compose headers, mind_agent.py). mmg-graph "sole writer on the far
side" was left: that is the far side of BACK's seam, still true.
This turn is the table and the gate. Count was not inherited.

**2026-09-02 (gap 50):** vault moved from not-a-seam to decided-unbuilt.
Live still 2. decided-unbuilt is now 3 (`mind`, `bus`, `vault`). REST
still serves; `/_cpcp` unbuilt. FRONT and `runtimes/switch` stay
not-a-seam.

## Measured

**Live CPCP HTTP servers (kind=server in the gap-59 census): 2 seams.**

| id | served | authoritative for | domain writer |
|---|---|---|---|
| `back` | `rails-cpcp` rpc_controller | domain state admitted over rails-cpcp | **yes** (with BACKJOB, who does not mount `/_cpcp`) |
| `switchyard-offline` | listener + contract.js + chrome SW | local credential routing (`switchyard.route`) | no |

**Decided, unbuilt: 2 seams.**

| id | authoritative for |
|---|---|
| `mind` | NOOA push/pull mapping (ADR 0048 / row 10) |
| `bus` | RES metadata; async (row 72); journal stays in BACK (row 73). Row 18: the SwitchYard CPCP endpoint **is this seam**, not a fifth |

**Not a seam:** FRONT (gated off), VAULT (REST; CPCP inbound unbuilt; non-200 plus envelope is correct), `runtimes/switch` (chat completions, no `/_cpcp`).

0050 said **four** (BACK, MIND, SwitchYard, BUS). Row 20 said **five**.
After row 18, SwitchYard-CPCP and BUS collapse, so 0050's four become
three topology slots (BACK live, MIND unbuilt, BUS unbuilt). The extra
**live** surface 0050 did not name is `switchyard-offline`. Live 2 +
unbuilt 2 = 4 files-in-the-table, not 0050's four names.

## Gate

`tooling/cpcp/seam_authority.json` + `check_seam_authority.py`.

- every `cpcp_callers.json` `kind=server` file belongs to a live seam
- live seam has `authoritative_for` and boolean `domain_writer`
- `domain_writer: true` is exactly `back`
- decided-unbuilt have authority text and empty `served_by`

Plants: empty CHECK_ROOT; empty `authoritative_for` on BACK; plant a
`kind=server` that is not on a live seam.

0050 is **partial**: `unenforced: true` for the unbuilt roles, and
`enforced_by` names this checker (gap 97 shape). Body of 0050 not
edited.

Did not build MIND or BUS. Did not rewrite ADRs. Did not touch the
mmg-graph far-side phrase.
