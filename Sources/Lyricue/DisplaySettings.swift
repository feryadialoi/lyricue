import Foundation
import Combine

/// Where the lyrics are shown.
enum DisplayMode: String, CaseIterable {
    case floating   // draggable pill, bottom-center by default
    case corner     // larger card pinned to the bottom-right corner
    case menuBar    // scrolling ticker in the menu bar

    var title: String {
        switch self {
        case .floating: return "Floating"
        case .corner: return "Corner"
        case .menuBar: return "Menu Bar"
        }
    }
}

private let displayModeKey = "displayMode"

@MainActor
final class DisplaySettings: ObservableObject {
    @Published var mode: DisplayMode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: displayModeKey) }
    }

    init() {
        let saved = UserDefaults.standard.string(forKey: displayModeKey)
        mode = saved.flatMap(DisplayMode.init(rawValue:)) ?? .floating
    }
}
