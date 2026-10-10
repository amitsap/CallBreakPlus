import StoreKit
import OSLog

private let storeLog = Logger(subsystem: "edu.amitsapkota.callbreakplus", category: "store")

/// The only type that talks to StoreKit. Owns Pro entitlement state; gating decisions
/// go through `ProGate`.
@Observable
@MainActor
final class ProStore {
    static let productID = "edu.amitsapkota.callbreakplus.pro"

    enum PurchaseState: Equatable {
        case idle
        case purchasing
        /// Ask to Buy: the purchase arrives later through `Transaction.updates`.
        case pending
        case failed
        case purchased
    }

    private(set) var hasPro = false
    private(set) var product: Product?
    private(set) var isLoadingProduct = false
    private(set) var purchaseState: PurchaseState = .idle
    /// What the Pro panel offers now; see `ProOffer`.
    var offer: ProOffer {
        ProOffer.resolve(hasPro: hasPro, price: product?.price, displayPrice: product?.displayPrice, isLoadingProduct: isLoadingProduct, purchaseState: purchaseState)
    }

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    @ObservationIgnored private var refreshGeneration = 0

    /// Call once at launch. Never blocks on the network: entitlements are cached on device.
    func start() async {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                await self.handle(update)
            }
        }
        await refresh()
    }

    /// Pro is on when a verified, unrevoked transaction for the product is current.
    /// Covers refunds, family-shared copies and offline launches. Refreshes overlap (launch
    /// and `Transaction.updates` both trigger one), so only the most recently started read
    /// may write: an earlier, slower read must not overwrite a fresher answer. A cancelled
    /// read may have ended early, so it never writes either.
    func refresh() async {
        refreshGeneration += 1
        let generation = refreshGeneration
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.productID == Self.productID,
                  transaction.revocationDate == nil else { continue }
            entitled = true
        }
        guard generation == refreshGeneration, !Task.isCancelled else { return }
        hasPro = entitled
        if entitled, purchaseState == .pending || purchaseState == .failed {
            purchaseState = .purchased
        }
    }

    /// Leaves `product` nil when the store is unreachable or the product isn't approved;
    /// the UI shows "unavailable" rather than a price.
    func loadProduct() async {
        guard product == nil, !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            product = try await Product.products(for: [Self.productID]).first
        } catch {
            storeLog.error("Loading the Pro product failed: \(error)")
        }
    }

    func purchase() async {
        guard let product, purchaseState != .purchasing else { return }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let result):
                // Judged from the transaction, not `hasPro`: a newer refresh may overtake
                // this one's, so `hasPro` can still be false here.
                purchaseState = await handle(result) ? .purchased : .failed
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            storeLog.error("Pro purchase failed: \(error)")
            purchaseState = .failed
        }
    }

    enum RestoreResult: Equatable {
        case synced
        /// The player dismissed the Apple Account sign-in.
        case cancelled
        case failed
    }

    /// Restore Purchases: App Review requires it for non-consumables. Refreshes either
    /// way, because entitlements already on the device still count.
    @discardableResult
    func restore() async -> RestoreResult {
        let result: RestoreResult
        do {
            try await AppStore.sync()
            result = .synced
        } catch StoreKitError.userCancelled {
            result = .cancelled
        } catch {
            storeLog.error("Restoring purchases failed: \(error)")
            result = .failed
        }
        await refresh()
        return result
    }

    /// An unverified transaction is never finished and never grants Pro. Returns whether
    /// the transaction is a verified, unrevoked Pro purchase.
    @discardableResult
    private func handle(_ result: VerificationResult<Transaction>) async -> Bool {
        guard case .verified(let transaction) = result else {
            storeLog.error("Ignoring an unverified transaction")
            return false
        }
        await transaction.finish()
        await refresh()
        return transaction.productID == Self.productID && transaction.revocationDate == nil
    }
}
