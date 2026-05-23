import AppKit
import SwiftUI

private let savedOriginXKey = "overlayOriginX"
private let savedOriginYKey = "overlayOriginY"

final class OverlayWindowController: NSWindowController {
    let viewModel = LyricsViewModel()

    convenience init() {
        let window = DraggableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 130),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        self.init(window: window)

        let rootView = ContentView(viewModel: self.viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        positionWindow(window)

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
            }
            return event
        }

        // Save position whenever the window is moved.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            guard let origin = window?.frame.origin else { return }
            UserDefaults.standard.set(Double(origin.x), forKey: savedOriginXKey)
            UserDefaults.standard.set(Double(origin.y), forKey: savedOriginYKey)
        }
    }

    private func positionWindow(_ window: NSWindow) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: savedOriginXKey) != nil {
            let x = defaults.double(forKey: savedOriginXKey)
            let y = defaults.double(forKey: savedOriginYKey)
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            // Default: bottom-center of main screen.
            guard let screen = NSScreen.main else { return }
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            let x = screenFrame.midX - windowSize.width / 2
            let y = screenFrame.minY + 40
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
}

final class DraggableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        performDrag(with: event)
    }
}
