# vv-ios

**Home: magentic-stack (ADR 0038).** Origin: `laquereric/vv-ios` (standalone
private copy; non-authoritative).

Private gem. **Creates Swift** — a SwiftUI iOS/macOS shell over the
shared package emitted by [`vv-mobile`](https://github.com/laquereric/vv-mobile-kit).

Swift 6.3's Android SDK does **not** render SwiftUI. This gem is
Apple-only. Android UI is Kotlin/Compose calling into the shared `.so`
via [`vv-android`](https://github.com/laquereric/vv-android).

Precompiled into every IosApp: **12 AIUX intentions** (TaskSlot) and
**19 ACIA SwiftUI widgets** (`PageShellView` … `ReferentBridgeView`)
plus `AciaRenderer`. The agent names a kind the phone already shipped.

```ruby
require "vv-ios"

Vv::Mobile.generate(spec: "spec.yml", output_dir: "out")
Vv::Ios.generate(spec: "spec.yml", output_dir: "out")
# => { ok: true, written: [...], package_dir: "out/IosApp" }
```

```bash
bin/vv-ios generate ../vv-mobile/examples/user.yml ./out
```

```bash
bundle install && bundle exec rspec
```

Private tooling. `LicenseRef-DataYoursSoftwareMine-1.0`.
