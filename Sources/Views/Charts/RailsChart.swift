import SwiftUI

struct RailsChart: View {
    let readings: [QuotaChartReading]
    let color: Color
    let mode: UsageDisplayMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 8) {
            ForEach(readings) { reading in
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(reading.label).font(Typography.label).foregroundStyle(.white.opacity(0.65))
                            .lineLimit(1).help(reading.label)
                        Spacer(minLength: 6)
                        QuotaValue(reading: reading, mode: mode, size: readings.count == 1 ? 32 : 22)
                    }
                    GeometryReader { geometry in
                        let fraction = (reading.value ?? 0) / 100
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.15))
                            if reading.value != nil {
                                if let projected = reading.projectedFill(mode: mode) {
                                    Capsule().fill(color.opacity(0.32)).frame(width: geometry.size.width * projected / 100)
                                }
                                Capsule().fill(color).frame(width: geometry.size.width * fraction)
                                if let mark = reading.paceMark(mode: mode) {
                                    PaceMark().offset(x: min(geometry.size.width - 2, max(0, geometry.size.width * mark / 100 - 1)))
                                }
                            }
                        }
                    }
                    .frame(height: 4)
                    .opacity(reading.amount == nil ? 1 : 0)
                    .accessibilityHidden(true)
                    QuotaCaption(caption: reading.caption, burst: reading.burstText)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .modifier(QuotaAccessibility(reading: reading, mode: mode))
            }
        }
        .animation(reduceMotion ? nil : .strongEaseOut, value: readings.map(\.value))
    }
}
