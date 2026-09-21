---
id: "0074"
title: A canonical home row has a natural key and a bundle scope, and is seeded declaratively
status: accepted
date: 2026-09-21
subject_kind: gem
subject: vv-base
components: [vv-base, vv-per-site, rails-osi-level-8, mind-pod]
paths:
  - gems/vv-base/db/migrate/20260824120000_create_vv_base_canonical_homes.rb
  - gems/vv-base/db/migrate/20260912000000_create_vv_base_flow_steps_and_information_models.rb
  - gems/vv-base/lib/vv/base/ledger_placed.rb
  - gems/vv-per-site/lib/vv/per_site/okf_node.rb
  - gems/vv-per-site/lib/vv/per_site/okf/seeder.rb
  - gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/j1.rb
  - runtimes/mind-pod/app/db/seeds.rb
  - docs/architecture/CANONICAL_GAPS.md
enforced_by: []
unenforced: true
unenforced_because: "Decision 5 requires a checker holding no-imperative-seeding and no-unscoped-uniqueness. It is unbuilt, and so are the columns it would examine, so there is no enforcing target to name and naming one would be the fake enforcement this repo already refuses elsewhere. Recorded now because the decision is what orders the migrations, and because two callers are already seeding journeys with different keys against no constraint: writing the rule down is what stops a third. Drop this flag and fill enforced_by when decision 5 lands."
stand_in: null
supersedes: null
superseded_by: null
amends: null
---

# A canonical home row has a natural key and a bundle scope, and is seeded declaratively

## Context

G12 says overlay journeys are prose rather than `vv-base` rows, and reads as an
absence: nobody has seeded them yet. The absence is real but it is not the
problem, and the problem is already in committed code.

**Two callers seed `journeys` with two different keys.**

`gems/rails-osi-level-8/lib/rails_osi_level_8/profile9/j1.rb:41`

    journey = ::Vv::Base::Journey.find_or_initialize_by(title: JOURNEY_TITLE, primary_actor_id: actor.id)

`runtimes/mind-pod/app/db/seeds.rb:22`

    journey = Journey.find_or_create_by!(title: "Assure an effect is authorized") do |j|

One keys on `(title, primary_actor_id)`, the other on `title` alone, and nothing
reconciles them: `…canonical_homes.rb:60-62` indexes `journeys` on `status`,
`primary_actor_id` and `ledger_placement`, and there is **no unique index on any
natural key**. `flows` is the same at `:72-74`. Same title with a different
actor: one path matches, the other creates a duplicate. Neither caller is wrong
against a constraint, because there is no constraint.

This is the shape ADR 0040's actor work turned out to have. G13 was not a
missing field, it was a defaulted one. G12 is not a missing seeder, it is two
disagreeing ones — and the disagreement is invisible because the schema has no
opinion.

Three more facts, each measurable:

- **No application scope.** `actors.role_key` and `information_models.key` are
  globally unique. Two applications that each seed an actor called `steward`
  collide. `ledger_placement` cannot serve: `LedgerPlaced::PLACEMENTS` is
  `canonical | sync_intent | private_local` and answers *may this cross the PULL
  boundary*, not *whose row is this*.
- **Seeding is imperative, per caller.** `j1.rb#seed!` is forty lines of
  `find_or_initialize_by` / assign / `save!` with an `unless
  model.fields.exists?` guard per field. Every application rewrites it.
- **"Pages cite those CIDs" names nothing.** `flow_steps` carries `step_key` and
  `route_key`. There is no `cid` column and no derivation rule, so G12's own
  acceptance cannot be met as written.

Meanwhile `vv-per-site` has already solved the first two for its own tree.
`OkfNode` validates `okf_path` unique **scoped to `bundle_key`**, and
`Okf::Seeder` splits export from load with a `_manifest.yml` ordered parent
before child. Its layout comment names `from_human/vision.yml` and
`generated/personas.yml`; that export has since been run against a real bundle
and produced exactly those files.

## Decision

**A canonical home row is identified by a natural key, scoped to a bundle, and
written by a loader rather than by hand.**

