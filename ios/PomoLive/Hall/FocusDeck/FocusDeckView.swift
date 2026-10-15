import SwiftUI

/// The reader's control panel while seated: a Clock-style progress ring, the phase and its actions.
/// Swipe down to fold it into a slim bar so the hall can be explored; swipe up or tap to unfold.
///
/// Both states share one glass surface that changes height, while the avatar and category glide
/// between their places, so folding reads as a single liquid motion. During a drag the panel
/// follows the finger with resistance and settles with the gesture's velocity.
struct FocusDeckView: View {
    let desk: DeskRecord
    let clock: ServerClock
    @Binding var isExpanded: Bool
    let onChangeTimer: (ChangeTimerCommand.Action) -> Void
    let onFinish: () -> Void

    @Namespace private var deck
    @GestureState private var dragOffset: CGFloat = 0
    @State private var confirmsFinish = false

    private static let fold = Animation.spring(duration: 0.45, bounce: 0.12)
    private static let foldDistance: CGFloat = 70

    private var cornerRadius: CGFloat { isExpanded ? 34 : 29 }

    var body: some View {
        VStack(spacing: 0) {
            if isExpanded {
                expandedDeck
                    .transition(.blurReplace)
            } else {
                compactBar
                    .transition(.blurReplace)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        .offset(y: resisted(dragOffset))
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .gesture(foldGesture)
        .animation(Self.fold, value: isExpanded)
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
        guard towardFold else { return offset * 0.15 }
        return offset * 0.55
    }

    private var foldGesture: some Gesture {
        DragGesture(minimumDistance: 10)
            .updating($dragOffset) { value, offset, _ in offset = value.translation.height }
            .onEnded { value in
                let travel = value.predictedEndTranslation.height
                if isExpanded, travel > Self.foldDistance { isExpanded = false }
                if !isExpanded, travel < -Self.foldDistance / 2 { isExpanded = true }
            }
    }

    // MARK: - Expanded

    private var expandedDeck: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let reading = desk.timer.reading(at: clock.now)
            VStack(spacing: 18) {
                header
                ProgressRing(reading: reading, timer: desk.timer, clock: clock)
                actions(for: reading)
            }
            .padding(20)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            avatar(size: 44)
            VStack(alignment: .leading, spacing: 2) {
                categoryLabel
                    .font(.headline)
                Text(desk.note ?? String(localized: "Masa \(desk.number) · \(desk.sessionNumber). seans"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            Spacer(minLength: 0)
            Button("Küçült", systemImage: "chevron.down") { isExpanded = false }
                .labelStyle(.iconOnly)
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .matchedGeometryEffect(id: "control", in: deck)
        }
    }

    private func actions(for reading: TimerReading) -> some View {
        let action = Self.primaryAction(mode: desk.timer.mode, phase: reading.phase)
        return HStack(spacing: 12) {
            Button { onChangeTimer(action.command) } label: {
                Label(action.title, systemImage: action.symbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .contentTransition(.symbolEffect(.replace))

            Button(role: .destructive) { confirmsFinish = true } label: {
                Label("Bitir", systemImage: "stop.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .controlSize(.large)
    }

    // MARK: - Compact

    private var compactBar: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let action = Self.primaryAction(mode: desk.timer.mode, phase: desk.timer.reading(at: clock.now).phase)
            HStack(spacing: 12) {
                avatar(size: 30)
                categoryLabel
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 4)
                TimerText(timer: desk.timer, clock: clock)
                    .font(.system(.headline, design: .rounded))
                Button(action.title, systemImage: action.symbol) { onChangeTimer(action.command) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .contentTransition(.symbolEffect(.replace))
                    .matchedGeometryEffect(id: "control", in: deck)
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .padding(.vertical, 8)
        }
        .contentShape(.rect)
        .onTapGesture { isExpanded = true }
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: Text("Odak panelini aç")) { isExpanded = true }
    }

    // MARK: - Shared pieces

    /// The same avatar in both states, so it glides between them.
    private func avatar(size: CGFloat) -> some View {
        Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: desk.avatarSpriteId)), scale: 1)
            .resizable()
            .interpolation(.none)
            .matchedGeometryEffect(id: "avatar", in: deck)
            .frame(width: size, height: size)
    }

    private var categoryLabel: some View {
        Label {
            Text(desk.category.displayName)
        } icon: {
            Image(systemName: desk.category.symbol)
                .foregroundStyle(desk.category.color.color)
        }
        .matchedGeometryEffect(id: "category", in: deck)
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

/// Clock-app style ring: fills through the pomodoro phase, or once per hour for a stopwatch.
private struct ProgressRing: View {
    let reading: TimerReading
    let timer: DeskTimer
    let clock: ServerClock

    private var progress: Double {
        let now = clock.now
        if let end = reading.phaseEndsAt {
            let length = Double(end - reading.phaseStartedAt)
            return length > 0 ? Double(now - reading.phaseStartedAt) / length : 0
        }
        return Double(reading.focusedMs % 3_600_000) / 3_600_000
    }

    private var tint: Color { reading.phase == .focus ? .accentColor : .mint }

    private var phaseTitle: LocalizedStringKey {
        switch (timer.mode, reading.phase) {
        case (.pomodoro, .focus): "Odak"
        case (.pomodoro, .rest): "Mola"
        case (.stopwatch, .focus): "Çalışıyor"
        case (.stopwatch, .rest): "Duraklatıldı"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.2), lineWidth: 12)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.001), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)
            VStack(spacing: 4) {
                Text(phaseTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                TimerText(timer: timer, clock: clock)
                    .font(.system(size: 44, weight: .semibold, design: .rounded))
                Text("Toplam \(formattedFocus(reading.focusedMs)) odak")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 196, height: 196)
        .accessibilityElement(children: .combine)
    }
}
