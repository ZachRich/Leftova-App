//
//  ProfileViewModel.swift
//  Leftova
//
//  Created by Claude Code on 8/7/25.
//

import Foundation
import SwiftUI

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var user: AuthUser?
    @Published var subscriptionStatus: UserSubscriptionStatus?
    @Published var usageStats: UsageStats?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showingSignOutAlert = false
    @Published var showingDeleteAccount = false
    @Published var showingError = false
    @Published var savedRecipesCount = 0
    
    private let authService = AuthenticationService.shared
    private let subscriptionService = SubscriptionService.shared
    private let usageService = UsageService.shared
    private let repository: RecipeRepositoryProtocol
    
    init(repository: RecipeRepositoryProtocol = RecipeRepository()) {
        self.repository = repository
        self.user = authService.currentUser
        self.subscriptionStatus = subscriptionService.subscriptionStatus
        self.usageStats = usageService.usageStats
    }
    
    func refreshProfile() async {
        isLoading = true
        errorMessage = nil
        
        // Refresh user data
        do {
            user = try await authService.getCurrentUser()
        } catch {
            errorMessage = "Failed to load user data: \(error.localizedDescription)"
        }
        
        // Refresh subscription status
        await subscriptionService.refreshSubscriptionStatus()
        subscriptionStatus = subscriptionService.subscriptionStatus
        
        // Refresh usage stats
        await usageService.refreshUsageStats()
        usageStats = usageService.usageStats
        
        isLoading = false
    }
    
    func signOut() async {
        do {
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    func startFreeTrial() async {
        isLoading = true
        let success = await subscriptionService.startFreeTrial()
        
        if success {
            await refreshProfile()
        } else {
            errorMessage = "Failed to start free trial"
        }
        
        isLoading = false
    }
    
    // Computed properties
    var displayName: String {
        user?.email ?? "User"
    }
    
    var subscriptionDisplayName: String {
        subscriptionStatus?.subscriptionTier.capitalized ?? "Free"
    }
    
    var hasActiveSubscription: Bool {
        subscriptionStatus?.isPremium ?? false
    }
    
    // MARK: - Profile Stats
    func loadStats() async {
        await refreshProfile()
        
        // Load saved recipes count
        do {
            let savedRecipeIds = try await repository.getSavedRecipeIds()
            savedRecipesCount = savedRecipeIds.count
        } catch {
            print("Failed to load saved recipes count: \(error)")
        }
    }
    
    // MARK: - Account Management
    func deleteAccount() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // This would call a delete account API
            // For now, we'll just sign out the user
            try await authService.signOut()
        } catch {
            errorMessage = "Failed to delete account: \(error.localizedDescription)"
            showingError = true
        }
        
        isLoading = false
    }
}