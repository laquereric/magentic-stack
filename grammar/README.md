# grammar/  🟢 OWN IT

**The durable language.** This is the most-owned part of the stack — the stable,
versioned contract layer that everything else derives from. When code and
contract disagree, the contract wins.

| Subdir | Purpose | Where |
|---|---|---|
| `osi-level-8/` | OSI Level 8 normative spec — the grounding language. Profiles and their closed SHACL shapes are a package under `gems/osi-level-8-profiles` (ADR 0022). | this repo |
| `cpcp/` | Cyborg-Pod-Contract-Package: the `/_cpcp` contract profile. | this repo (engine in `gems/rails-cpcp`) |
| `conformance/` | Profile 1–8 conformance tests — valid and invalid example calls. | this repo |

## Why grammar is first-class

OSI Level 8 translates upstream AI capabilities into enterprise actions via
**Context** (what may be read) and **Effect** (what may be done), constrained by
**closed SHACL shapes**. Because the contract is stable and machine-validated,
downstream experimentation stays auditable and governable while upstream churns.

## Vendored source

- `osi-level-8/` is vendored in via **git subtree** (ADR 0002) — real Profile 3-8
  closed SHACL shapes, valid/invalid examples, and the `scripts/validate_profiles.py`
  validator. **Gate 2** ([`.github/workflows/shacl-conformance.yml`](../.github/workflows/shacl-conformance.yml))
  runs it in CI against pinned pySHACL; a valid fixture must conform and an invalid
  fixture must fail, or the release is blocked.
