import Foundation

/// User preference for drawing pace on quota charts (issue #24): an even-pace
/// mark on each window and where the current burn rate lands it by reset.
///
/// Default off, so upgrading users see the charts they already know.
@MainActor
final class PaceDisplayStore: ObservableObject {
    static let shared = PaceDisplayStore()

    private static let key = "MacIsland.showPace"

    @Published var enabled: Bool {
        didSet { UserDefaults.standard.set(enabled, forKey: Self.key) }
    }

    private init() {
        self.enabled = UserDefaults.standard.bool(forKey: Self.key)
    }
}
