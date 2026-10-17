import SwiftUI

/// A Stories-sized (9:16) picture of the reader's week: focus time, streak, the last seven days,
/// favourite categories and earned badges, in the app's night-library colours.
struct WeekShareCard: View {
    let user: UserProfile
    let summary: StatsSummary

    static let size = CGSize(width: 390, height: 693)

    private static let ink = Color.white
    private static let lamp = Color(red: 1, green: 0.72, blue: 0.3)
    private static let accent = Color(red: 0.55, green: 0.55, blue: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            header
            VStack(alignment: .leading, spacing: 4) {
                Text("Bu hafta odaklandım")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Self.ink.opacity(0.7))
                Text(formattedFocus(summary.weekMs))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundStyle(Self.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                HStack(spacing: 16) {
                    Label("\(summary.streakDays) gün seri", systemImage: "flame.fill")
                        .foregroundStyle(.orange)
                    Label("Bugün \(formattedFocus(summary.todayMs))", systemImage: "sun.max.fill")
                        .foregroundStyle(Self.lamp)
                }
                .font(.headline)
            }
            weekBars
            categories
            badges
            Spacer(minLength: 0)
            footer
        }
        .padding(32)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .topLeading)
        .background {
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.12, blue: 0.27), Color(red: 0.05, green: 0.05, blue: 0.1)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: user.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 40, height: 40)
                .frame(width: 58, height: 58)
                .background(Self.lamp.opacity(0.22), in: .rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 1) {
                Text(user.displayName)
                    .font(.headline)
                    .foregroundStyle(Self.ink)
                Text(verbatim: "@\(user.username)")
                    .font(.subheadline)
                    .foregroundStyle(Self.ink.opacity(0.6))
            }
            Spacer()
            Label("PomoLive", systemImage: "books.vertical.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Self.accent)
        }
    }

    private var weekBars: some View {
        let longest = max(summary.last7Days.map(\.totalMs).max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(summary.last7Days) { day in
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(day.totalMs > 0 ? AnyShapeStyle(Self.accent.gradient) : AnyShapeStyle(Self.ink.opacity(0.12)))
                        .frame(height: max(6, 96 * CGFloat(day.totalMs) / CGFloat(longest)))
                    Text(Self.weekday(day.date))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Self.ink.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 118, alignment: .bottom)
    }

    @ViewBuilder
    private var categories: some View {
        if !summary.categories.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.categories.prefix(3)) { category in
                    HStack(spacing: 10) {
                        Image(systemName: category.symbol)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(category.color.color.gradient, in: .rect(cornerRadius: 8))
                        Text(category.displayName)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Self.ink)
                        Spacer()
                        Text(formattedFocus(category.ms))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Self.ink.opacity(0.7))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        let earned = (summary.badges ?? []).filter(\.earned).compactMap { badge in
            BadgeStyle(id: badge.id).map { (badge, $0) }
        }
        if !earned.isEmpty {
            HStack(spacing: 10) {
                ForEach(earned.prefix(6), id: \.0.id) { badge, style in
                    BadgeMedal(badge: badge, style: style, size: 40)
                }
            }
        }
    }

    private var footer: some View {
        Text("Sessiz kütüphanede birlikte odaklan.")
            .font(.footnote.weight(.medium))
            .foregroundStyle(Self.ink.opacity(0.55))
    }

    /// "Pzt" / "Mon" from `YYYY-MM-DD`.
    private static func weekday(_ date: String) -> String {
        guard let day = try? Date(date, strategy: .iso8601.year().month().day()) else { return "" }
        return day.formatted(.dateTime.weekday(.abbreviated).locale(.app))
    }
}

/// A toolbar button that renders the week card and opens the share sheet with it.
struct ShareWeekButton: View {
    let user: UserProfile
    let summary: StatsSummary

    @State private var rendered: Image?

    var body: some View {
        Group {
            if let rendered {
                // Shared as an image, so Photos, Messages and Stories apps all accept it.
                ShareLink(item: rendered, preview: SharePreview(String(localized: "PomoLive haftam"), image: rendered)) {
                    Label("Haftamı Paylaş", systemImage: "square.and.arrow.up")
                }
            } else {
                Button("Haftamı Paylaş", systemImage: "square.and.arrow.up") {}
                    .disabled(true)
            }
        }
        .task(id: summary) { render() }
    }

    private func render() {
        let renderer = ImageRenderer(content: WeekShareCard(user: user, summary: summary).environment(\.locale, .app))
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(WeekShareCard.size)
        guard let image = renderer.uiImage else { return }
        rendered = Image(uiImage: image)
    }
}

#Preview {
    WeekShareCard(
        user: UserProfile(id: "1", username: "baransel", displayName: "Baransel", avatarSpriteId: "coder_m_01", bio: nil, statsVisible: true),
        summary: StatsSummary(
            todayMs: 95 * 60_000, weekMs: 14 * 3_600_000, totalMs: 80 * 3_600_000, sessionCount: 40, streakDays: 6,
            last7Days: (10...16).map { DayTotal(date: "2026-10-\($0)", totalMs: Int64($0 % 4) * 3_600_000, byCategory: []) },
            categories: [CategoryTotal(key: "software", name: "Yazılım", symbol: "chevron.left.forwardslash.chevron.right", color: .blue, ms: 8 * 3_600_000)],
            badges: [Badge(id: "first_session", progress: 1, earned: true), Badge(id: "marathon", progress: 1, earned: true)]
        )
    )
}
