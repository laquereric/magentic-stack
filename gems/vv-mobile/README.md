# vv-mobile

**Home: magentic-stack (ADR 0038).** Origin: `laquereric/vv-mobile-kit`
(standalone private copy; non-authoritative).

Private gem (`vv-mobile`), hosted at
[`laquereric/vv-mobile-kit`](https://github.com/laquereric/vv-mobile-kit)
because [`laquereric/vv-mobile`](https://github.com/laquereric/vv-mobile)
is the Hotwire Native Rails app.

**Creates Swift** — a Foundation-only package that is the
shared brain of an iOS *and* Android app.

Swift 6.3's official Android SDK is not SwiftUI-on-Android. This gem
emits the layer that *does* ship on both platforms: models, repositories,
networking, validation. Platform UI lives in [`vv-ios`](https://github.com/laquereric/vv-ios)
(SwiftUI) and [`vv-android`](https://github.com/laquereric/vv-android)
(JNI / `@c` exports into a Kotlin/Compose shell).

```ruby
require "vv-mobile"

result = Vv::Mobile.generate(spec: "examples/user.yml", output_dir: "out")
# => { ok: true, written: [...], package_dir: "out/SharedKit",
#      android_sdk: "aarch64-unknown-linux-android28" }
```

```bash
bin/vv-mobile generate examples/user.yml ./out
swift build --package-path out/SharedKit
swift build --package-path out/SharedKit --swift-sdk aarch64-unknown-linux-android28
```

## Spec

```yaml
module: SharedKit
base_url: https://api.example.com
models:
  - name: User
    properties:
      - { name: id, type: String }
      - { name: name, type: String }
repositories:
  - name: UserRepository
    model: User
    collection_path: /users
    member_path: /users/{id}
```

## Precompiled catalogs

Every generated SharedKit **already holds**:

- **12 AIUX intentions** (`task.table` … `task.citation`) — jobs an agent
  puts in front of a human.
- **19 ACIA components** (`PageShell` … `ReferentBridge`, `ghis-19@1`) —
  the widgets those jobs compile into.

Unknown kinds refuse. `task.date` on `ghis-19@1` refuses
(`date_kind_missing` — date is never text). The agent names a part the
phone already shipped; no markup crosses the wire.

```ruby
Vv::Mobile.compile(task_kind: "task.empty")
# => { ok: true, document: { root: PageShell → EmptyState, … } }
```

## Doctrine

See [`docs/CHARTER.md`](docs/CHARTER.md) and [`docs/research/Swift.md`](docs/research/Swift.md).

```bash
bundle install && bundle exec rspec
```

Private tooling. `LicenseRef-DataYoursSoftwareMine-1.0`.
