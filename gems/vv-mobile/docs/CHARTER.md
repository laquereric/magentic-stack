# vv-mobile charter

**Job:** emit the shared Swift *brain* of a Verbal-Vibes / Magentic mobile app.

## Precompiled catalogs

The mobile client **ships** the closed catalogs. Generate always emits
them, even when the YAML spec has no models:

| Catalog | Count | Closed set |
|---|---|---|
| AIUX intentions | 12 | `task.table` `form` `date` `confirm` `status` `error` `empty` `approval` `preview` `choice` `progress_steps` `citation` |
| ACIA components | 19 | `PageShell` … `ReferentBridge` (`ghis-19@1`) |

Compile is F4: intention → ACIA tree. Date on ghis-19 refuses.

## What this gem creates

Swift. Always Swift. A Swift package named from the spec's `module`
(default `SharedKit`) that contains:

- `Codable, Sendable` domain models
- `actor` repositories
- `URLSession` networking
- `Envelope` / `Failure(reason:because:)` — the MM never-raise shape

The same package is compiled twice:

```bash
swift build                                          # iOS / macOS
swift build --swift-sdk aarch64-unknown-linux-android28   # Android
```

## What this gem does not create

- SwiftUI, UIKit, AppKit, or any view hierarchy
- Kotlin / Jetpack Compose
- JNI thunks (that is `vv-android`)
- An iOS app target (that is `vv-ios`)

Swift 6.3's official Android SDK is **not** SwiftUI-on-Android. UI is
explicitly out of scope for the Android Workgroup. Shared logic is the
whole point: stop rewriting validation, API clients, and domain models
in Kotlin every sprint.

Skip (SwiftUI→Compose) is a separate, unofficial project and is not a
dependency of this gem.

## Sister gems

| Gem | Swift it creates |
|---|---|
| `vv-mobile` (this) | Shared Foundation package |
| `vv-ios` | SwiftUI shell that imports the shared package |
| `vv-android` | `@c` / Swift-Java JNI export layer over the shared package |

## Source

Doctrine distilled from `magentic-market-ai/docs/research/Swift.md`
(Swift 6.3 official Android SDK, Swift Android Workgroup, March 2026).
