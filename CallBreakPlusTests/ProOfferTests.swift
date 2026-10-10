import Foundation
import Testing
@testable import CallBreakPlus

@Suite("Pro Offer")
struct ProOfferTests {
    private func offer(
        hasPro: Bool = false,
        price: Decimal? = 2.99,
        displayPrice: String? = "$2.99",
        loading: Bool = false,
        state: ProStore.PurchaseState = .idle
    ) -> ProOffer {
        ProOffer.resolve(hasPro: hasPro, price: price, displayPrice: displayPrice, isLoadingProduct: loading, purchaseState: state)
    }

    @Test func showsTheStorePrice() {
        #expect(offer() == .available(price: "$2.99"))
    }

    @Test func loadingWithoutAPriceShowsThePlaceholder() {
        #expect(offer(price: nil, displayPrice: nil, loading: true) == .loading)
    }

    @Test func noProductIsUnavailable() {
        #expect(offer(price: nil, displayPrice: nil) == .unavailable)
    }

    @Test func aZeroOrEmptyPriceIsNeverOffered() {
        #expect(offer(price: 0, displayPrice: "$0.00") == .unavailable)
        #expect(offer(displayPrice: "") == .unavailable)
    }

    @Test(arguments: [ProStore.PurchaseState.idle, .purchasing, .pending, .failed, .purchased])
    func anOwnerAlwaysSeesThankYou(state: ProStore.PurchaseState) {
        #expect(offer(hasPro: true, price: nil, displayPrice: nil, state: state) == .owned)
    }

    @Test func purchasingAndPendingWinOverThePrice() {
        #expect(offer(state: .purchasing) == .purchasing)
        #expect(offer(state: .pending) == .pending)
    }

    @Test func aFailureOffersRetryAtThePrice() {
        #expect(offer(state: .failed) == .failed(price: "$2.99"))
    }

    @Test func aFailureWithoutAProductIsUnavailable() {
        #expect(offer(price: nil, displayPrice: nil, state: .failed) == .unavailable)
    }

    @Test func aRefundAfterPurchaseOffersProAgain() {
        #expect(offer(state: .purchased) == .available(price: "$2.99"))
    }
}
