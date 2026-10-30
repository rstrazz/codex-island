import SwiftUI
import AppKit

struct QuotaChartReading: Identifiable {
    let id: String
    let label: String
    let value: Double?
    let caption: String
    var amount: String? = nil
    var history: [Double] = []
    var pace: WindowPace? = nil
    var burn: RecentBurn? = nil

    /// "5× · out in 9h" while the last hour ran hot, for the caption line.
    var burstText: String? {
        guard let burn, burn.isBurning else { return nil }
        let multiple = Int(burn.multiple.rounded())
        guard let out = burn.runsOutAt else { return L10n.tr("%d×", multiple) }
        return L10n.tr("%d× · out in %@", multiple, Duration.compact(max(0, out.timeIntervalSinceNow)))
    }

    /// Even-pace position on the 0...100 scale the chart draws, in the
    /// current used/remaining mode.
    func paceMark(mode: UsageDisplayMode) -> Double? {
        guard let pace else { return nil }
        return (mode == .used ? pace.evenPaceFraction : 1 - pace.evenPaceFraction) * 100
    }

    /// Projected fill past the used portion. Remaining mode has no meaningful
    /// ghost — the bar already shrinks toward it — so it shows only the mark.
    func projectedFill(mode: UsageDisplayMode) -> Double? {
        guard mode == .used, let pace, !pace.limitHit, pace.projectedFraction > pace.usedFraction else { return nil }
        return min(1, pace.projectedFraction) * 100
    }
}

struct PaceMark: View {
    var height: CGFloat = 8

    var body: some View {
        Capsule().fill(.white.opacity(0.8)).frame(width: 2, height: height)
    }
}

struct QuotaValue: View {
    let reading: QuotaChartReading
    let mode: UsageDisplayMode
    var size: CGFloat = 21
    var weight: Font.Weight = .medium

    private var font: Font { .system(size: size, weight: weight, design: .monospaced) }

    var body: some View {
        ZStack(alignment: .leading) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("100").font(font)
                Text("%").font(Typography.micro)
            }
            .hidden().accessibilityHidden(true)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if let value = reading.value {
                    Text("\(DisplayNumber.percent(value))")
                        .font(font)
                        .foregroundStyle(UrgencyColor.value(value, mode: mode))
                        .numericTransition(value: Double(DisplayNumber.percent(value)))
                } else {
                    Text(verbatim: reading.amount == nil ? "-" : "∞").font(font).foregroundStyle(.white.opacity(0.55))
                }
                Text("%")
                    .font(Typography.micro)
                    .foregroundStyle(.white.opacity(0.6))
                    .opacity(reading.value == nil ? 0 : 1)
            }
        }
        .fixedSize()
    }
}

struct QuotaCaption: View {
    let caption: String
    var burst: String? = nil

    var body: some View {
        Group {
            if let burst {
                // Narrow tiles can't fit both; the burst is the more urgent one.
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        burstLabel(burst)
                        Spacer(minLength: 0)
                        captionText.fixedSize()
                    }
                    burstLabel(burst)
                }
            } else {
                captionText
            }
        }
        .font(Typography.caption)
        .lineLimit(1)
    }

    private var captionText: some View {
        Text(caption)
            .foregroundStyle(.white.opacity(0.6))
            .truncationMode(.tail)
            .help(caption)
    }

    private func burstLabel(_ burst: String) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill").imageScale(.small)
            Text(burst)
        }
        .foregroundStyle(UrgencyColor.amber)
        .fixedSize()
    }
}

struct QuotaAccessibility: ViewModifier {
    let reading: QuotaChartReading
    let mode: UsageDisplayMode

    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(reading.amount.map {
                L10n.tr("%@, %@ credits used, unlimited", reading.label, $0)
            } ?? reading.value.map {
                L10n.tr("%@, %d%%", reading.label, DisplayNumber.percent($0))
            } ?? L10n.tr("%@, no reading", reading.label))
            .accessibilityValue(reading.amount == nil
                ? ([L10n.tr(mode == .used ? "Used" : "Remaining"), reading.caption]
                    + [reading.burn.flatMap { $0.isBurning ? L10n.tr("last hour %d times even pace", Int($0.multiple.rounded())) : nil }]
                        .compactMap { $0 }).joined(separator: ", ")
                : reading.caption)
    }
}

enum QuotaPalette {
    static func shortTerm(_ color: Color) -> Color {
        if color == IslandColor.codex { return Color(red: 163/255, green: 163/255, blue: 163/255) }
        if color == IslandColor.claude { return Color(red: 242/255, green: 196/255, blue: 150/255) }
        if color == IslandColor.grok { return Color(red: 0.65, green: 0.83, blue: 1) }
        let native = NSColor(color)
        return Color(nsColor: native.blended(withFraction: 0.55, of: .white) ?? native)
    }
}
