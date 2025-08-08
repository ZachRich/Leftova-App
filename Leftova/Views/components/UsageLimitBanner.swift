//
//  UsageLimitBanner.swift
//  Leftova
//
//  Created by Zach Rich on 8/7/25.
//


// File: Views/Components/UsageLimitBanner.swift
// Banner component to display current usage limits

import SwiftUI

struct UsageLimitBanner: View {
    @StateObject private var usageService = UsageService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    @State private var showingPaywall = false
    @State private var isExpanded = false
    
    var body: some View {
        if !usageService.isPremium {
            if usageService.currentTier == "free" {
                freeTierBanner
            } else if subscriptionService.subscriptionStatus?.isTrialActive == true {
                trialBanner
            }
        }
    }
    
    // MARK: - Free Tier Banner
    
    private var freeTierBanner: some View {
        VStack(spacing: 0) {
            // Main banner
            HStack {
                // Icon and title
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                    
                    Text("Free Plan")
                        .font(.headline)
                }
                
                Spacer()
                
                // Expand/collapse button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            // Expandable content
            if isExpanded {
                VStack(spacing: 12) {
                    Divider()
                    
                    // Usage stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 12) {
                        UsageStatItem(
                            icon: "magnifyingglass",
                            title: "Searches Today",
                            current: getCurrentSearches(),
                            limit: getSearchesLimit(),
                            color: usageService.getLimitColor(for: .search)
                        )
                        
                        UsageStatItem(
                            icon: "heart.fill",
                            title: "Saved Recipes",
                            current: getCurrentSavedRecipes(),
                            limit: getSavedRecipesLimit(),
                            color: usageService.getLimitColor(for: .saveRecipe)
                        )
                    }
                    
                    // Upgrade button
                    Button(action: { showingPaywall = true }) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("Upgrade to Premium")
                                .fontWeight(.semibold)
                            Image(systemName: "arrow.right")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            } else {
                // Collapsed view - show quick stats
                HStack(spacing: 20) {
                    QuickStat(
                        icon: "magnifyingglass",
                        text: "\(usageService.searchesRemaining)/\(getSearchesLimit())",
                        color: usageService.getLimitColor(for: .search)
                    )
                    
                    QuickStat(
                        icon: "heart",
                        text: "\(usageService.recipeSlotsRemaining)/\(getSavedRecipesLimit())",
                        color: usageService.getLimitColor(for: .saveRecipe)
                    )
                    
                    Spacer()
                    
                    Button("Upgrade") {
                        showingPaywall = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .font(.caption)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 4)
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Trial Banner
    
    private var trialBanner: some View {
        HStack {
            Image(systemName: "crown.fill")
                .foregroundColor(.yellow)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Premium Trial Active")
                    .font(.caption)
                    .fontWeight(.semibold)
                
                if let daysLeft = subscriptionService.subscriptionStatus?.daysLeftInTrial {
                    Text("\(daysLeft) days remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("Unlimited Access")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.1), Color.orange.opacity(0.1)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    private func getColorForUsage(current: Int, limit: Int) -> Color {
        let percentage = Double(current) / Double(limit)
        
        if percentage >= 1.0 {
            return .red
        } else if percentage >= 0.8 {
            return .orange
        } else if percentage >= 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
    
    // MARK: - Helper Methods for Real-time Data
    
    private func getCurrentSearches() -> Int {
        let limit = getSearchesLimit()
        return max(0, limit - usageService.searchesRemaining)
    }
    
    private func getSearchesLimit() -> Int {
        // Use server data if available, otherwise use config default
        return usageService.usageStats?.searchesLimit ?? Config.FreeTier.dailySearchLimit
    }
    
    private func getCurrentSavedRecipes() -> Int {
        let limit = getSavedRecipesLimit()
        return max(0, limit - usageService.recipeSlotsRemaining)
    }
    
    private func getSavedRecipesLimit() -> Int {
        // Use server data if available, otherwise use config default
        return usageService.usageStats?.savedRecipesLimit ?? Config.FreeTier.savedRecipesLimit
    }
}

// MARK: - Supporting Views

struct UsageStatItem: View {
    let icon: String
    let title: String
    let current: Int
    let limit: Int
    let color: Color
    
    private var percentage: Double {
        guard limit > 0 else { return 0 }
        return Double(current) / Double(limit)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(
                            width: geometry.size.width * min(percentage, 1.0),
                            height: 4
                        )
                }
            }
            .frame(height: 4)
            
            Text("\(current) / \(limit)")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct QuickStat: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview
#if DEBUG
struct UsageLimitBanner_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            UsageLimitBanner()
            
            Spacer()
        }
    }
}
#endif