//
//  UsageService.swift
//  Leftova
//
//  Modern usage tracking service with clean architecture
//  
//  This service manages user usage limits, tracks actions, and enforces
//  freemium model restrictions. It provides real-time usage monitoring
//  and server-side validation to prevent client-side bypassing.
//

import Foundation
import SwiftUI
import Supabase

// MARK: - Usage Service Protocol

/**
 Protocol defining the interface for usage tracking and limit enforcement.
 
 This protocol abstracts usage management to enable testing with mock
 implementations and maintain clean separation of concerns.
 */
protocol UsageServiceProtocol {
    // MARK: - Published Properties
    
    /// Number of searches remaining for current user today
    var searchesRemaining: Int { get }
    
    /// Number of recipe save slots remaining for current user
    var recipeSlotsRemaining: Int { get }
    
    /// Whether user can perform multi-ingredient searches
    var canUseAdvancedSearch: Bool { get }
    
    /// Current subscription tier ("free" or "premium")
    var currentTier: String { get }
    
    /// Whether user has premium subscription
    var isPremium: Bool { get }
    
    /// Complete usage statistics from server
    var usageStats: UsageStats? { get }
    
    // MARK: - Methods
    
    /**
     Check if user can perform an action and execute it if allowed.
     
     This method performs server-side validation to prevent client-side
     bypassing of usage limits. It updates local state upon successful
     action execution.
     
     - Parameter action: The user action to check and perform
     - Returns: true if action was allowed and performed, false otherwise
     */
    func checkAndPerformAction(_ action: UserAction) async -> Bool
    
    /**
     Refresh usage statistics from server.
     
     This method fetches the latest usage data from the server and updates
     local state. Should be called periodically and after actions that
     may affect usage counts.
     */
    func refreshUsageStats() async
}

// MARK: - Usage Service Implementation

/**
 Singleton service for managing user usage limits and subscription tiers.
 
 This service provides real-time usage tracking with server-side validation,
 ensuring that usage limits cannot be bypassed on the client side. It uses
 Supabase RPC functions for secure limit enforcement and maintains local
 state for immediate UI updates.
 
 Key Features:
 - Server-side validation prevents client tampering
 - Real-time UI updates via @Published properties
 - Configurable limits via Config.swift
 - Premium tier detection and handling
 - Comprehensive error handling and fallbacks
 
 Usage:
 ```swift
 let allowed = await UsageService.shared.checkAndPerformAction(.search)
 if allowed {
     // Perform search operation
 } else {
     // Show paywall or limit message
 }
 ```
 */
@MainActor
final class UsageService: UsageServiceProtocol, ObservableObject {
    
    /// Shared singleton instance for app-wide usage tracking
    static let shared = UsageService()
    
    // MARK: - Published Properties
    
    /// Number of searches remaining for today (triggers UI updates)
    @Published var searchesRemaining = Config.FreeTier.dailySearchLimit
    
    /// Number of recipe save slots remaining (triggers UI updates)
    @Published var recipeSlotsRemaining = Config.FreeTier.savedRecipesLimit
    
    /// Whether multi-ingredient search is available (premium feature)
    @Published var canUseAdvancedSearch = Config.FreeTier.canUseAdvancedSearch
    
    /// Current subscription tier ("free" or "premium")
    @Published var currentTier = "free"
    
    /// Loading state for async operations
    @Published var isLoading = false
    
    /// Complete usage statistics from server (optional, may be nil during loading)
    @Published var usageStats: UsageStats?
    
    // MARK: - Dependencies
    
    /// Supabase client for server communication
    private let supabase = SupabaseService.shared.client
    
    /// Authentication service for user identification
    private let authService = AuthenticationService.shared
    
    // MARK: - Computed Properties
    
    /// True if user has premium subscription
    var isPremium: Bool {
        currentTier == "premium"
    }
    
    /// True if user has exhausted daily search limit
    var hasReachedSearchLimit: Bool {
        searchesRemaining <= 0 && !isPremium
    }
    
