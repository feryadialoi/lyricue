import AppKit
import SwiftUI

private let savedOriginXKey = "overlayOriginX"
private let savedOriginYKey = "overlayOriginY"

final class OverlayWindowController: NSWindowController {
    let viewModel = LyricsViewModel()
    private(set) var settings: DisplaySettings!

    /// User asked to hide the window from the menu (floating and corner modes).
    var isHiddenByUser = false

    convenience init(settings: DisplaySettings) {
        let window = DraggableWindow(
            contentRect: NSRect(origin: .zero, size: OverlayLayout.floatingSize),
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
        self.settings = settings

        let rootView = ContentView(viewModel: self.viewModel, settings: settings)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.frame = window.contentView!.bounds
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "q" {
                NSApp.terminate(nil)
            }
            return event
        }

        // Remember where the user dragged the floating pill.
        NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard self?.settings.mode == .floating, let origin = window?.frame.origin else { return }
            UserDefaults.standard.set(Double(origin.x), forKey: savedOriginXKey)
            UserDefaults.standard.set(Double(origin.y), forKey: savedOriginYKey)
        }
    }

    /// Resizes, positions and shows or hides the window for the current mode.
    func applyMode() {
        guard let window = window as? DraggableWindow else { return }

        switch settings.mode {
        case .floating:
            window.allowsDrag = true
            window.setContentSize(OverlayLayout.floatingSize)
            window.setFrameOrigin(floatingOrigin(for: window))
        case .corner:
            window.allowsDrag = false
            window.setContentSize(OverlayLayout.cornerSize)
            window.setFrameOrigin(cornerOrigin(for: window))
        case .menuBar:
            window.orderOut(nil)
            return
        }

        if isHiddenByUser {
            window.orderOut(nil)
        } else {
            window.orderFront(nil)
        }
    }

    private func floatingOrigin(for window: NSWindow) -> NSPoint {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: savedOriginXKey) != nil {
            return NSPoint(x: defaults.double(forKey: savedOriginXKey),
                           y: defaults.double(forKey: savedOriginYKey))
        }
        // Default: bottom-center of main screen.
        guard let frame = NSScreen.main?.visibleFrame else { return .zero }
        return NSPoint(x: frame.midX - window.frame.width / 2, y: frame.minY + 40)
    }

    private func cornerOrigin(for window: NSWindow) -> NSPoint {
        guard let frame = NSScreen.main?.visibleFrame else { return .zero }
        let margin: CGFloat = 16
        return NSPoint(x: frame.maxX - window.frame.width - margin, y: frame.minY + margin)
    }
}

final class DraggableWindow: NSWindow {
    var allowsDrag = true

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func mouseDown(with event: NSEvent) {
        if allowsDrag { performDrag(with: event) }
    }
}
