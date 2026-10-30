import Foundation

/// How fast a window moved over the last hour, against even pace for that
/// window. The weekly projection averages the whole window; this is what the
/// user is doing right now, so a burst shows while there is still time to ease
/// off.
struct RecentBurn: Equatable {
    typealias Reading = (at: Date, used: Double)

    /// Times even pace: 1 spends exactly the window by reset.
    let multiple: Double
    /// Fraction of the window gained over the lookback.
    let gained: Double
    /// When this hour's rate would use the window up, if before reset.
    let runsOutAt: Date?

    /// Weekly limits report whole points, so one step after a quiet half hour
    /// reads as 3× on paper. Two points is the floor for a real burst.
    var isBurning: Bool { multiple >= 3 && gained >= 0.02 }

    /// More than any single poll plausibly adds, even on a five-hour window.
    static let maximumStep = 0.25

    /// - Parameter readings: oldest first, `used` as a 0...1 fraction.
    init?(
        readings: [Reading],
        usedNow: Double,
        resetAt: Date?,
        span: TimeInterval,
        now: Date = Date(),
        // "Last hour" with slack: readings land every five minutes, so the one
        // nearest an hour ago can sit a little past it.
        lookback: TimeInterval = 75 * 60,
        minimumSpan: TimeInterval = 30 * 60
    ) {
        // At a hit limit the countdown to reset is what matters, not the rate.
        guard span > 0, usedNow < 1 else { return nil }
        var recent = readings.filter { now.timeIntervalSince($0.at) <= lookback }
        // A reset drops `used` and an account switch can jump it; history isn't
        // per account, so only readings since the last break are this window.
        if let cut = recent.indices.dropFirst().last(where: {
            let step = recent[$0].used - recent[$0 - 1].used
            return step < 0 || step > Self.maximumStep
        }) {
            recent.removeFirst(cut)
        }
        guard let first = recent.first, let last = recent.last else { return nil }
        let elapsed = last.at.timeIntervalSince(first.at)
        guard elapsed >= minimumSpan else { return nil }

        gained = max(0, last.used - first.used)
        let rate = gained / elapsed
        multiple = rate / (1 / span)
        if rate > 0, let resetAt {
            let out = now.addingTimeInterval(max(0, 1 - usedNow) / rate)
            runsOutAt = out < resetAt ? out : nil
        } else {
            runsOutAt = nil
        }
    }
}
