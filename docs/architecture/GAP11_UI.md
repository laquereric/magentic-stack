# Gap 11, slice B: the switch display lives in config-admin

Built at SHA of this change. Scope was [`ROW11.md`](ROW11.md) slice B.
Slices C–D remain.

## 1. What was built

Config-admin shows switch sources + pins + test results, calling the
switch UI plane server-side so browsers never touch switch — the
documented precondition for retiring `:13001`:

* `ConfigAdmin::SwitchClient`: allowlisted display + trigger paths
  (`sources`, `refresh`, `verify-tools`, `test`), pod-internal base URL
  from `SWITCH_UI_URL` (no host port literal anywhere), gap-104
  envelopes, generous read timeout for billed verify loops. It cannot
  send key material — no key param exists.
* `ConfigAdmin::SwitchController` + view: vendors table (readiness,
  pins, enable toggles, prices), refresh/verify/test triggers with
  confirm on the billed ones, refusal surfacing. Recording-style POSTs
  redirect; refusals re-render with reason/because.
* Routes (`GET /switch`, four POST actions, config role only), nav
  links, `SWITCH_UI_URL` in fail-closed boot, both composes, and route
  dump env.

## 2. What this does not do

* Slice C (retire `:13001`) — unpublishing plus the docs sweep. The
  display this was conditioned on now exists.
* Slice D (cache-attest verdict).
* Key entry (vault UI owns it since slice A); verify/test execute on
  switch (row 15 stands).
* No census change was needed: the new files carry no `_cpcp/rpc`
  token (verified — an entry would fail the bidirectional match).

## 3. Gates

* `check_config_switch_client.py` (7 examined): paths named, no host
  port, no key material, `request()` bodies, env wiring + refusal in
  the controller.
* `role_routes.json` gains the five switch rules. Specs: boot envs,
  client allowlist + envelope, switch routes. Full suite holds only the
  12 pre-existing failures.
