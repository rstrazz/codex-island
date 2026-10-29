import Foundation

/// Where a window's current burn rate lands it by reset, and where spending
/// evenly would put it right now. All fractions are 0...1 like
/// `WindowUsage.usedPercent`; a projection can run past 1.
struct WindowPace: Equatable {
    enum Level { case onPace, tight, over }

    let usedFraction: Double
    let evenPaceFraction: Double
    let projectedFraction: Double
    let exhaustsAt: Date?
    let lowConfidence: Bool

    var limitHit: Bool { usedFraction >= 1 }

    /// Nothing used yet or already out: no figure worth showing. Early in a
    /// window the figure still shows, marked rough (`lowConfidence`), since a
    /// fast start is exactly what's worth seeing.
    var showsProjection: Bool { usedFraction > 0 && !limitHit }

    /// The projection as a whole percent for the used/remaining mode, capped at
    /// 999 so a runaway early rate can't print four digits. Not clamped to 100:
    /// over 100 is the whole point of the warning.
    func projectedPercent(mode: UsageDisplayMode) -> Int {
        let fraction = mode == .used ? projectedFraction : max(0, 1 - projectedFraction)
        return Int((min(fraction, 9.99) * 100).rounded())
    }

    var level: Level {
        if limitHit || projectedFraction > 1 { return .over }
        return projectedFraction > 0.85 ? .tight : .onPace
    }

    init?(usage: WindowUsage, span: TimeInterval, now: Date = Date()) {
        guard usage.hasPercentageReading, !usage.isUnlimitedAmount,
              let resetAt = usage.resetAt, resetAt > now, span > 0 else { return nil }

        let rawElapsed = min(span, max(0, span - resetAt.timeIntervalSince(now)))
        // Two minutes into a window, used / elapsed is arithmetically right and
        // useless, so extrapolate from at least 5% of it.
        let elapsed = max(rawElapsed, span * 0.05)
        let used = usage.usedPercent
        let rate = used / elapsed
        let exhaust = rate > 0 ? now.addingTimeInterval(max(0, 1 - used) / rate) : nil

        usedFraction = used
        evenPaceFraction = rawElapsed / span
        projectedFraction = used / (elapsed / span)
        exhaustsAt = exhaust.flatMap { $0 < resetAt ? $0 : nil }
        lowConfidence = rawElapsed < span * 0.12
    }
}
