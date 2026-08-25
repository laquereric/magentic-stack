# vv-base  (PRIVATE)

Canonical ActiveRecord homes for **Actor, Persona, Journey, Flow, Mission,
Vision** — platform models that were sitting in
`runtimes/mind-pod/app/app/models` because they needed a home. Each of the
six already said so in a comment: *canonical home, shared by P9 GHIS and
P10 INTENT*.

`Note` and `Reconciliation` stay in mind-pod. They are that pod's data.
Controllers stay in the app.

## Namespacing

Models live at `Vv::Base::Actor` (etc.), inheriting from `Vv::Base::Record`,
**not** from the host's `ApplicationRecord`. A gem that defines
`::ApplicationRecord` is stealing the host.

Top-level `Actor` is opt-in — friendlier to existing mind-pod specs, and a
collision waiting to happen in the next app. Call once at boot:

```ruby
Vv::Base.install_bare_constants!
# => { ok: true, installed: ["Actor", …] }
# collision: { ok: false, reason: :constant_exists, because: ["Actor"] }
```

Never-raise. No `Dry::Monads`.

## Schema

This is a Rails engine. Table names are **unprefixed** (`actors`,
`journeys`, …) so existing mind-pod databases keep working. There is no
`isolate_namespace`. Hosts run the engine migration; do not create tables
from an initializer.

`ledger_placement` is in the create migration, not a follow-up.

## LedgerPlaced

`private_local` never crosses a CPCP PULL boundary. The `cross_boundary`
scope is unchanged: it is still something the caller must use. `.all`
still includes `private_local` — BACK has to see those rows in-process.
A default_scope would have hidden them from the writer and changed
semantics silently.

PULL adapters should go through the named API:

```ruby
Vv::Base::Pull.relation(Vv::Base::Mission)
# => { ok: true, relation: <Mission.cross_boundary> }
```

That does not make bypass impossible (`.unscoped` / `.all` still exist).
It makes the boundary a method you call instead of a scope you forget.

## What this gem does not do

- Does not reach for `RailsCpcp` (none of the six had `as_api`).
- Does not wire itself into `rails-base`. That needs a base rebuild.
- Does not move `note.rb` or `reconciliation.rb`.

## Specs

```
bundle exec rspec
```

Temp SQLite in process. No host app required.
