// File: Services/StoreManager.swift
// StoreManager for In-App Purchases with explicit StoreKit namespaces

import Foundation
import SwiftUI
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var hasActiveSubscription = false
    @Published var isLoading = false
    
    private let productIds = [
        "com.leftova.premium.monthly",
        "com.leftova.premium.annual"
    ]
    
    private var updates: Task<Void, Never>?
    
    // Singleton pattern
    static let shared = StoreManager()
    
    private init() {
        self.updates = observeTransactionUpdates()
        
        Task {
            await checkPurchasedProducts()
        }
    }
    
    deinit {
        updates?.cancel()
    }
    
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            products = try await Product.products(for: productIds)
            print("StoreManager: Loaded \(products.count) products")
        } catch {
            print("StoreManager: Failed to load products: \(error)")
        }
    }
    
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        
        switch result {
        case let .success(verification):
            switch verification {
            case .verified(let transaction):
                // Update local state
                await transaction.finish()
                await checkPurchasedProducts()
                
                // Sync with backend
                await syncWithBackend(transaction)
                
                return true
                
            case .unverified(_, _):
                // Handle unverified transaction
                throw StoreError.verificationFailed
            }
            
        case .pending:
            // Transaction is pending
            throw StoreError.purchasePending
            
        case .userCancelled:
            // User cancelled
            throw StoreError.userCancelled
            
        @unknown default:
            throw StoreError.unknown
        }
    }
    
    func restorePurchases() async throws {
        // Sync with App Store to restore purchases
        try await StoreKit.AppStore.sync()
        await checkPurchasedProducts()
    }
    
    func checkPurchasedProducts() async {
        var purchased: Set<String> = []
        
        // Check all current entitlements - use explicit StoreKit.Transaction
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }
            
            // Check if the subscription is still valid
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        
        self.purchasedProductIDs = purchased
        self.hasActiveSubscription = !purchased.isEmpty
    }
    
    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            // Use explicit StoreKit.Transaction to avoid ambiguity
            for await result in StoreKit.Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await checkPurchasedProducts()
                }
            }
        }
    }
    
    private func syncWithBackend(_ transaction: StoreKit.Transaction) async {
        // Sync with your backend (Supabase)
        let subscriptionService = SubscriptionService.shared
        await subscriptionService.syncWithApple(transaction: transaction)
    }
}

// MARK: - Store Errors

enum StoreError: LocalizedError {
    case userCancelled
    case purchasePending
    case verificationFailed
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "Purchase was cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .verificationFailed:
            return "Purchase verification failed"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}
