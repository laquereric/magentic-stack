# rails-osi-level-8

**The OSI Level 8 cybernetic interface as a Rails engine - a *semantic adapter atop CPCP*.**

OSI Level 8 is the layer above Application where a **Cyborg** (a responsible Human + Compute)
**perceives Context** and **acts via Effect**, over grounded JSON-RPC-LD constrained by closed
SHACL shapes (spec: https://github.com/laquereric/osi-level-8). `rails-osi-level-8` realizes that
grammar in Rails **without inventing a new endpoint family**:

- **Context = perception (a CPCP PULL); Effect = action (a CPCP PUSH).**
- **It decorates `rails-cpcp`** - `/_cpcp` remains the *single* public RPC seam. This engine adds
  grounding (closed-SHACL validation of profile shapes), the **three-ledger discipline**
  (`canonical` / `sync_intent` / `private_local`), and **profile evidence** (Profiles 1-8).
- **Additive**: mount it in the BACK app alongside `rails-cpcp`; it never becomes a competing surface.

## Role in the Magentic POC

Per the [preliminary design](https://github.com/laquereric/app-osi-8-nooa-poc), `rails-osi-level-8`
is the **grounding grammar** in the BACK container - the stable enterprise semantic layer under a
fast-moving agent runtime (MIND / NOOA) and model router (SwitchYard). We follow the upstreams; we
own the grounding. It composes with `rails-cpcp` (the pod contract) and `mm-shacl-reader` (SHACL),
both soft-loaded.

## Layout
```
lib/rails_osi_level_8/  grammar, context/effect, ledger, grounding (SHACL), cpcp_adapter, engine
```

Status: **scaffold**. Apache-2.0 (open-protocol realization). See `docs/CHARTER.md`.