1. **Natural keys.** `journeys.journey_key` and `flows.flow_key`, both
   `null: false`. Unique index on `journeys.journey_key`; unique on
   `(flows.journey_id, flows.flow_key)`. This extends the discipline
   `flow_steps` already has at `(flow_id, step_key)` upward to its parents
   rather than introducing a new idea.
2. **Bundle scope.** `bundle_key` on `journeys`, `actors` and
   `information_models`, spelled as in `vv_per_site_okf_nodes`. The global
   unique indexes on `actors.role_key` and `information_models.key` become
   unique scoped to `bundle_key`.
3. **`bundle_key` is a value, not a registry.** This repo does not enumerate
   bundle keys, validate them against a list, or know what any of them mean —
   exactly as it does not for OKF nodes today.
4. **A declarative loader.** `Vv::Base::Seeder.load!(seed_root:, bundle_key:)`,
   modelled on `Vv::PerSite::Okf::Seeder`: read YAML, apply idempotently by the
   keys above, parent before child, **refuse** an unknown key rather than
   skipping it.
5. **A gate.** `tooling/cpcp/check_seed_contract.py` with a plant that must go
   red, holding two rules: no `find_or_initialize_by` / `find_or_create_by`
   against a canonical home outside the loader, and no unique index on a
   canonical home that omits `bundle_key`. Auto-discovered by `bin/sweep`, so it
   runs in `gate-main-green` with no new workflow — the route
   `check_actor_provenance.py` took.
6. **The step CID is derived, never stored.** A digest over
   `(bundle_key, journey_key, flow_key, step_key)`. A `cid` column that can
   drift from its own inputs would be this ADR's own Context in a new place.

## Why not the alternatives

**Let each application seed how it likes.** This is today, and today is two
callers disagreeing inside one repo before any overlay exists. The count only
goes up, and every increment makes the migration that fixes it larger.

**Use `ledger_placement` as the scope.** It is the nearest existing column and
it is the wrong one. Its values describe what may cross CPCP. Overloading it
with ownership would make a boundary control answer two questions and break the
one it already answers correctly.

**Have the substrate register applications.** A table of known bundle keys,
validated on write. This is ADR 0063's prohibition arriving as bookkeeping — the
substrate naming its consumers — and it is the same mistake 0063's first
amendment caught when application shapes were authored here and failed seven
gates at once. A value carried by the seed asks nothing of this repo.

**Store the step CID.** Simpler to query and one more thing that can be wrong.
Derived costs a digest and cannot drift.

## Consequences

- **`j1.rb` and `mind-pod/app/db/seeds.rb` must each name a key.** That is the
  point: after decision 1 they cannot disagree. Both become YAML plus a call,
  with no behaviour change.
- **Migrations are ordered by this ADR.** Keys and scope before loader before
  gate; the gate cannot hold rules about columns that do not exist.
- **This does not seed anything.** The loader is substrate; the rows stay each
  application's own.
- **The PULL boundary is untouched.** `bundle_key` is orthogonal to
  `ledger_placement` and neither replaces nor narrows it.
- **G12 becomes closable.** Its acceptance — *pages cite those CIDs* — acquires
  a referent it does not have today.

## Chain break, declared

`enforced_by` is empty and `unenforced: true`, because decision 5's gate does not
exist and neither do the columns it would check. The break is here, named, not
silent. Closing it means landing `check_seed_contract.py` with its plant and
filling `enforced_by`.

Until then the only thing holding decisions 1–4 is this document, which is
exactly the standing `j1.rb` and `seeds.rb` have had, and it is why they
diverged.

## What is not decided here

- **When this lands.** Nothing here argues for jumping the ordered path in
  `CANONICAL_GAPS.md` §8. The damage is bounded while only one seeder runs at a
  time; it becomes urgent when a second application seeds, which is when an
  overlay lands. Letting an overlay land first is the mistake — then the defects
  are found by an application and the fix is a migration against rows that are
  already wrong.
- **The digest function** behind decision 6. The inputs are fixed; the algorithm
  is not.
- **Whether `flow_steps` and `information_fields` also take `bundle_key`.** They
  are children and inherit scope through their parents today. If a query needs
  it denormalised, that is a later decision with evidence.
