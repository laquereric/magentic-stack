# Consumer requirements — MagenticMarket (`MM`) on `vv-android`

- Gem repo: https://github.com/laquereric/vv-android
- Depends on: `vv-mobile`
- Related (not this gem): `mm-android` Kotlin shell, `CONSUMER_REQUIREMENT_ANDROID.md` in MM

## How MM pins this gem

```ruby
gem "vv-android", git: "https://github.com/laquereric/vv-android.git"
```

## Surfaces MM consumes

- `Vv::Android::VERSION`
- `Vv::Android.generate(spec:, output_dir:)` never-raise envelope
- Generated package under `<output_dir>/AndroidKit`
- Generated Swift contains **no** `import SwiftUI`
- Generated `Package.swift` documents `--swift-sdk aarch64-unknown-linux-android28`
- Generated `@c` functions: `vv_android_abi_version`, `vv_android_model_count`
- `@_exported import` of the vv-mobile module
- Precompiled `@c` pins: `vv_android_acia_count` (19), `vv_android_aiux_count` (12), `vv_android_acia_contains`, `vv_android_aiux_contains`

## What would break MM if it changed

- Raising from `generate`
- Emitting SwiftUI
- Dropping the Android SDK triple from Package.swift / the ok envelope
- Renaming `@c` pin `vv_android_abi_version`

## What MM tolerates

- Additional `@c` pins
- jextract annotations as they stabilize
- README / Kotlin sample edits
- CLI additions
