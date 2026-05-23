import AppKit
import SwiftUI

/// A borderless, always-on-top floating window that hosts the lyric overlay.
final class OverlayWindowController: NSWindowController {
    private let viewModel = LyricsViewModel()

    convenience init() {
        // Build the borderless window.
        let window = DraggableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 100),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = false  // We handle dragging manually.
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        self.init(window: window)

        // Embed the SwiftUI view.
        let viewModel = self.viewModel
        let rootView = ContentView(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        // Position the window at the bottom-center of the main screen.
        positionWindow(window)

        // Allow Cmd+Q to quit the app.
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
            }
            return event
        }
    }

    private func positionWindow(_ window: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let x = screenFrame.midX - windowSize.width / 2
        let y = screenFrame.minY + 40
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// An NSWindow subclass that forwards mouse-drag events so the window can be
/// repositioned by clicking anywhere on it.
final class DraggableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        performDrag(with: event)
    }
}
