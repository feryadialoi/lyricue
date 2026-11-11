import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = DisplaySettings()
    private var overlayController: OverlayWindowController?
    private var statusItem: NSStatusItem?
    private var tickerView: NSView?
    private var toggleItem: NSMenuItem?
    private var modeItems: [DisplayMode: NSMenuItem] = [:]
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayController = OverlayWindowController(settings: settings)

        setupMenuBar()
        applyMode()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let menu = NSMenu()

        let trackItem = NSMenuItem(title: "No track playing", action: nil, keyEquivalent: "")
        trackItem.isEnabled = false
        menu.addItem(trackItem)

        menu.addItem(.separator())

        let displayItem = NSMenuItem(title: "Display", action: nil, keyEquivalent: "")
        let displayMenu = NSMenu()
        for mode in DisplayMode.allCases {
            let item = NSMenuItem(title: mode.title, action: #selector(selectMode(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = mode.rawValue
            displayMenu.addItem(item)
            modeItems[mode] = item
        }
        displayItem.submenu = displayMenu
        menu.addItem(displayItem)

        let toggleItem = NSMenuItem(title: "Hide Overlay", action: #selector(toggleOverlay), keyEquivalent: "h")
        toggleItem.target = self
        menu.addItem(toggleItem)
        self.toggleItem = toggleItem

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

    @objc private func selectMode(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let mode = DisplayMode(rawValue: raw) else { return }
        settings.mode = mode
        applyMode()
    }

    /// Syncs the window, the menu bar item and the menu checkmarks with the current mode.
    private func applyMode() {
        let mode = settings.mode
        for (itemMode, item) in modeItems {
            item.state = itemMode == mode ? .on : .off
        }
        toggleItem?.isHidden = mode == .menuBar

        overlayController?.applyMode()

        guard let button = statusItem?.button else { return }
        if mode == .menuBar {
            if tickerView == nil, let vm = overlayController?.viewModel {
                let ticker = PassthroughHostingView(rootView: MenuBarTicker(viewModel: vm))
                ticker.frame = NSRect(x: 4, y: 0, width: TickerLayout.width, height: button.bounds.height)
                ticker.autoresizingMask = [.height]
                button.addSubview(ticker)
                tickerView = ticker
            }
            button.image = nil
            statusItem?.length = TickerLayout.width + 8
        } else {
            tickerView?.removeFromSuperview()
            tickerView = nil
            button.image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Lyricue")
            statusItem?.length = NSStatusItem.variableLength
        }
    }

    @objc private func toggleOverlay() {
        guard let controller = overlayController else { return }
        controller.isHiddenByUser.toggle()
        toggleItem?.title = controller.isHiddenByUser ? "Show Overlay" : "Hide Overlay"
        controller.applyMode()
    }
}
