# Gap 11, slice A: provider keys live in vault

Built at SHA of this change. Scope was [`ROW11.md`](ROW11.md) slices A.
Slices B–D remain.

## 1. What was built

Switch is an allowlisted vault `get` caller (`llm-plane`: `list` for
presence, `get` for values). New `runtimes/switch/vault.mjs`: slots are
`switchyard.<vendor>` (namespaced — a bare vendor id could collide with
another caller's slot); presence via one `list` RPC, values fetched only
at the point of use (completion, discovery); **no caching**, so rotation
applies on the next call and no second copy goes stale. Misses read
exactly like no key (`missing_credential`) — vault down, unconfigured,
or refusing are indistinguishable downstream, and there is no fallback
credential anywhere.

* `completeRemote` and `discover` take vault-fetched values; readiness
  comes from an attached presence set (`withKeys`), never the file.
* `POST /api/sources` key set/clear is now `400 key_moved_to_vault`;
  the UI key form is a static pointer to the config UI.
* The `/state` bind mount keeps non-key routing state only
  (`active/enabled/prices/discovered/verified`) — form unchanged per row
  46, `.agent/secrets` untouched. Old files may still *contain* keys;
  they are never read in prod, and boot logs `switch_keys_ignored`
  naming the vendors to move. Nothing purges them in this slice (a purge
  that races the operator's copy loses credentials); purge belongs with
  slice B after the migration window.

## 2. Operator migration (order matters)

1. Put keys in vault slots `switchyard.<vendor>` via the config UI
   (`:13003`); add `llm-plane` (`list`, `get`) to `VAULT_CALLERS`; set
   `SWITCH_VAULT_TOKEN` on switch.
2. Deploy. Completions refuse `missing_credential` until step 1 lands —
   fail-closed and visible, recoverable by completing step 1.
3. After keys verify (test endpoint per vendor), clear the stale file
   entries. Slice B removes the form; the purge rides with it.

QUICKSTART's key step now points at the vault UI.

## 3. Gates

* `check_switchyard_vault_keys.py` (12 examined): vault get+list used,
  client touches no state file, no `state.keys` in server/sources/
  discovery, key writes refused, UI takes no key material, both composes
  vault-wired with the bind kept. Plants: file-key read, UI key form,
  missing vault env.
* All 76 switch node tests pass against a stub vault (real HTTP —
  global fetch stubs pass `/​_cpcp/rpc` through), including an explicit
  refresh where key-setting used to trigger discovery inline.
* Standing gates untouched: content-blind algorithms, loopback, row-46
  binds, pin. `check_credential_bind_mounts` still passes — the mount
  never changed, only its contents did.

## 4. Live proof (real vault, wiped after)

* Vault container + switch server from source: key put in vault slot
  `switchyard.openai` → `/api/sources` reports openai ready with an
  **empty** state file (vault is the source, not the file); UI payload
  contains no secret; key POST → 400 `key_moved_to_vault`.
* All 76 switch node tests pass against a stub vault over real HTTP.

## 5. What this does not do

* Slices B (UI move), C (retire `:13001`), D (cache-attest verdict).
* Purging stale file keys (slice B, post-migration).
* Caching key values anywhere (deliberate; see §1).
* Touching the data plane, the pin, discovery/verify placement (row 15),
  or the bind mount form (row 46).
