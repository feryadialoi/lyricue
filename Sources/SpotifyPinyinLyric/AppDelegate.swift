import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app activates without a Dock tile at runtime.
        // Info.plist LSUIElement handles the launch-time setting;
        // this call is a belt-and-suspenders for some edge cases.
        NSApp.setActivationPolicy(.accessory)

        overlayController = OverlayWindowController()
        overlayController?.showWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
