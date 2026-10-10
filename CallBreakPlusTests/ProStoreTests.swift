import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import CallBreakPlus

/// `SKTestSession` is process-wide state, so these run one at a time from a clean session.
/// Runs only where the StoreKit test environment is active. On the iOS 26.5 simulator
/// runtime storekitd rejects the app as "not installed for development" (FB22237318), so
/// product requests fall through to production, which has the real product since App Store
/// Connect created it, and a purchase there waits on an Apple Account sign-in. Only the test
/// environment honours a simulated failure, so that is the probe. iOS 27 works.
@Suite(
    "Pro Store", .serialized,
    .enabled("StoreKit test environment is active (needs an iOS 27+ simulator, FB22237318)") {
        let session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts
        )
        let reachedProduction = (try? await Product.products(for: [ProStore.productID]).isEmpty) == false
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        let products = try await Product.products(for: [ProStore.productID])
        return !reachedProduction && !products.isEmpty
    }
)
@MainActor
struct ProStoreTests {
    let session: SKTestSession

    init() async throws {
        session = try SKTestSession(configurationFileNamed: "Products")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        try await session.setSimulatedError(nil, forAPI: .appStoreSync)
    }

    private func loadedStore() async throws -> ProStore {
        let store = ProStore()
        await store.loadProduct()
        try #require(store.product != nil)
        return store
    }

    /// storekitd applies refunds asynchronously (gone from `currentEntitlements` within
    /// ~0.5 s), so entitlement changes are awaited through the store's update listener.
    private func eventually(_ condition: () -> Bool) async throws -> Bool {
        for _ in 0..<40 where !condition() {
            try await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    @Test func productLoadsFromConfiguration() async throws {
        let store = try await loadedStore()
        #expect(store.product?.id == ProStore.productID)
        #expect(store.product?.type == .nonConsumable)
        #expect(!store.isLoadingProduct)
        #expect(!store.hasPro)
    }

    @Test func unreachableStoreLeavesProductUnavailable() async throws {
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts
        )
        let store = ProStore()
        await store.loadProduct()
        #expect(store.product == nil)
        #expect(!store.isLoadingProduct)
    }

    @Test func purchaseGrantsPro() async throws {
        let store = try await loadedStore()
        await store.purchase()
        #expect(store.purchaseState == .purchased)
        #expect(store.hasPro)
    }

    @Test func refundRevokesPro() async throws {
        let store = try await loadedStore()
        await store.start()
        await store.purchase()
        try #require(store.hasPro)

        let transaction = try #require(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        #expect(try await eventually { !store.hasPro })
    }

    @Test func askToBuyStaysPendingWithoutPro() async throws {
        session.askToBuyEnabled = true
        let store = try await loadedStore()
        await store.purchase()
        #expect(store.purchaseState == .pending)
        await store.refresh()
        #expect(!store.hasPro)
    }

    @Test func failedPurchaseLeavesProOff() async throws {
        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase
        )
        let store = try await loadedStore()
        await store.purchase()
        #expect(store.purchaseState == .failed)
        #expect(!store.hasPro)
    }

    @Test func failedRestoreKeepsPro() async throws {
        let store = try await loadedStore()
        await store.purchase()
        try #require(store.hasPro)

        try await session.setSimulatedError(
            .generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync
        )
        #expect(await store.restore() == .failed)
        #expect(store.hasPro)
    }

    @Test func restoreWithoutPurchaseLeavesProOff() async throws {
        let store = ProStore()
        #expect(await store.restore() == .synced)
        #expect(!store.hasPro)
    }

    @Test func cancelledSignInIsReportedAsCancelled() async throws {
        let store = ProStore()
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .appStoreSync)
        #expect(await store.restore() == .cancelled)
        #expect(!store.hasPro)
    }

    @Test func startReadsCachedEntitlement() async throws {
        let firstLaunch = try await loadedStore()
        await firstLaunch.purchase()
        try #require(firstLaunch.hasPro)

        let relaunch = ProStore()
        await relaunch.start()
        #expect(relaunch.hasPro)
    }
}
