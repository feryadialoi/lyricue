import SwiftUI
import AppKit

@main
struct SpotifyPinyinLyricApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We use a custom NSWindow via AppDelegate, so no SwiftUI scene window is needed.
        // We must still provide at least one scene; use Settings with no content to suppress
        // any automatic window creation while keeping @main happy.
        Settings {
            EmptyView()
        }
    }
}
