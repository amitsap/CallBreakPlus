import Foundation

/// What the Pro panel's purchase area shows, resolved from `ProStore`'s state. Pure, so
/// its promises are tested without StoreKit: an owner always sees the thank-you state,
/// and a missing or zero price never reaches a button.
enum ProOffer: Equatable {
    /// The product is still loading: a disabled button with a placeholder.
    case loading
    /// Offline on first launch, or not approved yet: "Pro isn't available right now".
    case unavailable
    case available(price: String)
    case purchasing
    /// Ask to Buy: Pro arrives through `Transaction.updates` once approved.
    case pending
    /// The purchase failed; Retry buys again at this price.
    case failed(price: String)
    case owned

    /// A cancelled purchase leaves `purchaseState` idle, so it returns to `.available`
    /// silently. A `.purchased` state without `hasPro` (a later refund) offers Pro again.
    static func resolve(hasPro: Bool, price: Decimal?, displayPrice: String?, isLoadingProduct: Bool, purchaseState: ProStore.PurchaseState) -> ProOffer {
        if hasPro { return .owned }
        switch purchaseState {
        case .purchasing: return .purchasing
        case .pending: return .pending
        case .idle, .failed, .purchased: break
        }
        guard let price, price > 0, let displayPrice, !displayPrice.isEmpty else {
            return isLoadingProduct ? .loading : .unavailable
        }
        return purchaseState == .failed ? .failed(price: displayPrice) : .available(price: displayPrice)
    }
}
