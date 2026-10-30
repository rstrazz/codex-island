import Foundation

/// Last-hour burst: how fast a window moved over the past hour against even
/// pace, and whether that is fast enough to flag.
@main
struct RecentBurnTests {
    static var failures = 0

    static func expect(_ condition: Bool, _ label: String) {
        if condition { print("PASS \(label)") } else { print("FAIL \(label)"); failures += 1 }
    }

    static func close(_ a: Double?, _ b: Double, _ tolerance: Double = 0.01) -> Bool {
        guard let a else { return false }
        return abs(a - b) < tolerance
    }

    static let now = Date(timeIntervalSince1970: 1_784_000_000)
    static let week = UsageWindow.weekly.span

    /// One reading every five minutes, `minutesAgo` oldest first.
    static func readings(_ points: [(minutesAgo: Double, used: Double)]) -> [RecentBurn.Reading] {
        points.map { (now.addingTimeInterval(-$0.minutesAgo * 60), $0.used) }
    }

    static func ramp(from: Double, to: Double, minutes: Int = 60) -> [RecentBurn.Reading] {
        let steps = minutes / 5
        return readings((0...steps).map { i in
            (Double(minutes - i * 5), from + (to - from) * Double(i) / Double(steps))
        })
    }

    static func burn(_ samples: [RecentBurn.Reading], used: Double? = nil,
                     resetIn: TimeInterval = 3 * 86400, span: TimeInterval = week) -> RecentBurn? {
        RecentBurn(readings: samples, usedNow: used ?? samples.last?.used ?? 0,
                   resetAt: now.addingTimeInterval(resetIn), span: span, now: now)
    }

    static func main() {
        // MARK: multiple of even pace

        // Even weekly pace is 100% / 168h ≈ 0.6 points an hour.
        let hard = burn(ramp(from: 0.30, to: 0.33))
        expect(close(hard?.multiple, 5.04), "3 points in an hour is about 5× even weekly pace")
        expect(hard?.isBurning == true, "5× and 3 points is a burst")

        let steady = burn(ramp(from: 0.30, to: 0.31))
        expect(steady?.isBurning == false, "1 point in an hour is not a burst")

        // MARK: both bars must clear

        let fiveHour = UsageWindow.fiveHour.span
        let sessionCrawl = burn(ramp(from: 0.10, to: 0.30), resetIn: 3 * 3600, span: fiveHour)
        expect(close(sessionCrawl?.multiple, 1.0), "20 points an hour is even pace for the 5-hour window")
        expect(sessionCrawl?.isBurning == false, "even pace on the 5-hour window is not a burst")

        // A weekly limit moves in whole points: one step after a quiet half hour
        // is 3× on paper but not a burst.
        let oneStep = burn(readings([(31, 0.30), (30, 0.30), (5, 0.30), (0, 0.31)]))
        expect(oneStep?.isBurning == false, "one point is under the two-point floor")

        // MARK: enough history

        expect(burn(ramp(from: 0.30, to: 0.33, minutes: 20)) == nil, "under half an hour of readings is no reading")
        expect(burn([]) == nil, "no readings, no burst")
        let gap = readings([(90, 0.20), (85, 0.25), (0, 0.30)])
        expect(burn(gap) == nil, "readings older than the lookback don't count")

        // MARK: a reset inside the hour

        let afterReset = readings([(60, 0.90), (55, 0.95), (40, 0.00), (20, 0.01), (5, 0.03), (0, 0.04)])
        let reset = burn(afterReset, resetIn: week - 40 * 60)
        expect(close(reset?.multiple, 0.04 / (40.0 / 60) / (1.0 / 168)), "only readings after a reset count")
        expect(reset?.isBurning == true, "4 points in the 40 minutes since reset is a burst")

        // MARK: a hit limit

        let capped = burn(readings([(60, 0.95), (40, 0.98), (20, 1.0), (0, 1.0)]), used: 1.0)
        expect(capped == nil, "a hit limit shows no burst")

        // MARK: an account switch

        let switched = readings([(60, 0.10), (55, 0.10), (50, 0.60), (25, 0.60), (5, 0.60), (0, 0.61)])
        let afterSwitch = burn(switched)
        expect(afterSwitch?.isBurning == false, "a jump from another account's reading is not a burst")
        expect(close(afterSwitch?.gained, 0.01), "only readings after the jump count")
        let sessionRush = burn(ramp(from: 0.20, to: 0.80), resetIn: 3 * 3600, span: UsageWindow.fiveHour.span)
        expect(sessionRush?.isBurning == true, "5 points a poll on the 5-hour window is still a real burst")

        // MARK: runs out

        let runaway = burn(ramp(from: 0.80, to: 0.90), resetIn: 86400)
        expect(close(runaway?.runsOutAt?.timeIntervalSince(now), 3600, 1), "10 points an hour from 90% runs out in an hour")
        expect(close(hard?.runsOutAt?.timeIntervalSince(now), 67.0 / 3 * 3600, 60), "3 points an hour from 33% runs out in about 22 hours")
        expect(burn(ramp(from: 0.30, to: 0.33), resetIn: 12 * 3600)?.runsOutAt == nil,
               "3 points an hour from 33% makes it to a reset 12 hours out")

        print(failures == 0 ? "ALL PASS" : "\(failures) FAILURE(S)")
        exit(failures == 0 ? 0 : 1)
    }
}
