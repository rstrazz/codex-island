import Foundation

/// How the collapsed island reads: which window the peek pill shows, and two
/// louder signals for a window that is used up or burning fast.
///
/// Defaults keep the pill as it was: session first, no extra signals.
@MainActor
final class PeekPreferenceStore: ObservableObject {
    enum Window: String, CaseIterable {
        case session, weekly

        var label: String {
            switch self {
            case .session: return "5-hour"
            case .weekly: return "Weekly"
            }
        }
    }

    static let shared = PeekPreferenceStore()

    private static let windowKey = "MacIsland.peekWindow"
    private static let limitKey = "MacIsland.peekShowsLimit"
    private static let glowKey = "MacIsland.glowOverPace"

    @Published var window: Window {
        didSet { UserDefaults.standard.set(window.rawValue, forKey: Self.windowKey) }
    }

    @Published var showsLimit: Bool {
        didSet { UserDefaults.standard.set(showsLimit, forKey: Self.limitKey) }
    }

    @Published var glowsOverPace: Bool {
        didSet { UserDefaults.standard.set(glowsOverPace, forKey: Self.glowKey) }
    }

    var prefersWeekly: Bool { window == .weekly }

    private init() {
        self.window = Pref.enumValue(key: Self.windowKey, default: .session)
        self.showsLimit = UserDefaults.standard.bool(forKey: Self.limitKey)
        self.glowsOverPace = UserDefaults.standard.bool(forKey: Self.glowKey)
    }
}
