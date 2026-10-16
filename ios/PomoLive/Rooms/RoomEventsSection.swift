import SwiftUI

/// A room's upcoming events with "I'm coming" toggles; the owner can plan and cancel them.
/// Used in the room preview and in the room's events sheet.
struct RoomEventsList: View {
    let roomId: String
    let isOwner: Bool

    @Environment(AppModel.self) private var app
    @State private var plans = false
    @State private var eventToCancel: RoomEventItem?

    var body: some View {
        let events = app.events.events(in: roomId)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionTitle("Etkinlikler")
                Spacer()
                if isOwner {
                    Button("Planla", systemImage: "calendar.badge.plus") { plans = true }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            if events.isEmpty {
                Text(isOwner ? "Bir oturum planla; katılanlara başlamadan önce hatırlatma gider." : "Planlanmış bir etkinlik yok.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        EventRow(event: event, isOwner: isOwner) { eventToCancel = event }
                        if index < events.count - 1 { Divider().padding(.leading, 70) }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            }
        }
        .task(id: roomId) { await app.events.load(roomId) }
        .sheet(isPresented: $plans) {
            PlanEventSheet(roomId: roomId)
                .presentationDetents([.medium, .large])
        }
        .confirmationDialog(
            "Etkinlik iptal edilsin mi?",
            isPresented: Binding(get: { eventToCancel != nil }, set: { if !$0 { eventToCancel = nil } }),
            titleVisibility: .visible
        ) {
            Button("Etkinliği İptal Et", role: .destructive) {
                guard let event = eventToCancel else { return }
                Task { await app.events.delete(event) }
            }
        } message: {
            Text("Katılacağını söyleyenlerin hatırlatmaları da kaldırılır.")
        }
    }
}

private struct EventRow: View {
    let event: RoomEventItem
    let isOwner: Bool
    let onCancel: () -> Void

    @Environment(AppModel.self) private var app
    @State private var isWorking = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            let live = event.isLive(at: timeline.date)
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Text(event.start, format: .dateTime.month(.abbreviated).locale(.app))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(live ? .white : .red)
                        .textCase(.uppercase)
                    Text(event.start, format: .dateTime.day().locale(.app))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(live ? .white : .primary)
                }
                .frame(width: 46, height: 46)
                .background(live ? AnyShapeStyle(Color.green.gradient) : AnyShapeStyle(.fill.tertiary), in: .rect(cornerRadius: 12))

                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title).font(.body.weight(.semibold)).lineLimit(1)
                    Group {
                        if live {
                            Text("Şu an devam ediyor").foregroundStyle(.green)
                        } else {
                            Text("\(event.start.formatted(Date.FormatStyle(date: .omitted, time: .shortened, locale: .app))) · \(formattedFocus(Int64(event.durationMinutes) * 60_000))")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.subheadline)
                    .lineLimit(1)
                    Label("\(event.goingCount) katılıyor", systemImage: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                }
                Spacer(minLength: 4)
                if isOwner {
                    Menu("Seçenekler", systemImage: "ellipsis.circle") {
                        Button("Etkinliği İptal Et", systemImage: "xmark.circle", role: .destructive, action: onCancel)
                    }
                    .labelStyle(.iconOnly)
                } else {
                    Button {
                        isWorking = true
                        Task {
                            await app.events.setGoing(event, !event.isGoing)
                            isWorking = false
                        }
                    } label: {
                        Text(event.isGoing ? "Katılıyorsun" : "Katılacağım")
                    }
                    .buttonStyle(.bordered)
                    .tint(event.isGoing ? .green : .accentColor)
                    .controlSize(.small)
                    .disabled(isWorking)
                    .sensoryFeedback(.success, trigger: event.isGoing)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }
}

/// Title, start and length of a new event.
private struct PlanEventSheet: View {
    let roomId: String

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = Calendar.current.nextDate(after: .now, matching: DateComponents(minute: 0), matchingPolicy: .nextTime) ?? .now
    @State private var durationMinutes = 90
    @State private var isSaving = false
    @State private var error: LibraryError?

    private static let durations = [30, 60, 90, 120, 180, 240]

    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Örn. Sabah 3 pomodoro", text: $title)
                        .onChange(of: title) { title = String(title.prefix(60)) }
                }
                Section {
                    DatePicker("Başlangıç", selection: $start, in: Date.now...Date.now.addingTimeInterval(60 * 86_400))
                    Picker("Süre", selection: $durationMinutes) {
                        ForEach(Self.durations, id: \.self) { Text(formattedFocus(Int64($0) * 60_000)).tag($0) }
                    }
                } footer: {
                    Text("Katılacağını söyleyenlere 10 dakika önce ve başlarken hatırlatma gider.")
                }
            }
            .navigationTitle("Etkinlik Planla")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Planla", systemImage: "checkmark", action: save)
                            .disabled(trimmed.count < 2)
                    }
                }
            }
            .errorAlert($error)
        }
    }

    private func save() {
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await app.events.create(roomId: roomId, title: trimmed, start: start, durationMinutes: durationMinutes)
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
