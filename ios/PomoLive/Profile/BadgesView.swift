import SwiftUI

/// How each badge looks and reads.
struct BadgeStyle {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String
    let color: Color

    init?(id: String) {
        switch id {
        case "first_session": self.init("İlk Adım", "İlk odak oturumunu tamamla.", "flag.fill", .green)
        case "marathon": self.init("Maraton", "Tek oturumda 2 saat odaklan.", "figure.run", .orange)
        case "ten_hours": self.init("10 Saat", "Toplam 10 saat odaklan.", "clock.fill", .blue)
        case "hundred_hours": self.init("Yüz Saat", "Toplam 100 saat odaklan.", "crown.fill", .yellow)
        case "fifty_sessions": self.init("Elli Seans", "50 oturum tamamla.", "square.stack.3d.up.fill", .purple)
        case "streak_7": self.init("Haftalık Seri", "7 gün üst üste çalış.", "flame.fill", .red)
        case "streak_30": self.init("Aylık Seri", "30 gün üst üste çalış.", "bolt.heart.fill", .pink)
        case "early_bird": self.init("Erken Kuş", "Sabah 05–08 arası 5 oturum başlat.", "sunrise.fill", .orange)
        case "night_owl": self.init("Gece Kuşu", "Gece 23–04 arası 5 oturum başlat.", "moon.stars.fill", .indigo)
        case "all_rounder": self.init("Çok Yönlü", "Son 30 günde 4 farklı kategoride çalış.", "circle.hexagongrid.fill", .teal)
        default: return nil
        }
    }

    private init(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, _ symbol: String, _ color: Color) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
        self.color = color
    }
}

/// A medal: coloured when earned, a grey outline with a progress ring while still in reach.
struct BadgeMedal: View {
    let badge: Badge
    let style: BadgeStyle
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle()
                .fill(badge.earned ? AnyShapeStyle(style.color.gradient) : AnyShapeStyle(.fill.tertiary))
            if !badge.earned, badge.progress > 0 {
                Circle()
                    .trim(from: 0, to: badge.progress)
                    .stroke(style.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(1.5)
            }
            Image(systemName: style.symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(badge.earned ? .white : .secondary)
        }
        .frame(width: size, height: size)
        .shadow(color: badge.earned ? style.color.opacity(0.35) : .clear, radius: 6, y: 3)
    }
}

/// A horizontal shelf of medals, earned first; tap one to read what it is for.
struct BadgeShelf: View {
    let badges: [Badge]
    @State private var selected: Badge?

    private var known: [(Badge, BadgeStyle)] {
        badges.compactMap { badge in BadgeStyle(id: badge.id).map { (badge, $0) } }
            .sorted { ($0.0.earned ? 0 : 1, -$0.0.progress) < ($1.0.earned ? 0 : 1, -$1.0.progress) }
    }

    var body: some View {
        let earned = badges.filter(\.earned).count
        VStack(alignment: .leading, spacing: 10) {
            Text("\(earned)/\(known.count) rozet kazanıldı")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(known, id: \.0.id) { badge, style in
                        Button { selected = badge } label: {
                            VStack(spacing: 6) {
                                BadgeMedal(badge: badge, style: style)
                                Text(style.title)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(badge.earned ? .primary : .secondary)
                                    .lineLimit(1)
                            }
                            .frame(width: 72)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $selected) { badge in
            if let style = BadgeStyle(id: badge.id) {
                VStack(spacing: 14) {
                    BadgeMedal(badge: badge, style: style, size: 96)
                    Text(style.title).font(.title2.weight(.bold))
                    Text(style.detail).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    if badge.earned {
                        Label("Kazanıldı", systemImage: "checkmark.seal.fill").foregroundStyle(.green).font(.headline)
                    } else {
                        ProgressView(value: badge.progress) {
                            Text("%\(Int(badge.progress * 100)) tamamlandı").font(.subheadline)
                        }
                        .tint(style.color)
                        .padding(.horizontal, 40)
                    }
                }
                .padding(24)
                .presentationDetents([.height(340)])
            }
        }
    }
}
