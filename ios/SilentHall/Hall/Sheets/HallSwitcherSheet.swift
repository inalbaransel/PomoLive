import SwiftUI

/// Join a friend's private hall by code, open a new one, or go back to the public halls.
struct HallSwitcherSheet: View {
    let room: RoomState?
    let onJoin: (String) async -> Void
    let onCreate: () async -> Void
    let onReturnToPublic: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var isWorking = false

    private var normalizedCode: String { code.uppercased().filter { $0.isLetter || $0.isNumber } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("6 haneli kod", text: $code)
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .onChange(of: code) { code = String(normalizedCode.prefix(6)) }
                    Button("Salona Katıl", systemImage: "arrow.right.circle.fill") { run { await onJoin(normalizedCode) } }
                        .disabled(normalizedCode.count != 6 || isWorking)
                } header: {
                    Text("Arkadaşının salonu")
                }

                Section {
                    Button("Yeni Özel Salon Aç", systemImage: "plus.rectangle.on.rectangle") { run { await onCreate() } }
                    if room?.type == .private {
                        Button("Genel Salona Dön", systemImage: "building.columns") { run { await onReturnToPublic() } }
                    }
                } footer: {
                    Text("Özel salonlar bir kodla paylaşılır. Genel salonlar 25 kişiye ulaştığında yeni bir salon kendiliğinden açılır.")
                }
                .disabled(isWorking)
            }
            .navigationTitle("Salon Değiştir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
        }
    }

    private func run(_ action: @escaping () async -> Void) {
        isWorking = true
        Task {
            await action()
            dismiss()
        }
    }
}
