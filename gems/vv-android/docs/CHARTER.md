# vv-android charter

**Job:** emit the Swift Android *export* of a Verbal-Vibes / Magentic
mobile app — the `.so` Kotlin loads.

## What this gem creates

Swift. Always Swift. Specifically:

- a `dynamic` library target (`AndroidKit`)
- `@_exported import SharedKit` so swift-java jextract sees one module
- Swift 6.3 `@c` ABI pins (`vv_android_abi_version`, per-model names)
- `Package.swift` documenting `--swift-sdk aarch64-unknown-linux-android28`

## What this gem does not create

- SwiftUI / UIKit / AppKit
- Jetpack Compose screens (Kotlin owns those)
- A rewrite of domain models (those live in `vv-mobile`)
- A Skip-based UI transpiler

## Call path

```
Kotlin/Compose  --JNI / jextract-->  AndroidKit.so  --@_exported-->  SharedKit
```

Same SharedKit binary shape as iOS. One spec, two compile triples.

## Source

`magentic-market-ai/docs/research/Swift.md` — official Swift 6.3
Android SDK, Swift Java / JNI Core, UI out of scope for the Workgroup.
