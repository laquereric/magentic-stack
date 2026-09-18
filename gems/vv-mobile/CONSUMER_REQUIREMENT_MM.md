# Consumer requirements — MagenticMarket (`MM`) on `vv-mobile`

This file is MM's perspective on `vv-mobile`. Drift between this file
and the gem's actual behaviour is a paired-PR signal.

- Gem repo: https://github.com/laquereric/vv-mobile-kit
  (`vv-mobile` is the Ruby gem name; GitHub `laquereric/vv-mobile` is the
  Hotwire Native Rails app and is a different product.)
- Sisters: `vv-ios`, `vv-android`
- Doctrine: `docs/research/Swift.md`

## How MM pins this gem

Private git source (not rubygems.org):

```ruby
gem "vv-mobile", git: "https://github.com/laquereric/vv-mobile-kit.git"
```

During co-evolution, a path source from a sibling checkout is allowed.

## Surfaces MM consumes

- `Vv::Mobile::VERSION`
- `Vv::Mobile.generate(spec:, output_dir:)` never-raise envelope
  `{ ok: true, written:, count:, package_dir:, android_sdk: }` /
  `{ ok: false, reason:, because: }`
- `Vv::Mobile::Spec.parse` — Hash / YAML / path
- Generated Swift package under `<output_dir>/SharedKit` (or spec module name)
- Generated Swift contains **no** `import SwiftUI` / `UIKit` / `AppKit`
- Generated `Package.swift` documents `--swift-sdk aarch64-unknown-linux-android28`
- Generated `Envelope` / `Failure` with `reason` + `because`
- Precompiled catalogs: 12 `AiuxIntention` cases and 19 `AciaComponent.ghis19` widgets
- `Vv::Mobile.compile(task_kind:)` and generated `AiuxCompiler.compile`
- `date_kind_missing` when `task.date` is compiled against `ghis-19@1`

## What would break MM if it changed

- Raising from `generate` instead of returning the envelope
- Emitting SwiftUI in the shared package
- Renaming the Android SDK triple
- Dropping `written` / `package_dir` from the ok envelope

## What MM tolerates

- Additional generated files (tests, README)
- Extra Codable helpers
- Template formatting changes that keep the public Swift types stable
- CLI flag additions that do not change `generate`'s positional meaning
