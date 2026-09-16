# storytime application contract

Slot for StoryTime (`vv-storytime`), a Magentic Market overlay.
It consumes `shapes-level-8` protocol vocabulary and ships its
own contracts in the overlay repo (`vv-storytime/contracts/storytime/`).

Empty of TTL here, and stays that way. ADR 0063: the substrate
**names** the application; contracts stay in the overlay.

This directory names the application identifier `storytime`
and reserves it. That is all it is for.

The overlay repo is `vv-storytime` (private). That name is a
product repo, not a substrate gem — `gems/vv-storytime/` is
denied by `tooling/boundary/check_no_storytime_gem.py`.

Product contract: [`docs/architecture/plan_vv-storytime.md`](../../../../docs/architecture/plan_vv-storytime.md).
