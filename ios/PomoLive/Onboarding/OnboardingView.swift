import SwiftUI

/// Three pages shown once after the first sign-in: what PomoLive is, how the timer works and why
/// friends matter, ending with the notification permission and a seat in the busiest hall.
struct OnboardingView: View {
    /// Called when the reader is done; `true` when they want to sit down right away.
    let onFinish: (_ sitsDown: Bool) -> Void

    @Environment(AppModel.self) private var app
    @State private var page = Page.library

    private enum Page: Int, CaseIterable {
        case library, timer, friends
    }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardingPage(
                    title: "Sessiz bir kütüphane",
                    message: "Bir masaya otur, lamban yansın. Salondaki herkes kendi işine odaklanırken sen de yalnız değilsin. Konuşmak zorunda değilsin."
                ) {
                    ReadingRoomIllustration()
                }
                .tag(Page.library)

                OnboardingPage(
                    title: "Kendi sayacın, ortak sessizlik",
                    message: "Pomodoro ya da kronometre seç. Sayacın kilit ekranında, Dynamic Island'da ve widget'larda seninle kalır; telefonu kilitlesen de masan korunur."
                ) {
                    TimerIllustration()
                }
                .tag(Page.timer)

                OnboardingPage(
                    title: "Arkadaşlarınla daha kolay",
                    message: "Arkadaşlarını takip et, çalışmaya başladıklarında haberin olsun ve yanlarına otur. Haftalık sıralamada kimin daha çok odaklandığını gör."
                ) {
                    FriendsIllustration(focusingNow: app.rooms.overview?.focusingNow)
                }
                .tag(Page.friends)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.smooth, value: page)

            actions
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
        }
        .interactiveDismissDisabled()
        .task { await app.rooms.refresh() }
    }

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 8) {
            if page == .friends {
                Button {
                    Task {
                        await app.push.requestPermission()
                        onFinish(true)
                    }
                } label: {
                    Text("Bildirimleri Aç ve Başla")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                Button("Şimdi Değil") { onFinish(true) }
                    .controlSize(.large)
            } else {
                Button {
                    page = Page(rawValue: page.rawValue + 1) ?? .friends
                } label: {
                    Text("Devam")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.extraLarge)
                Button("Geç") { onFinish(false) }
                    .controlSize(.large)
            }
        }
        .fontWeight(.semibold)
        .animation(.smooth, value: page)
    }
}

private struct OnboardingPage<Illustration: View>: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    @ViewBuilder let illustration: Illustration

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)
            illustration
                .frame(height: 220)
            VStack(spacing: 12) {
                Text(title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            Spacer(minLength: 56)
        }
    }
}

/// Six desks, most of them lit, with readers typing away.
private struct ReadingRoomIllustration: View {
    private static let readers: [(AvatarSprite, Bool)] = [
        (.student, true), (.coder, true), (.cat, false),
        (.blonde, true), (.scholar, true), (.hijabi, true),
    ]

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.4)) { context in
            let tick = Int(context.date.timeIntervalSinceReferenceDate / 0.4)
            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                ForEach(0..<2, id: \.self) { row in
                    GridRow {
                        ForEach(0..<3, id: \.self) { column in
                            let index = row * 3 + column
                            let (sprite, isLit) = Self.readers[index]
                            DeskTile(sprite: sprite, isLit: isLit, frame: (tick + index) % 2)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct DeskTile: View {
    let sprite: AvatarSprite
    let isLit: Bool
    let frame: Int

    var body: some View {
        Image(decorative: sprite.image(isLit ? .typing(frame: frame) : .idle), scale: 1)
            .resizable()
            .interpolation(.none)
            .frame(width: 52, height: 52)
            .frame(width: 84, height: 84)
            .background {
                RoundedRectangle(cornerRadius: 20)
                    .fill(isLit ? AnyShapeStyle(Color.orange.opacity(0.18)) : AnyShapeStyle(.fill.tertiary))
            }
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(isLit ? Color.orange : Color.secondary.opacity(0.4))
                    .frame(width: 10, height: 10)
                    .padding(10)
            }
    }
}

/// A pomodoro ring counting down, and where the timer follows the reader.
private struct TimerIllustration: View {
    var body: some View {
        VStack(spacing: 20) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = 18 * 60 + 42 - Int(context.date.timeIntervalSinceReferenceDate) % 60
                ZStack {
                    Circle()
                        .stroke(Color.indigo.opacity(0.18), lineWidth: 14)
                    Circle()
                        .trim(from: 0, to: Double(remaining) / Double(25 * 60))
                        .stroke(Color.indigo, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(Duration.seconds(remaining), format: .time(pattern: .minuteSecond))
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                }
                .frame(width: 140, height: 140)
                .animation(.smooth, value: remaining)
            }
            HStack(spacing: 18) {
                Label("Kilit Ekranı", systemImage: "lock.fill")
                Label("Dynamic Island", systemImage: "capsule.fill")
                Label("Widget", systemImage: "square.grid.2x2.fill")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .accessibilityHidden(true)
    }
}

/// Friends' avatars around a bell, with how many people are focusing right now.
private struct FriendsIllustration: View {
    let focusingNow: Int?

    var body: some View {
        VStack(spacing: 22) {
            HStack(spacing: 10) {
                ForEach([AvatarSprite.ponytail, .gamer, .artist, .wizard], id: \.self) { sprite in
                    Image(decorative: SpriteCache.shared.avatar(sprite), scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 40, height: 40)
                        .frame(width: 64, height: 64)
                        .background(.fill.tertiary, in: .circle)
                }
            }
            Label {
                Text(focusingNow.map { $0 > 0 ? "Şu an \($0) kişi odaklanıyor" : "Salonlar seni bekliyor" } ?? "Salonlar seni bekliyor")
                    .contentTransition(.numericText())
            } icon: {
                Image(systemName: "bell.badge.fill")
                    .symbolRenderingMode(.multicolor)
                    .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 2)))
            }
            .font(.headline)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
        }
        .accessibilityElement(children: .combine)
    }
}
