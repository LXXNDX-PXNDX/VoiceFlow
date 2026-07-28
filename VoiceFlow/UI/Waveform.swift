import SwiftUI

/// Live level meter drawn as a row of rounded bars, mirrored around the centre.
struct Waveform: View {
    let levels: [Float]
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 3
    var minHeight: CGFloat = 3
    var gradient: LinearGradient = Theme.waveGradient

    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { _, level in
                    Capsule()
                        .fill(gradient)
                        .frame(width: barWidth,
                               height: max(minHeight, CGFloat(level) * geo.size.height))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
            .animation(.easeOut(duration: 0.08), value: levels)
        }
    }
}

/// Idle placeholder: a gentle travelling ripple so the pill never looks dead.
struct IdleWave: View {
    @State private var phase: Double = 0
    var barCount: Int = 36
    var barWidth: CGFloat = 3
    var spacing: CGFloat = 3

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(0.30))
                        .frame(width: barWidth, height: height(index: index, time: t))
                }
            }
        }
    }

    private func height(index: Int, time: Double) -> CGFloat {
        let wave = sin(time * 2.2 + Double(index) * 0.35)
        return 3 + CGFloat((wave + 1) / 2) * 7
    }
}
