# Swift 6.3 Android SDK — constraints this gem encodes

Source: MagenticMarket `docs/research/Swift.md` (Ravi, "I Built an Android
App in Swift", Swift 6.3 official Android SDK).

1. Swift 6.3 ships the first **official** Swift SDK for Android
   (`aarch64-unknown-linux-android28`). Community toolchains existed
   since 2015; Apple / Swift core now own versioning and support.
2. This is **not** SwiftUI on Android. No `import SwiftUI`, no view
   hierarchy on the Android target.
3. What you get:
   - cross-compile to a native `.so` / ELF
   - Swift Java / JNI Core so Kotlin/Java can call Swift
   - shared business logic (networking, parsing, validation, MVVM
     view-models) between iOS and Android
4. Android UI remains Kotlin/Jetpack Compose (or unofficial Skip).
5. Tooling is young: no Xcode-level debugging on the Android target.

`vv-mobile` implements (3). `vv-ios` owns SwiftUI. `vv-android` owns
the JNI/`@c` export layer. None of the three emit Compose.
