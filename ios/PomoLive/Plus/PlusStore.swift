import Foundation
import Observation
import StoreKit

/// PomoLive Plus: what is on sale and whether this reader has it. StoreKit handles the purchase;
/// every signed transaction is sent to the server, which verifies it and unlocks Plus for the
/// account on all devices. The server's answer is the truth; a fresh local entitlement only
/// bridges the moment before the server has seen it.
@MainActor
@Observable
final class PlusStore {
    static let productIds = ["com.baransel.pomolive.plus.yearly", "com.baransel.pomolive.plus.monthly"]

    private(set) var status = PlusStatus(active: false)
    private(set) var hasLocalEntitlement = false

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(socket: LibrarySocket) {
        self.socket = socket
        // Renewals, purchases made on other devices and refunds arrive here while the app runs.
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(update)
            }
        }
    }

    var isActive: Bool { status.active || hasLocalEntitlement }

    /// After every sign-in: asks the server, then hands it any entitlement StoreKit holds.
    func signedIn() async {
        if let result = try? await socket.send(PlusStatusCommand()) { status = result.status }
        await syncEntitlements()
    }

    /// "Satın Alımları Geri Yükle": re-reads the Apple Account's purchases.
    func restore() async throws {
        try await AppStore.sync()
        await syncEntitlements()
    }

    func reset() {
        status = PlusStatus(active: false)
        hasLocalEntitlement = false
    }

    private func syncEntitlements() async {
        var found = false
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement, Self.productIds.contains(transaction.productID) else { continue }
            found = true
            await upload(entitlement)
        }
        hasLocalEntitlement = found
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result, Self.productIds.contains(transaction.productID) else { return }
        hasLocalEntitlement = transaction.revocationDate == nil && (transaction.expirationDate ?? .distantFuture) > .now
        await upload(result)
        await transaction.finish()
    }

    private func upload(_ result: VerificationResult<Transaction>) async {
        guard let response = try? await socket.send(SyncPlusCommand(signedTransaction: result.jwsRepresentation)) else { return }
        status = response.status
    }
}

/// What Plus unlocks, mirrored from the server's `plus-catalog.ts` so the app can show locks.
enum PlusCatalog {
    static let freeRoomLimit = 2
    static let themes: Set<RoomTheme> = [.forest, .beach, .space]
    static let avatars: Set<AvatarSprite> = [.wizard, .cat, .blonde, .ponytail, .flower, .pinkBuns]
    static let sounds: Set<AmbientSound> = [.waves, .fireplace, .pink]
}
