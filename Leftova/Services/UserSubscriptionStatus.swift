//
//  UserSubscriptionStatus 2.swift
//  Leftova
//
//  Created by Zach Rich on 8/7/25.
//


// File: Services/SubscriptionService.swift

import Foundation
import StoreKit
import Supabase

// MARK: - Subscription Models
struct UserSubscriptionStatus: Codable {
    let userId: String
    let email: String?
    let subscriptionTier: String
    let subscriptionStatus: String?
    let trialEndsAt: Date?
    let currentPeriodEnd: Date?
    let productId: String?
    
    var isPremium: Bool {
        return subscriptionTier == "premium" || isTrialActive
    }
    
    var isTrialActive: Bool {
        guard let trialEndsAt = trialEndsAt else { return false }
        return trialEndsAt > Date()
    }
    
    var daysLeftInTrial: Int? {
        guard let trialEndsAt = trialEndsAt, isTrialActive else { return nil }
        let calendar = Calendar.current
        let now = Date()
        let daysRemaining = calendar.dateComponents([.day], from: now, to: trialEndsAt).day ?? 0
        return max(0, daysRemaining)
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case subscriptionTier = "subscription_tier"
        case subscriptionStatus = "subscription_status"
        case trialEndsAt = "trial_ends_at"
        case currentPeriodEnd = "current_period_end"
        case productId = "product_id"
    }
}

