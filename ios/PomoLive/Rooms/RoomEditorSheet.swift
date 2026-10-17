import SwiftUI

/// Name, icon and visibility of a room: blank for a new one, filled in when the owner edits theirs.
/// Private rooms are shared with a 6-character code.
struct RoomEditorSheet: View {
    struct Draft {
        var name: String
        var symbol: String
        var color: GlyphColor
        var visibility: RoomKind
        var theme: RoomTheme
        var description: String
    }

    /// The room being edited; `nil` creates a new one.
    let room: RoomState?
    /// Floor plans by theme, for the previews.
    let layouts: [String: LibraryLayout]
    let onSave: (Draft) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Draft
    @State private var isSaving = false
    @State private var error: LibraryError?

    init(room: RoomState? = nil, layouts: [String: LibraryLayout], onSave: @escaping (Draft) async throws -> Void) {
        self.room = room
        self.layouts = layouts
        self.onSave = onSave
        _draft = State(initialValue: room.map {
            Draft(name: $0.name, symbol: $0.symbol, color: $0.color, visibility: $0.kind, theme: $0.roomTheme, description: $0.description ?? "")
        } ?? Draft(name: "", symbol: "books.vertical.fill", color: .indigo, visibility: .private, theme: .classic, description: ""))
    }

    private static let descriptionLimit = 200

    private var trimmedName: String { draft.name.trimmingCharacters(in: .whitespaces) }

    private var hasChanges: Bool {
        guard let room else { return true }
        return trimmedName != room.name || draft.symbol != room.symbol || draft.color != room.color || draft.visibility != room.kind || draft.theme != room.roomTheme
            || draft.description != (room.description ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        GlyphIcon(symbol: draft.symbol, color: draft.color, size: 84)
                            .contentTransition(.symbolEffect(.replace))
                        TextField("Oda Adı", text: $draft.name)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 10)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                            .onChange(of: draft.name) { draft.name = String(draft.name.prefix(32)) }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    TextField("Bu odada neler yapılıyor, hedef ne?", text: $draft.description, axis: .vertical)
                        .lineLimit(3...6)
                        .onChange(of: draft.description) { _, text in
                            if text.count > Self.descriptionLimit { draft.description = String(text.prefix(Self.descriptionLimit)) }
                        }
                } header: {
                    Text("Açıklama")
                } footer: {
                    Text("Katılmadan önce herkes bunu okur. \(draft.description.count)/\(Self.descriptionLimit)")
                }

                Section {
                    ThemePicker(selection: $draft.theme, layouts: layouts, kept: room?.roomTheme)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                } header: {
                    Text("Mekan")
                }

                Section {
                    Picker("Görünürlük", selection: $draft.visibility) {
                        Text("Özel").tag(RoomKind.private)
                        Text("Herkese Açık").tag(RoomKind.public)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(draft.visibility == .private
                        ? "Yalnızca kodu paylaştığın kişiler girebilir."
                        : "Keşfet'te herkes görür ve girebilir.")
                }

                GlyphPicker(symbol: $draft.symbol, color: $draft.color)
            }
            .navigationTitle(room == nil ? "Yeni Oda" : "Odayı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(room == nil ? "Oluştur" : "Kaydet", systemImage: "checkmark", action: save)
                            .disabled(trimmedName.count < 2 || !hasChanges)
                    }
                }
            }
            .errorAlert($error)
        }
    }

    private func save() {
        isSaving = true
        var draft = draft
        draft.name = trimmedName
        draft.description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            defer { isSaving = false }
            do {
                try await onSave(draft)
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
