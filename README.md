# vv-docker-swap

**Layer sharing for closely related Rails service images, as rules you can check.**

Ten Rails services that share a codebase and differ by one to three gems should
not cost ten times the disk. They should **swap in one immutable common parent
image** -- Ruby runtime, OS libraries, and the common bundle -- and each build
`FROM` that exact parent digest. Docker stores a layer once per host no matter
how many images reference it, so the base and common-gem layers are paid for
once and each service adds only its delta gems, its code, and its writable layer.

Grounding: [`docs/rails_image_optimization.md`](docs/rails_image_optimization.md).

## The invariant that fails silently

> The key is not merely having similar Dockerfiles. Every service must inherit
> from the **same parent image digest** and must preserve exactly the **same gem
> versions** for common dependencies.

Both halves fail quietly. Similar-looking Dockerfiles still build. A drifted
common gem still resolves. Nothing errors -- you simply do not get the sharing
you designed for, and you find out from a disk graph weeks later.
`SharingInvariant` makes that loud and specific:

```ruby
Image = Vv::DockerSwap::SharingInvariant::Image

Vv::DockerSwap::SharingInvariant.verify([
  Image.new(name: "billing", parent: "registry/acme/rails-common@sha256:aaa...",
            commons: { "rails" => "7.2.1", "pg" => "1.5.4" }),
  Image.new(name: "ledger",  parent: "registry/acme/rails-common@sha256:aaa...",
            commons: { "rails" => "7.2.2", "pg" => "1.5.4" })
])
# => { ok: true, shares: false, violations: [
#      { rule: :common_gem_version_drift, gem: "rails", versions: ["7.2.1", "7.2.2"],
#        because: "rails resolves to 2 different versions ..." } ] }
```

It also rejects a **floating parent tag** even when every image agrees on it:
`:latest` can change bytes underneath a child that never changed.

## The arithmetic that makes the win look like a loss

`docker system df -v` reports `SHARED SIZE` and `UNIQUE SIZE`, and Docker's
displayed `SIZE` is their sum. So **adding up image sizes double-counts every
shared byte** -- precisely the bytes this design exists to store once. For ten
thin children on one common parent, the naive sum overstates real disk by
**7.35x**:

```ruby
Image = Vv::DockerSwap::Accounting::Image
fam = (1..10).map { |i| Image.new(name: "svc#{i}",
                                  layers: { "base" => 800, "gems" => 400, "code#{i}" => 50 }) }

Vv::DockerSwap::Accounting.total_disk(fam)  # => { ok: true, bytes: 1700, layer_count: 12 }
Vv::DockerSwap::Accounting.naive_sum(fam)   # => { ok: true, bytes: 12_500 }
Vv::DockerSwap::Accounting.overcount(fam)   # => { bytes: 10_800, ratio: 7.35, ... }
```

The honest unit is the **layer**, which is what
`docker image inspect --format '{{json .RootFS.Layers}}'` gives you. Bytes count
once per distinct layer id. A layer id reported at two different sizes is
refused, not silently resolved -- a content-addressed layer cannot have two.

## Modules

| Module | Answers |
|---|---|
| `Strategy` | One superset image, or a common base with thin children? Independent release or conflicting deps force the base; a modest non-conflicting delta favours the superset. |
| `SharingInvariant` | Will these images actually share? Names `:floating_parent_tag`, `:parent_digest_mismatch`, `:common_gem_version_drift`. |
| `BuildRules` | Does the build preserve the cache and the layers? Dependency copy before source; build-only packages purged in the **same** `RUN`. |
| `Accounting` | What does this really cost on disk? Layer-union math, plus the naive sum exposed as the trap it is. |
| `Expectations` | What does sharing buy? Disk, pull bandwidth, build time -- **not RAM**. |

## Two rules worth stating outright

**A later purge does not shrink an earlier layer.** Build-only packages must be
removed inside the same `RUN` that installs them; a cleanup step further down
adds a layer, it does not reclaim bytes already committed.

**This buys disk and bandwidth, not RAM.** `Expectations` keeps `:ram` in
`DOES_NOT_OPTIMIZE`, and a spec asserts it stays there, so a refactor cannot
quietly promote it. RAM is still sized by the Puma processes, workers, and
databases that actually run.

## Boundary shape

Every public entry point returns the substrate's never-raise envelope --
`{ ok: true, ... }` or `{ ok: false, reason:, because: }`. No `Dry::Monads`.
Refusals are used where an answer would have to be invented: an unclassified
package, an unknown resource, a single image asked to prove sharing, a layer id
with two sizes.

## Test

```bash
bundle install
LANG=en_US.UTF-8 bundle exec rspec   # 38 examples, 0 failures
```

## License

Apache-2.0 (see `LICENSE`).