    /// True if user has reached maximum saved recipes
    var hasReachedSaveLimit: Bool {
        recipeSlotsRemaining <= 0 && !isPremium
    }
    
    /// True if user can search with multiple ingredients (premium feature)
    var canSearchMultipleIngredients: Bool {
        isPremium || canUseAdvancedSearch
    }
    
    // MARK: - Initialization
    
    /**
     Private initializer for singleton pattern.
     
     Automatically refreshes usage statistics on initialization to ensure
     UI displays current usage status immediately.
     */
    private init() {
        Task {
            await refreshUsageStats()
        }
    }
    
    // MARK: - Public Methods
    
    /**
     Check if user can perform an action and execute it if allowed.
     
     This is the core method for usage limit enforcement. It performs a
     server-side check to prevent client-side bypassing of limits, then
     updates local state if the action is allowed.
     
     Process:
     1. Pre-check local capacity (quick UI feedback)
     2. Verify user authentication
     3. Call server RPC function for validation
     4. Parse server response and update local state
     5. Return whether action was allowed
     
     - Parameter action: The UserAction to validate (search, save, etc.)
     - Returns: true if action was allowed and recorded, false otherwise
     
     Example:
     ```swift
     let canSearch = await usageService.checkAndPerformAction(.search)
     if canSearch {
         // Proceed with search
         let recipes = try await repository.searchRecipes(...)
     } else {
         // Show upgrade prompt
         showPaywall = true
     }
     ```
     */
    func checkAndPerformAction(_ action: UserAction) async -> Bool {
        // Quick local check for immediate UI feedback
        guard hasLocalCapacity(for: action) else {
            return false
        }
        
        // Ensure user is authenticated for server validation
        guard let userId = authService.currentUserId else {
            return false
        }
        
        do {
            // Parameters for Supabase RPC function
            struct UsageParams: Codable {
                let p_user_id: String
                let p_action_type: String
                let p_metadata: [String: String]
            }
            
            let params = UsageParams(
                p_user_id: userId,
                p_action_type: action.rawValue,
                p_metadata: [:] // Future: could include search terms, etc.
            )
            
            // Call server-side validation function
            let response = try await supabase
                .rpc("check_and_record_usage", params: params)
                .execute()
            
            // Parse JSONB response from RPC function
            if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                let result = UsageResult(
                    allowed: jsonData["allowed"] as? Bool ?? false,
                    currentCount: jsonData["current_count"] as? Int ?? 0,
                    remaining: jsonData["remaining"] as? Int ?? 0,
                    limit: jsonData["limit"] as? Int ?? 0,
                    tier: jsonData["tier"] as? String ?? "free"
                )
                
                // Update local state if action was allowed
                if result.allowed {
                    await updateLocalLimits(action: action, result: result)
                }
                
                return result.allowed
            } else {
                return false
            }
        } catch {
            // Network error: fallback to local decision to maintain app functionality
            // Note: This could potentially allow bypassing in airplane mode, but
            // server will still validate on next successful connection
            return hasLocalCapacity(for: action)
        }
    }
    
    func refreshUsageStats() async {
        guard let userId = authService.currentUserId else {
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            struct StatsParams: Codable {
                let p_user_id: String
            }
            
            let params = StatsParams(p_user_id: userId)
            
            let response = try await supabase
                .rpc("get_usage_stats", params: params)
                .execute()
            
            // The function returns jsonb, parse it manually
            if let jsonData = try? JSONSerialization.jsonObject(with: response.data) as? [String: Any] {
                let stats = UsageStats(
                    tier: jsonData["tier"] as? String ?? "free",
                    searchesToday: jsonData["searches_today"] as? Int ?? 0,
                    searchesLimit: jsonData["searches_limit"] as? Int ?? Config.FreeTier.dailySearchLimit,
                    savedRecipes: jsonData["saved_recipes"] as? Int ?? 0,
                    savedRecipesLimit: jsonData["saved_recipes_limit"] as? Int ?? Config.FreeTier.savedRecipesLimit,
                    multiIngredientSearchesToday: jsonData["multi_ingredient_searches_today"] as? Int ?? 0,
                    multiIngredientLimit: jsonData["multi_ingredient_limit"] as? Int ?? Config.FreeTier.multiIngredientSearchLimit
                )
                
                await updateLocalState(with: stats)
            }
        } catch {
            await setDefaultLimits()
        }
    }
    
    // MARK: - Helper Methods
    func formattedLimitMessage(for action: UserAction) -> String {
        switch action {
        case .search, .ingredientSearch:
            if isPremium {
                return "Unlimited searches"
            }
            return searchesRemaining == 1
                ? "1 search remaining today"
                : "\(searchesRemaining) searches remaining today"
                
        case .saveRecipe:
            if isPremium {
                return "Unlimited saves"
            }
            return recipeSlotsRemaining == 1
                ? "1 save slot remaining"
                : "\(recipeSlotsRemaining) save slots remaining"
                
        case .multiIngredientSearch:
            if isPremium {
                return "Advanced search available"
            }
            return canUseAdvancedSearch
                ? "1 multi-ingredient search available"
                : "Upgrade for multi-ingredient search"
        }
    }
    
    func shouldShowLimitWarning(for action: UserAction) -> Bool {
        if isPremium { return false }
        
        switch action {
        case .search, .ingredientSearch:
            return searchesRemaining <= Config.FreeTier.WarningThresholds.searchesRemaining
        case .saveRecipe:
            return recipeSlotsRemaining <= Config.FreeTier.WarningThresholds.savedRecipesRemaining
        case .multiIngredientSearch:
            return !canUseAdvancedSearch
        }
    }
    
    func getLimitColor(for action: UserAction) -> Color {
        if isPremium { return .green }
        
        switch action {
        case .search, .ingredientSearch:
            if searchesRemaining == 0 { return .red }
            if searchesRemaining <= Config.FreeTier.WarningThresholds.searchesRemaining { return .orange }
            return .blue
            
        case .saveRecipe:
            if recipeSlotsRemaining == 0 { return .red }
            if recipeSlotsRemaining <= Config.FreeTier.WarningThresholds.savedRecipesRemaining { return .orange }
            return .blue
            
        case .multiIngredientSearch:
            return canUseAdvancedSearch ? .blue : .gray
        }
    }
    
    // MARK: - Private Methods
    private func hasLocalCapacity(for action: UserAction) -> Bool {
        if currentTier == "premium" {
            return true
        }
        
        switch action {
        case .search, .ingredientSearch:
            return searchesRemaining > 0
        case .saveRecipe:
            return recipeSlotsRemaining > 0
        case .multiIngredientSearch:
            return canUseAdvancedSearch
        }
    }
    
    private func updateLocalLimits(action: UserAction, result: UsageResult) async {
        currentTier = result.tier
        
        switch action {
        case .search, .ingredientSearch:
            searchesRemaining = result.remaining
            
        case .saveRecipe:
            if result.tier == "free" {
                recipeSlotsRemaining = max(0, result.limit - result.currentCount - 1)
            } else {
                recipeSlotsRemaining = Config.FreeTier.UI.unlimitedValue
            }
            
        case .multiIngredientSearch:
            canUseAdvancedSearch = result.tier == "premium" || result.remaining > 0
        }
    }
    
    private func updateLocalState(with stats: UsageStats) async {
        usageStats = stats
        currentTier = stats.tier
        searchesRemaining = stats.searchesRemaining
        recipeSlotsRemaining = stats.savedRecipesRemaining
        canUseAdvancedSearch = stats.tier == "premium" || stats.canUseMultiIngredientSearch
    }
    
    private func setDefaultLimits() async {
        currentTier = "free"
        searchesRemaining = Config.FreeTier.dailySearchLimit
        recipeSlotsRemaining = Config.FreeTier.savedRecipesLimit
        canUseAdvancedSearch = Config.FreeTier.canUseAdvancedSearch
        usageStats = nil
    }
}