import SwiftUI

/// Name, icon and visibility for a new room. Private rooms are shared with a 6-character code.
struct CreateRoomSheet: View {
    let onCreate: (String, String, GlyphColor, RoomKind) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var symbol = "books.vertical.fill"
    @State private var color = GlyphColor.indigo
    @State private var visibility: RoomKind = .private
    @State private var isCreating = false
    @State private var error: LibraryError?

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 16) {
                        GlyphIcon(symbol: symbol, color: color, size: 84)
                            .contentTransition(.symbolEffect(.replace))
                        TextField("Oda Adı", text: $name)
                            .font(.title3.weight(.semibold))
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 10)
                            .background(.fill.tertiary, in: .rect(cornerRadius: 12))
                            .onChange(of: name) { name = String(name.prefix(32)) }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Picker("Görünürlük", selection: $visibility) {
                        Text("Özel").tag(RoomKind.private)
                        Text("Herkese Açık").tag(RoomKind.public)
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    Text(visibility == .private
                        ? "Yalnızca kodu paylaştığın kişiler girebilir."
                        : "Keşfet'te herkes görür ve girebilir.")
                }

                GlyphPicker(symbol: $symbol, color: $color)
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
                try await onCreate(trimmedName, symbol, color, visibility)
                dismiss()
            } catch {
                self.error = LibraryError(error)
            }
        }
    }
}
