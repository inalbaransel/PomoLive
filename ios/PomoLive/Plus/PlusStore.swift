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
    /// Yearly first; empty until the App Store answers.
    private(set) var products: [Product] = []
    private(set) var isEligibleForTrial = true
    private(set) var productsFailed = false

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

    func loadProducts() async {
        guard products.isEmpty else { return }
        productsFailed = false
        do {
            let loaded = try await Product.products(for: Self.productIds)
            products = Self.productIds.compactMap { id in loaded.first { $0.id == id } }
            productsFailed = products.isEmpty
            if let yearly = products.first { isEligibleForTrial = await yearly.subscription?.isEligibleForIntroOffer ?? false }
        } catch {
            productsFailed = true
        }
    }

    /// Buys `product`; true once it went through. Pending (Ask to Buy) and cancelled return false.
    func purchase(_ product: Product) async throws -> Bool {
        switch try await product.purchase() {
        case .success(let result):
            await handle(result)
            return true
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
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
