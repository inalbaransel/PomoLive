import SwiftUI

/// Name, icon and visibility for a new room. Private rooms are shared with a 6-character code.
struct CreateRoomSheet: View {
    let onCreate: (String, String, RoomKind) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var emoji = Self.emojis[0]
    @State private var visibility: RoomKind = .private
    @State private var isCreating = false
    @State private var error: LibraryError?

    static let emojis = ["📚", "💻", "🌙", "☕️", "🎧", "🧠", "✍️", "🎨", "🌿", "🔥", "🎯", "🏛️", "🧪", "🎸", "🌊", "🚀"]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        EmojiTile(emoji: emoji, size: 56)
                        TextField("Oda adı", text: $name)
                            .font(.title3.weight(.semibold))
                            .onChange(of: name) { name = String(name.prefix(32)) }
                    }
                    .padding(.vertical, 4)
                }

                Section("Simge") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                        ForEach(Self.emojis, id: \.self) { option in
                            Button { emoji = option } label: {
                                Text(option)
                                    .font(.title3)
                                    .frame(width: 36, height: 36)
                                    .selectableBackground(emoji == option, in: .circle)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(emoji == option ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 6)
                    .animation(.spring(duration: 0.3), value: emoji)
                }

                Section {
                    Picker("Görünürlük", selection: $visibility) {
                        Label("Özel", systemImage: "lock.fill").tag(RoomKind.private)
                        Label("Herkese Açık", systemImage: "globe").tag(RoomKind.public)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(visibility == .private
                        ? "Yalnızca kodu paylaştığın kişiler girebilir."
                        : "Odalar listesinde herkes görür ve girebilir.")
                }
            }
            .navigationTitle("Yeni Oda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç", systemImage: "xmark", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Oluştur", systemImage: "checkmark", action: create)
                            .disabled(trimmedName.count < 2)
                    }
                }
            }
            .errorAlert($error)
        }
    }

    private func create() {
        isCreating = true
        Task {
            defer { isCreating = false }
            do {
                try await onCreate(trimmedName, emoji, visibility)
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
