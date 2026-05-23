import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayController: OverlayWindowController?
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayController = OverlayWindowController()
        overlayController?.showWindow(nil)

        setupMenuBar()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Spotify Pinyin Lyric")

        let menu = NSMenu()

        let trackItem = NSMenuItem(title: "No track playing", action: nil, keyEquivalent: "")
        trackItem.isEnabled = false
        menu.addItem(trackItem)

        menu.addItem(.separator())

        let toggleItem = NSMenuItem(title: "Hide Overlay", action: #selector(toggleOverlay), keyEquivalent: "h")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem?.menu = menu

        // Keep track item title in sync with current track.
        overlayController?.viewModel.$statusMessage
            .receive(on: RunLoop.main)
            .sink { [weak trackItem] message in
                trackItem?.title = message
            }
            .store(in: &cancellables)

        overlayController?.viewModel.$currentHanzi
            .receive(on: RunLoop.main)
            .sink { [weak trackItem, weak self] hanzi in
                guard let self, let vm = self.overlayController?.viewModel else { return }
                if !hanzi.isEmpty {
                    trackItem?.title = "\(vm.currentHanzi)"
                }
            }
            .store(in: &cancellables)
    }

    @objc private func toggleOverlay() {
        guard let window = overlayController?.window,
              let item = statusItem?.menu?.item(withTitle: "Hide Overlay") ?? statusItem?.menu?.item(withTitle: "Show Overlay") else { return }

        if window.isVisible {
            window.orderOut(nil)
            item.title = "Show Overlay"
        } else {
            window.orderFront(nil)
            item.title = "Hide Overlay"
        }
    }
}
