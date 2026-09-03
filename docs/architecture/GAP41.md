# Gap 41 (caller wiring): config-admin configures persistence

Built at SHA of this change. ROW41 scoped the effect; GAP8 built the
server. This closes the caller half: config-admin — the UI that stores
credentials to vault — now configures persistence through persist.

## 1. What was built

* `ConfigAdmin::PersistClient`: persist's first caller. Allowlisted
  `persist.path.set/get` only, Bearer token, `Net::HTTP#request` so 4xx
  bodies keep reason/because (gap 104 — same contract as the vault
  client, which this mirrors method for method).
* `ConfigAdmin::PlacementsController` + view: per-store recorded
  intention plus a record form. Path options come from the row-39 closed
  set (`Persist::ClosedSet`, same file the gate enforces) — never free
  text, never client-built. Refusals surface as `@refusal` (gap-104
  pattern); recording redirects, refusal re-renders 422.
* Routes (`GET/POST /placements`, config role only), nav links both
  ways, `PERSIST_URL`/`PERSIST_TOKEN` in fail-closed boot and both
  composes (`PERSIST_URL: http://persist:3000`, token from
  `CONFIG_PERSIST_TOKEN`), dump-env dummies for route dumping.

## 2. What this does not do

* **No pairing validation.** The form offers every closed-set path for
  every store; recording domain→bus-file is storable as an intention.
  The static writer-set gate still protects the actual compose, and
  application stays a human-approved restart — but a set that pairs a
  store with another store's path is not refused at admission. That
  matrix is the 0051 §5 amendment's territory, still the owner's.
* **No first real placement.** The loop (record → restart → bind) has not
  been exercised against production data; that is operational, with the
  operator, not a further build.
* **No secret handling.** Placement paths are not credentials; they
  render in full. Do not let this page grow a "show token" habit from
  sitting next to the secrets page.

## 3. Live proof (isolated fixtures, wiped after)

* persist + config booted with wired tokens: `GET /placements` renders,
  `POST /placements` (domain → domain path) 302s, re-GET shows the
  recorded path; evil path posts 422 with "persist refused" rendered.
  Full UI → seam → record → render loop, no production data.

## 4. Gates

* `check_config_persist_client.py` (7 examined): set+get named, CPCP
  transport, `request()` bodies, no client-side path invention,
  controller wired to env + closed set + refusal.
* Census: persist client as caller/config. `role_routes.json` gains the
  two placement routes. Specs: boot envs, client allowlist + envelope,
  placement routes.
