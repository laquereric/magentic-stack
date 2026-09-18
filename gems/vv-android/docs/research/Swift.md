# Swift 6.3 Android SDK — constraints this gem encodes

1. Official SDK triple: `aarch64-unknown-linux-android28`.
2. Output is a native `.so` / ELF, not a SwiftUI view tree.
3. Kotlin/Java call in through Swift Java / JNI Core (`jextract`,
   `wrap-java`) or a C ABI. This gem pins `@c` functions for bring-up
   and re-exports SharedKit for jextract.
4. Compose (or unofficial Skip) is the UI. This gem does not emit it.
5. Tooling is young — no Xcode-level Android debugging assumed.
