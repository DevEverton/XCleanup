import SwiftUI
import XCleanupCore

@main
struct XCleanupApp: App {
    var body: some Scene {
        MenuBarExtra("XCleanup", systemImage: "hammer.circle") {
            Text("XCleanup — coming up")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
