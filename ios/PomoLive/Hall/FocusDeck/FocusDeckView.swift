import SwiftUI

/// The reader's control panel while seated. Folded it is a slim bar with a mini ring and the clock;
/// unfolded it shows a large dial and the session's actions.
///
/// The top row never leaves the screen: the avatar, labels and trailing button resize in place while
/// the dial and actions fade out before the glass shrinks (and in after it grows), so folding reads
/// as one continuous motion. Drags follow the finger and settle with the gesture's velocity.
struct FocusDeckView: View {
    let desk: DeskRecord
    let clock: ServerClock
    @Binding var isExpanded: Bool
    let onChangeTimer: (ChangeTimerCommand.Action) -> Void
    let onFinish: () -> Void
    let onFocusMode: () -> Void
    let onTasks: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    @State private var confirmsFinish = false

    /// The one spring every fold and unfold runs on, shared with the controls above the deck.
    static let fold = Animation.spring(duration: 0.5, bounce: 0.15)
    private static let foldDistance: CGFloat = 60

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let reading = desk.timer.reading(at: clock.now)
            VStack(spacing: 0) {
                headerRow(reading)
                if isExpanded {
                    VStack(spacing: 22) {
                        FocusDial(reading: reading, timer: desk.timer, clock: clock)
                        actions(for: reading)
                    }
                    .padding(.top, 22)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.94, anchor: .top))
                            .animation(.smooth(duration: 0.35).delay(0.1)),
                        removal: .opacity.animation(.easeIn(duration: 0.12))
                    ))
                }
            }
            .padding(.horizontal, isExpanded ? 20 : 12)
            .padding(.vertical, isExpanded ? 20 : 10)
        }
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: isExpanded ? 34 : 30))
        .offset(y: resisted(dragOffset))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .contentShape(.rect)
        .gesture(foldGesture)
        .animation(.interactiveSpring, value: dragOffset)
        .sensoryFeedback(.impact(weight: .light), trigger: isExpanded)
        .confirmationDialog("Oturum bitsin mi?", isPresented: $confirmsFinish, titleVisibility: .visible) {
            Button("Oturumu Bitir", role: .destructive, action: onFinish)
        } message: {
            Text("Masadan kalkarsın; odak süren geçmişine kaydedilir.")
        }
    }

    /// Follows the finger toward the fold direction and resists the other way.
    private func resisted(_ offset: CGFloat) -> CGFloat {
        let towardFold = isExpanded ? offset > 0 : offset < 0
        return offset * (towardFold ? 0.5 : 0.12)
    }

    private var foldGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragOffset) { value, offset, _ in offset = value.translation.height }
            .onEnded { value in
                let travel = value.predictedEndTranslation.height
                if isExpanded, travel > Self.foldDistance { setExpanded(false) }
                if !isExpanded, travel < -Self.foldDistance / 2 { setExpanded(true) }
            }
    }

    private func setExpanded(_ expanded: Bool) {
        withAnimation(Self.fold) { isExpanded = expanded }
    }

    // MARK: - Header

    /// The one row both states share; its pieces resize instead of being swapped out.
    private func headerRow(_ reading: TimerReading) -> some View {
        let action = Self.primaryAction(mode: desk.timer.mode, phase: reading.phase)
        return HStack(spacing: 12) {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: desk.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: isExpanded ? 44 : 30, height: isExpanded ? 44 : 30)

            VStack(alignment: .leading, spacing: 2) {
                Label {
                    Text(desk.category.displayName)
                } icon: {
                    Image(systemName: desk.category.symbol)
                        .foregroundStyle(desk.category.color.color)
                }
                .font(isExpanded ? .headline : .subheadline.weight(.semibold))
                if isExpanded {
                    Text(desk.note ?? String(localized: "Masa \(desk.number) · \(desk.sessionNumber). seans"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .lineLimit(1)

            Spacer(minLength: 4)

            if !isExpanded {
                HStack(spacing: 8) {
                    ProgressArc(progress: reading.progress(at: clock.now), tint: reading.tint, lineWidth: 3.5)
                        .frame(width: 22, height: 22)
                    TimerText(timer: desk.timer, clock: clock)
                        .font(.system(.headline, design: .rounded))
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8, anchor: .trailing)))
            }

            if isExpanded {
                Button("Görevler", systemImage: "checklist", action: onTasks)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                Button("Odak Modu", systemImage: "moon.fill", action: onFocusMode)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }

            Button {
                if isExpanded { setExpanded(false) } else { onChangeTimer(action.command) }
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : action.symbol)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(isExpanded ? Text("Küçült") : Text(action.title))
        }
        .contentShape(.rect)
        .onTapGesture { if !isExpanded { setExpanded(true) } }
        .accessibilityAction(named: Text("Odak panelini aç")) { setExpanded(true) }
    }

    // MARK: - Actions

    private func actions(for reading: TimerReading) -> some View {
        let action = Self.primaryAction(mode: desk.timer.mode, phase: reading.phase)
        return HStack(spacing: 12) {
            Button { onChangeTimer(action.command) } label: {
                Label(action.title, systemImage: action.symbol)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(reading.tint)

            Button(role: .destructive) { confirmsFinish = true } label: {
                Label("Bitir", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .controlSize(.large)
        .animation(.smooth, value: reading.phase)
    }

    private static func primaryAction(
        mode: TimerMode,
        phase: TimerPhase
    ) -> (title: LocalizedStringKey, symbol: String, command: ChangeTimerCommand.Action) {
        switch (mode, phase) {
        case (.pomodoro, .focus): ("Molaya Geç", "cup.and.saucer.fill", .rest)
        case (.pomodoro, .rest): ("Molayı Atla", "forward.fill", .resume)
        case (.stopwatch, .focus): ("Duraklat", "pause.fill", .rest)
        case (.stopwatch, .rest): ("Devam Et", "play.fill", .resume)
        }
    }
}

private extension TimerReading {
    /// How far through the phase we are; a stopwatch fills once per hour of focus.
    func progress(at now: Int64) -> Double {
        if let end = phaseEndsAt {
            let length = Double(end - phaseStartedAt)
            return length > 0 ? min(max(Double(now - phaseStartedAt) / length, 0), 1) : 0
        }
        return Double(focusedMs % 3_600_000) / 3_600_000
    }

    var tint: Color { phase == .focus ? .accentColor : .mint }
}

/// A rounded arc on a faint track, sweeping smoothly between the once-a-second readings.
private struct ProgressArc: View {
    let progress: Double
    let tint: Color
    let lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(progress, 0.002))
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.55), tint], center: .center, startAngle: .degrees(0), endAngle: .degrees(360 * max(progress, 0.002))),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .animation(.linear(duration: 1), value: progress)
        .animation(.smooth(duration: 0.6), value: tint)
    }
}

