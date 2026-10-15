import SwiftUI

/// Where a typed username stands, checked locally first and then against the server.
enum UsernameStatus: Equatable {
    case invalid
    case checking
    case available
    case taken
    /// The reader's current username, left as it is.
    case unchanged
    /// The availability check could not reach the server; the submit itself will decide.
    case unknown

    var allowsSubmit: Bool {
        switch self {
        case .available, .unchanged, .unknown: true
        case .invalid, .checking, .taken: false
        }
    }
}

/// A `@handle` text field that reports availability as the reader types. What is typed stays
/// untouched in the field; `username` receives its normalised form.
struct UsernameField: View {
    @Binding var username: String
    @Binding var status: UsernameStatus
    /// The reader's current username when editing a profile.
    var current: String?

    @Environment(AppModel.self) private var app
    @State private var text: String

    init(username: Binding<String>, status: Binding<UsernameStatus>, current: String? = nil) {
        _username = username
        _status = status
        self.current = current
        _text = State(initialValue: username.wrappedValue)
    }

    static let lengthRange = 3...20

    /// Mirrors the server: lowercase letters, digits, `_` and `.`, no leading, trailing or doubled dot.
    static func isValid(_ username: String) -> Bool {
        lengthRange.contains(username.count)
            && username.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_" || $0 == "." }
            && !username.hasPrefix(".") && !username.hasSuffix(".") && !username.contains("..")
    }

    /// Lowercase and without surrounding spaces, as the server stores it.
    static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces).lowercased()
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(verbatim: "@")
                .foregroundStyle(.secondary)
            // Rewriting the field's own text while typing drops keystrokes, so only the handle is normalised.
            TextField("kullaniciadi", text: $text)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .onChange(of: text) { username = Self.normalized(text) }
            indicator
                .animation(.smooth, value: status)
        }
        .task(id: username) { await check() }
    }

    @ViewBuilder
    private var indicator: some View {
        switch status {
        case .checking:
            ProgressView()
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Kullanılabilir")
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel("Alınmış")
        case .invalid, .unchanged, .unknown:
            EmptyView()
        }
    }

    private func check() async {
        if username == current { return status = .unchanged }
        guard Self.isValid(username) else { return status = .invalid }
        status = .checking
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }
        do {
            let available = try await app.isUsernameAvailable(username)
            guard !Task.isCancelled else { return }
            status = available ? .available : .taken
        } catch {
            status = .unknown
        }
    }
}

/// The footer under a `UsernameField`, explaining the rule or the problem.
struct UsernameFooter: View {
    let status: UsernameStatus
    let username: String

    var body: some View {
        switch status {
        case .taken:
            Text("@\(username) alınmış.")
                .foregroundStyle(.red)
        case .available:
            Text("@\(username) senin olabilir.")
        default:
            Text("3–20 karakter: küçük harf, rakam, alt çizgi ve nokta. Profilinde ve odalarda görünür.")
        }
    }
}
