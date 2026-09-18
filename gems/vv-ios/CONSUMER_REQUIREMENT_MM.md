# Consumer requirements — MagenticMarket (`MM`) on `vv-ios`

- Gem repo: https://github.com/laquereric/vv-ios
- Depends on: `vv-mobile`
- Doctrine: `docs/research/Swift.md`

## How MM pins this gem

```ruby
gem "vv-ios", git: "https://github.com/laquereric/vv-ios.git"
```

## Surfaces MM consumes

- `Vv::Ios::VERSION`
- `Vv::Ios.generate(spec:, output_dir:)` never-raise envelope
- Generated package under `<output_dir>/IosApp`
- Generated Swift **does** `import SwiftUI` and `import <SharedKit>`
- Generated `Package.swift` has **no** Android SDK triple
- View-models switch on `Envelope` rather than `try`
- Precompiled SwiftUI: 19 `*View` types, `AciaRenderer`, `TaskSlotView`, `CatalogGalleryView`

## What would break MM if it changed

- Raising from `generate`
- Emitting an Android target
- Dropping the `../SharedKit` (module-name) path dependency
- Replacing Envelope switching with throwing APIs

## What MM tolerates

- Extra views / accessibility modifiers
- `@Observable` vs `ObservableObject` as long as views still compile
- CLI additions
