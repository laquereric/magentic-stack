# vv-android

**Home: magentic-stack (ADR 0038).** Origin: `laquereric/vv-android`
(standalone private copy; non-authoritative).

Private gem. **Creates Swift** — a dynamic library + `@c` JNI pins for
the official Swift 6.3 Android SDK, over the shared package emitted by
[`vv-mobile`](https://github.com/laquereric/vv-mobile-kit).

This is **not** SwiftUI-on-Android. UI stays Kotlin/Jetpack Compose.
The `.so` is the brain; Compose renders it.

Precompiled into every AndroidKit: **12 AIUX intentions** and **19 ACIA
components** (`vv_android_acia_count` / `vv_android_aiux_count` /
`vv_android_*_contains`). Kotlin maps those names onto Compose; it does
not invent kinds. `AiuxCompiler` in SharedKit is the F4 compile.

```ruby
require "vv-android"

Vv::Mobile.generate(spec: "spec.yml", output_dir: "out")
Vv::Android.generate(spec: "spec.yml", output_dir: "out")
# => { ok: true, package_dir: "out/AndroidKit",
#      android_sdk: "aarch64-unknown-linux-android28" }
```

```bash
bin/vv-android generate ../vv-mobile/examples/user.yml ./out
swift build --package-path out/AndroidKit --swift-sdk aarch64-unknown-linux-android28
```

Sister: [`vv-ios`](https://github.com/laquereric/vv-ios) (SwiftUI, Apple-only).

```bash
bundle install && bundle exec rspec
```

Private tooling. `LicenseRef-DataYoursSoftwareMine-1.0`.
