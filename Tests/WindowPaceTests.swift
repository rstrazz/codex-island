import Foundation

/// Pace projection (issue #24): where the current burn rate lands a window by
/// its reset, and where even spending would put it right now.
@main
struct WindowPaceTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ label: String) {
        if condition { print("PASS \(label)") } else { print("FAIL \(label)"); failures += 1 }
    }

    static func close(_ a: Double?, _ b: Double, _ tolerance: Double = 0.0001) -> Bool {
        guard let a else { return false }
        return abs(a - b) < tolerance
    }

    static let now = Date(timeIntervalSince1970: 1_784_000_000)
    static let week = UsageWindow.weekly.span

    static func pace(_ used: Double, elapsed: TimeInterval, span: TimeInterval = week) -> WindowPace? {
        WindowPace(
            usage: WindowUsage(usedPercent: used, resetAt: now.addingTimeInterval(span - elapsed), error: nil),
            span: span, now: now
        )
    }

    static func main() {
        // MARK: projection is used / elapsed fraction

        let half = pace(0.30, elapsed: week / 2)
        expect(close(half?.projectedFraction, 0.60), "30% halfway through the week lands at 60%")
        expect(close(half?.evenPaceFraction, 0.50), "even pace halfway through is 50%")
        expect(half?.level == .onPace, "60% projected is on pace")
        expect(half?.exhaustsAt == nil, "a pace that lands under 100% never runs out")

        expect(pace(0.425, elapsed: week / 2)?.level == .onPace, "85% projected is still on pace")
        expect(pace(0.46, elapsed: week / 2)?.level == .tight, "92% projected is tight")

        let fast = pace(0.40, elapsed: 86400)
        expect(close(fast?.projectedFraction, 2.80), "40% after one day projects 280%")
        expect(fast?.level == .over, "280% projected is over pace")
        expect(close(fast?.exhaustsAt?.timeIntervalSince(now), 129_600, 1),
               "40% after one day runs out a day and a half later")

        // MARK: early-window guard

        let sliver = pace(0.01, elapsed: week * 0.005)
        expect(close(sliver?.projectedFraction, 0.20), "the first sliver extrapolates from at least 5% of the window")
        expect(sliver?.lowConfidence == true, "under 12% of the window is low confidence")
        expect(half?.lowConfidence == false, "halfway is not low confidence")

        // MARK: limit hit

        let out = pace(1.0, elapsed: week * 5 / 7)
        expect(out?.limitHit == true, "100% used is a hit limit")
        expect(out?.level == .over, "a hit limit reads as over")
        expect(half?.limitHit == false, "60% projected has not hit the limit")
        expect(out?.showsProjection == false, "a hit limit shows no projection")

        // MARK: projection text needs something to extrapolate

        expect(half?.showsProjection == true, "30% halfway shows a projection")
        expect(sliver?.showsProjection == true, "the first sliver of a window still shows a (rough) projection")
        let morning = pace(0.05, elapsed: 7 * 3600)
        expect(morning?.showsProjection == true && morning?.lowConfidence == true,
               "5% seven hours into the week shows a projection, marked low confidence")
        expect(close(morning?.projectedFraction, 1.00), "5% seven hours into the week projects 100% (extrapolated from the 5% floor)")

        // MARK: the displayed figure (panel caption and peek pill share it)

        let early = pace(0.06, elapsed: 8 * 3600)
        expect(early?.projectedPercent(mode: .used) == 120, "6% early in the week reads 120%, not clamped to 100%")
        expect(early?.projectedPercent(mode: .remaining) == 0, "remaining never reads below 0%")
        expect(pace(0.5, elapsed: week * 0.05)?.projectedPercent(mode: .used) == 999, "a runaway rate caps at 999%")
        expect(half?.projectedPercent(mode: .remaining) == 40, "60% projected leaves 40% in remaining mode")
        let idle = pace(0, elapsed: 3 * 3600, span: UsageWindow.fiveHour.span)
        expect(idle?.showsProjection == false, "0% used shows no projection")
        expect(close(idle?.evenPaceFraction, 0.60), "0% used still has an even-pace mark")

        // MARK: works for the 5-hour window too

        let session = pace(0.50, elapsed: 2.5 * 3600, span: UsageWindow.fiveHour.span)
        expect(close(session?.projectedFraction, 1.0), "50% halfway through the 5-hour window lands at 100%")

        // MARK: no pace without a reading and a live reset

        expect(WindowPace(usage: WindowUsage(usedPercent: 0, resetAt: now.addingTimeInterval(3600), error: "HTTP 500"),
                          span: week, now: now) == nil, "a failed fetch has no pace")
        expect(WindowPace(usage: WindowUsage(usedPercent: 0.3, resetAt: nil, error: nil),
                          span: week, now: now) == nil, "no reset time, no pace")
        expect(WindowPace(usage: WindowUsage(usedPercent: 0.3, resetAt: now.addingTimeInterval(-60), error: nil),
                          span: week, now: now) == nil, "a reset already passed has no pace")
        expect(WindowPace(usage: WindowUsage(usedPercent: 0, resetAt: now.addingTimeInterval(3600), error: nil,
                                             usedAmount: 12, limitAmount: nil),
                          span: week, now: now) == nil, "unlimited credit amounts have no pace")

        print(failures == 0 ? "ALL PASS" : "\(failures) FAILURE(S)")
        exit(failures == 0 ? 0 : 1)
    }
}
