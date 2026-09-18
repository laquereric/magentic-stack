# Swift 6.3 — why vv-ios is Apple-only

The official Android SDK ships a compiler target and Swift-Java/JNI.
It does **not** ship a SwiftUI renderer. `import SwiftUI` on Android
is out of scope for the Workgroup.

Therefore:

- `vv-ios` generates SwiftUI and lists only iOS 17 / macOS 14 platforms
- `vv-mobile` generates the UI-free package both shells consume
- `vv-android` generates the JNI/`@c` export layer, not views

Do not add an Android triple to this package's `Package.swift`.
