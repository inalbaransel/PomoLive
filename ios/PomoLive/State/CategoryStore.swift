import Observation

/// Built-in categories plus the reader's own.
@MainActor
@Observable
final class CategoryStore {
    private(set) var builtIn: [FocusCategory] = []
    private(set) var custom: [FocusCategory] = []

    @ObservationIgnored private let socket: LibrarySocket

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    var all: [FocusCategory] { builtIn + custom }

    func refresh() async {
        guard let result = try? await socket.send(ListCategoriesCommand()) else { return }
        builtIn = result.builtIn
        custom = result.custom
    }

    func create(name: String, emoji: String) async throws -> FocusCategory {
        let category = try await socket.send(CreateCategoryCommand(name: name, emoji: emoji)).category
        custom.append(category)
        return category
    }

    func delete(_ category: FocusCategory) async throws {
        guard let id = category.customId else { return }
        _ = try await socket.send(DeleteCategoryCommand(id: id))
        custom.removeAll { $0.key == category.key }
    }

    func reset() {
        builtIn = []
        custom = []
    }
}
