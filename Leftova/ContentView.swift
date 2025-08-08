import SwiftUI

struct ContentView: View {
    @StateObject private var usageService = UsageService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    var body: some View {
        TabView {
            RecipeSearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .badge(badgeForSearch)
            
            SavedRecipesView()
                .tabItem {
                    Label("Saved", systemImage: "heart.fill")
                }
                .badge(badgeForSaved)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .task {
            // Initialize on app launch
            await subscriptionService.refreshSubscriptionStatus()
            await usageService.refreshUsageStats()
        }
    }
    
    private var badgeForSearch: String? {
        guard !usageService.isPremium else { return nil }
        if usageService.searchesRemaining <= Config.FreeTier.WarningThresholds.searchesRemaining {
            return "\(usageService.searchesRemaining)"
        }
        return nil
    }
    
    private var badgeForSaved: String? {
        guard !usageService.isPremium else { return nil }
        if usageService.recipeSlotsRemaining <= Config.FreeTier.WarningThresholds.savedRecipesRemaining {
            return "\(usageService.recipeSlotsRemaining)"
        }
        return nil
    }
}