// MARK: - Subscription Service
@MainActor
class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()
    
    @Published var subscriptionStatus: UserSubscriptionStatus?
    @Published var isLoadingStatus = false
    @Published var hasActiveSubscription = false
    
    private let supabase = SupabaseService.shared.client
    private let authService = AuthenticationService.shared
    
    private init() {
        Task {
            await refreshSubscriptionStatus()
        }
    }
    
    // MARK: - Subscription Status
    func refreshSubscriptionStatus() async {
        guard let userId = authService.currentUserId else {
            print("No user ID available")
            return
        }
        
        isLoadingStatus = true
        defer { isLoadingStatus = false }
        
        do {
            // First, ensure user profile exists
            await ensureUserProfile(userId: userId)
            
            // Then fetch the subscription status
            let response = try await supabase
                .from("user_profiles")
                .select("*, user_subscriptions!user_subscriptions_user_id_fkey(*)")
                .eq("id", value: userId)
                .single()
                .execute()
            
            // Parse the response manually since we have a joined query
            if let json = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                let status = UserSubscriptionStatus(
                    userId: userId,
                    email: json["email"] as? String,
                    subscriptionTier: json["subscription_tier"] as? String ?? "free",
                    subscriptionStatus: json["subscription_status"] as? String,
                    trialEndsAt: parseDate(json["trial_ends_at"] as? String),
                    currentPeriodEnd: parseDate(getCurrentPeriodEnd(from: json)),
                    productId: getProductId(from: json)
                )
                
                self.subscriptionStatus = status
                self.hasActiveSubscription = status.isPremium
            }
        } catch {
            print("Failed to fetch subscription status: \(error)")
            // Set default free status
            self.subscriptionStatus = UserSubscriptionStatus(
                userId: userId,
                email: authService.currentUser?.email,
                subscriptionTier: "free",
                subscriptionStatus: "inactive",
                trialEndsAt: nil,
                currentPeriodEnd: nil,
                productId: nil
            )
            self.hasActiveSubscription = false
        }
    }
    
    // MARK: - Trial Management
    func startFreeTrial() async -> Bool {
        guard let userId = authService.currentUserId else { return false }
        
        do {
            struct TrialParams: Codable {
                let p_user_id: String
                let p_days: Int
            }
            
            let params = TrialParams(p_user_id: userId, p_days: Config.FreeTier.trialDurationDays)
            
            let response = try await supabase
                .rpc("start_free_trial", params: params)
                .execute()
            
            // Function returns jsonb, parse manually
            if let data = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any],
               let success = data["success"] as? Bool {
                
                if success {
                    await refreshSubscriptionStatus()
                }
                
                return success
            }
        } catch {
            print("Failed to start trial: \(error)")
        }
        
        return false
    }
    
    // MARK: - Sync with Apple
    func syncWithApple(transaction: Transaction) async {
        guard let userId = authService.currentUserId else { return }
        
        do {
            // Fix: Use properly typed dictionary that conforms to Encodable
            struct SubscriptionData: Codable {
                let user_id: String
                let apple_transaction_id: String
                let product_id: String
                let status: String
                let current_period_start: String
                let current_period_end: String
            }
            
            let subscriptionData = SubscriptionData(
                user_id: userId,
                apple_transaction_id: String(transaction.id),
                product_id: transaction.productID,
                status: "active",
                current_period_start: ISO8601DateFormatter().string(from: transaction.purchaseDate),
                current_period_end: ISO8601DateFormatter().string(from: transaction.expirationDate ?? Date().addingTimeInterval(2592000)) // 30 days default
            )
            
            // Upsert subscription record
            _ = try await supabase
                .from("user_subscriptions")
                .upsert(subscriptionData)
                .execute()
            
            // Update user profile to premium
            struct UserProfileUpdate: Codable {
                let subscription_tier: String
                let subscription_status: String
            }
            
            let profileUpdate = UserProfileUpdate(
                subscription_tier: "premium",
                subscription_status: "active"
            )
            
            _ = try await supabase
                .from("user_profiles")
                .update(profileUpdate)
                .eq("id", value: userId)
                .execute()
            
            await refreshSubscriptionStatus()
            
            // Refresh usage stats after subscription update
            await UsageService.shared.refreshUsageStats()
            
        } catch {
            print("Failed to sync with Apple: \(error)")
        }
    }
    
    // MARK: - Cancel Subscription
    func cancelSubscription() async {
        guard let userId = authService.currentUserId else { return }
        
        do {
            // Fix: Use properly typed structures
            struct SubscriptionUpdate: Codable {
                let status: String
                let canceled_at: String
            }
            
            let subscriptionUpdate = SubscriptionUpdate(
                status: "canceled",
                canceled_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // Update subscription status
            _ = try await supabase
                .from("user_subscriptions")
                .update(subscriptionUpdate)
                .eq("user_id", value: userId)
                .eq("status", value: "active")
                .execute()
            
            // Update user profile
            struct UserProfileUpdate: Codable {
                let subscription_status: String
            }
            
            let profileUpdate = UserProfileUpdate(subscription_status: "canceled")
            
            _ = try await supabase
                .from("user_profiles")
                .update(profileUpdate)
                .eq("id", value: userId)
                .execute()
            
            await refreshSubscriptionStatus()
        } catch {
            print("Failed to cancel subscription: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func ensureUserProfile(userId: String) async {
        do {
            // Check if profile exists
            let response = try await supabase
                .from("user_profiles")
                .select("id")
                .eq("id", value: userId)
                .execute()
            
            // If no profile exists, create one
            if let data = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
               data.isEmpty {
                
                struct UserProfile: Codable {
                    let id: String
                    let email: String
                    let subscription_tier: String
                    let subscription_status: String
                }
                
                let newProfile = UserProfile(
                    id: userId,
                    email: authService.currentUser?.email ?? "",
                    subscription_tier: "free",
                    subscription_status: "inactive"
                )
                
                _ = try? await supabase
                    .from("user_profiles")
                    .insert(newProfile)
                    .execute()
            }
        } catch {
            print("Error ensuring user profile: \(error)")
        }
    }
    
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
    
    private func getCurrentPeriodEnd(from json: [String: Any]) -> String? {
        if let subscriptions = json["user_subscriptions"] as? [[String: Any]],
           let activeSubscription = subscriptions.first(where: { $0["status"] as? String == "active" }) {
            return activeSubscription["current_period_end"] as? String
        }
        return nil
    }
    
    private func getProductId(from json: [String: Any]) -> String? {
        if let subscriptions = json["user_subscriptions"] as? [[String: Any]],
           let activeSubscription = subscriptions.first(where: { $0["status"] as? String == "active" }) {
            return activeSubscription["product_id"] as? String
        }
        return nil
    }
}

// MARK: - App Store Receipt Validation (Optional)
extension SubscriptionService {
    func validateReceipt() async -> Bool {
        // This is for server-side receipt validation
        // You would typically send the receipt to your server
        // which then validates with Apple's servers
        
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: appStoreReceiptURL.path) else {
            print("No receipt found")
            return false
        }
        
        do {
            let receiptData = try Data(contentsOf: appStoreReceiptURL)
            let receiptString = receiptData.base64EncodedString()
            
            // Send to your server for validation
            // For now, we'll just return true if we have a receipt
            return !receiptString.isEmpty
        } catch {
            print("Error reading receipt: \(error)")
            return false
        }
    }
}