/// The unfolded clock face: minute ticks lighting up as the phase runs, a gradient arc with a knob
/// at its tip, a phase pill and the big countdown. While focusing, a soft glow breathes behind it.
private struct FocusDial: View {
    let reading: TimerReading
    let timer: DeskTimer
    let clock: ServerClock

    private static let size: CGFloat = 214
    private static let ticks = 60

    private var progress: Double { reading.progress(at: clock.now) }
    private var isRunning: Bool { reading.phase == .focus }

    private var phaseTitle: LocalizedStringKey {
        switch (timer.mode, reading.phase) {
        case (.pomodoro, .focus): "Odak"
        case (.pomodoro, .rest): "Mola"
        case (.stopwatch, .focus): "Çalışıyor"
        case (.stopwatch, .rest): "Duraklatıldı"
        }
    }

    private var phaseSymbol: String {
        switch (timer.mode, reading.phase) {
        case (_, .focus): "brain.head.profile.fill"
        case (.pomodoro, .rest): "cup.and.saucer.fill"
        case (.stopwatch, .rest): "pause.fill"
        }
    }

    var body: some View {
        let tint = reading.tint
        ZStack {
            Circle()
                .fill(tint.opacity(0.08))
                .padding(26)
                .phaseAnimator(isRunning ? [false, true] : [false]) { glow, breathing in
                    glow.scaleEffect(breathing ? 1.04 : 0.96).opacity(breathing ? 1 : 0.6)
                } animation: { _ in .easeInOut(duration: 2.4) }

            ticks(tint: tint)

            ProgressArc(progress: progress, tint: tint, lineWidth: 12)
                .padding(14)

            knob(tint: tint)

            VStack(spacing: 6) {
                Label(phaseTitle, systemImage: phaseSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.16), in: .capsule)
                    .contentTransition(.symbolEffect(.replace))
                TimerText(timer: timer, clock: clock)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                Text("Toplam \(formattedFocus(reading.focusedMs)) odak")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .frame(width: Self.size, height: Self.size)
        .animation(.smooth(duration: 0.6), value: reading.phase)
        .accessibilityElement(children: .combine)
    }

    /// Sixty marks around the rim; those the phase has passed take the tint.
    private func ticks(tint: Color) -> some View {
        let lit = Int(progress * Double(Self.ticks))
        return ForEach(0..<Self.ticks, id: \.self) { index in
            let isMajor = index % 5 == 0
            Capsule()
                .fill(index < lit ? tint.opacity(0.9) : Color.secondary.opacity(isMajor ? 0.45 : 0.22))
                .frame(width: isMajor ? 2.5 : 1.5, height: isMajor ? 7 : 4)
                .offset(y: -Self.size / 2 + 3)
                .rotationEffect(.degrees(Double(index) / Double(Self.ticks) * 360))
        }
    }

    /// A small bead riding the tip of the arc.
    private func knob(tint: Color) -> some View {
        Circle()
            .fill(.white)
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(tint, lineWidth: 3))
            .offset(y: -(Self.size / 2 - 14))
            .rotationEffect(.degrees(progress * 360))
            .animation(.linear(duration: 1), value: progress)
    }
}
