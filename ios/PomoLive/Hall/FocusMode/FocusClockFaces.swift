import SwiftUI

/// The numbers every face shows: time on the clock (left in a pomodoro phase, or focused so far for
/// a stopwatch), how far the phase is, and the fraction of the current second for smooth sweeps.
struct ClockReading {
    let reading: TimerReading
    let displayMs: Int64
    let progress: Double
    let secondFraction: Double
    let isCountdown: Bool

    init(timer: DeskTimer, now: Int64) {
        reading = timer.reading(at: now)
        if let end = reading.phaseEndsAt {
            displayMs = max(0, end - now)
            let length = Double(end - reading.phaseStartedAt)
            progress = length > 0 ? min(max(Double(now - reading.phaseStartedAt) / length, 0), 1) : 0
            isCountdown = true
        } else {
            displayMs = reading.focusedMs
            progress = Double(reading.focusedMs % 3_600_000) / 3_600_000
            isCountdown = false
        }
        let secondMs = Double(displayMs % 60_000) / 60_000
        secondFraction = isCountdown ? 1 - secondMs : secondMs
    }

    var hours: Int64 { displayMs / 3_600_000 }
    var minutes: Int64 { displayMs / 60_000 % 60 }
    var seconds: Int64 { displayMs / 1000 % 60 }

    var phaseTitle: LocalizedStringKey {
        switch (isCountdown, reading.phase) {
        case (true, .focus): "Odak"
        case (true, .rest): "Mola"
        case (false, .focus): "Çalışıyor"
        case (false, .rest): "Duraklatıldı"
        }
    }
}

/// Huge thin digits; every change rolls in like a split-flap.
struct DigitalFace: View {
    let clock: ClockReading
    let tint: Color
    let showsSeconds: Bool

    var body: some View {
        VStack(spacing: 12) {
            PhaseCaption(clock: clock, tint: tint)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if clock.hours > 0 {
                    digits(clock.hours)
                    colon
                }
                digits(clock.minutes, padded: clock.hours > 0)
                if showsSeconds {
                    colon
                    digits(clock.seconds)
                        .opacity(0.55)
                }
            }
            .font(.system(size: 200, weight: .thin, design: .rounded))
            .minimumScaleFactor(0.2)
            .lineLimit(1)
            .monospacedDigit()
            .foregroundStyle(tint)
            .animation(.smooth(duration: 0.45), value: clock.seconds)
            ProgressCapsule(progress: clock.progress, tint: tint)
                .frame(width: 220)
        }
    }

    private func digits(_ value: Int64, padded: Bool = true) -> some View {
        Text(verbatim: padded ? String(format: "%02lld", value) : "\(value)")
            .contentTransition(.numericText(countsDown: clock.isCountdown))
    }

    private var colon: some View {
        Text(verbatim: ":")
            .opacity(clock.seconds % 2 == 0 ? 0.9 : 0.35)
            .padding(.horizontal, 4)
    }
}

/// A hairline ring that fills through the phase, with a glowing bead orbiting once a minute.
struct RingFace: View {
    let clock: ClockReading
    let tint: Color
    let showsSeconds: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .stroke(tint.opacity(0.12), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: max(clock.progress, 0.002))
                    .stroke(tint.opacity(0.85), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                if showsSeconds {
                    Circle()
                        .fill(tint)
                        .frame(width: 10, height: 10)
                        .shadow(color: tint, radius: 8)
                        .offset(y: -side / 2)
                        .rotationEffect(.degrees(clock.secondFraction * 360))
                }
                VStack(spacing: 10) {
                    PhaseCaption(clock: clock, tint: tint)
                    Text(verbatim: TimeText.string(clock))
                        .font(.system(size: side * 0.2, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .contentTransition(.numericText(countsDown: clock.isCountdown))
                        .animation(.smooth(duration: 0.4), value: clock.seconds)
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(28)
    }
}

/// A watch dial: hour ticks, the phase as a sweeping sector and a smoothly gliding seconds hand.
struct AnalogFace: View {
    let clock: ClockReading
    let tint: Color
    let showsSeconds: Bool

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Canvas { context, size in
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    let radius = min(size.width, size.height) / 2
                    for tick in 0..<60 {
                        let isMajor = tick % 5 == 0
                        let angle = Double(tick) / 60 * 2 * .pi - .pi / 2
                        let outer = radius - 2
                        let inner = outer - (isMajor ? radius * 0.1 : radius * 0.04)
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
                        context.stroke(path, with: .color(tint.opacity(isMajor ? 0.7 : 0.25)), lineWidth: isMajor ? 3 : 1.2)
                    }
                    var sector = Path()
                    sector.move(to: center)
                    sector.addArc(center: center, radius: radius * 0.8, startAngle: .degrees(-90),
                                  endAngle: .degrees(-90 + 360 * clock.progress), clockwise: false)
                    sector.closeSubpath()
                    context.fill(sector, with: .color(tint.opacity(0.1)))
                }
                if showsSeconds {
                    Capsule()
                        .fill(tint)
                        .frame(width: 2, height: side * 0.46)
                        .offset(y: -side * 0.2)
                        .rotationEffect(.degrees(clock.secondFraction * 360))
                    Circle()
                        .fill(tint)
                        .frame(width: 10, height: 10)
                }
                VStack(spacing: 6) {
                    PhaseCaption(clock: clock, tint: tint)
                    Text(verbatim: TimeText.string(clock))
                        .font(.system(size: side * 0.12, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(tint)
                        .contentTransition(.numericText(countsDown: clock.isCountdown))
                        .animation(.smooth(duration: 0.4), value: clock.seconds)
                }
                .offset(y: side * 0.2)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(28)
    }
}

/// "ODAK · Yazılım" above every face.
struct PhaseCaption: View {
    let clock: ClockReading
    let tint: Color

    var body: some View {
        Text(clock.phaseTitle)
            .font(.system(.subheadline, design: .rounded, weight: .semibold))
            .textCase(.uppercase)
            .kerning(3)
            .foregroundStyle(tint.opacity(0.6))
            .contentTransition(.opacity)
    }
}

struct ProgressCapsule: View {
    let progress: Double
    let tint: Color

    var body: some View {
        Capsule()
            .fill(tint.opacity(0.12))
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(tint.opacity(0.8))
                        .frame(width: max(4, proxy.size.width * progress))
                }
            }
            .animation(.linear(duration: 1), value: progress)
    }
}

enum TimeText {
    /// "24:59" or "1:05:09".
    static func string(_ clock: ClockReading) -> String {
        clock.hours > 0
            ? String(format: "%lld:%02lld:%02lld", clock.hours, clock.minutes, clock.seconds)
            : String(format: "%02lld:%02lld", clock.minutes, clock.seconds)
    }
}
