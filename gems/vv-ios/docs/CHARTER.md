# vv-ios charter

**Job:** emit the SwiftUI shell of a Verbal-Vibes / Magentic iPhone app.

## What this gem creates

Swift. Always Swift. Specifically **SwiftUI**:

- `@main` App
- `List` / `Detail` views per domain model
- `@Observable @MainActor` view-models that switch on
  `Envelope.ok` / `Envelope.fail` from the shared actor repositories

The generated package depends on the `vv-mobile` package via
`.package(path: "../SharedKit")`.

## What this gem does not create

- Android targets
- Kotlin / Compose
- JNI / `@c` exports
- Shared domain models (those live in `vv-mobile`)

Skip is unofficial and is not used here. If you want one UI codebase on
both platforms, that is a different (non-doctrinal) experiment.

## Source

`magentic-market-ai/docs/research/Swift.md` — SwiftUI stays on Apple;
shared logic is the cross-compile unit.
