// File: Views/PaywallView.swift
// Simplified paywall without StoreManager redefinition

import SwiftUI
import StoreKit

struct PaywallView: View {
    // Use the shared instance to avoid ambiguity
    @StateObject private var storeManager = StoreManager.shared
    @State private var isProcessingPurchase = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedProduct: Product?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Features list
                    featuresSection
                    
                    // Subscription options
                    if storeManager.products.isEmpty && !storeManager.isLoading {
                        loadingOrEmptyState
                    } else {
                        subscriptionOptionsSection
                    }
                    
                    // Trial info
                    trialInfoSection
                    
                    // Terms and restore
                    bottomSection
                }
                .padding(.bottom, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await storeManager.loadProducts()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
                .shadow(radius: 10)
            
            Text("Unlock Premium")
                .font(.largeTitle.bold())
            
            Text("Get unlimited access to all features")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top, 20)
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium Features")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                FeatureRowItem(
                    icon: "infinity",
                    text: "Unlimited recipe searches (free: \(Config.FreeTier.dailySearchLimit)/day)",
                    isIncluded: true
                )
                
                FeatureRowItem(
                    icon: "heart.fill",
                    text: "Save unlimited recipes (free: \(Config.FreeTier.savedRecipesLimit) total)",
                    isIncluded: true
                )
                
                // Only show multi-ingredient search as a premium feature if it's not available to free users
                if !Config.FreeTier.canUseAdvancedSearch {
                    FeatureRowItem(
                        icon: "sparkles",
                        text: "Multi-ingredient search",
                        isIncluded: true
                    )
                }
                
                FeatureRowItem(
                    icon: "chart.bar.fill",
                    text: "Nutritional analysis",
                    isIncluded: true
                )
                
                FeatureRowItem(
                    icon: "calendar",
                    text: "Advanced meal planning",
                    isIncluded: true
                )
                
                FeatureRowItem(
                    icon: "person.2.fill",
                    text: "Family sharing (up to 5)",
                    isIncluded: true
                )
                
                FeatureRowItem(
                    icon: "icloud.fill",
                    text: "Cloud sync across devices",
                    isIncluded: true
                )
                
                FeatureRowItem(
                    icon: "nosign",
                    text: "Ad-free experience",
                    isIncluded: true
                )
            }
            .padding(.horizontal)
        }
    }
    
    private var loadingOrEmptyState: some View {
        VStack(spacing: 16) {
            if storeManager.isLoading {
                ProgressView("Loading products...")
                    .padding()
            } else {
                Text("Products unavailable")
                    .foregroundColor(.secondary)
                
                Button("Retry") {
                    Task {
                        await storeManager.loadProducts()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(minHeight: 100)
    }
    
    // Simplified subscription options to avoid complex expression
    private var subscriptionOptionsSection: some View {
        VStack(spacing: 12) {
            ForEach(sortedProducts, id: \.id) { product in
                productCard(for: product)
            }
        }
        .padding(.horizontal)
    }
    
    // Helper computed property to simplify the expression
    private var sortedProducts: [Product] {
        storeManager.products.sorted { $0.price < $1.price }
    }
    
    // Helper function to create product card
    private func productCard(for product: Product) -> some View {
        let isSelected = selectedProduct?.id == product.id
        let isPopular = product.id.contains("annual")
        let isProcessing = isProcessingPurchase && isSelected
        
        return SubscriptionOptionCard(
            product: product,
            isSelected: isSelected,
            isPopular: isPopular,
            isProcessing: isProcessing,
            onSelect: {
                selectedProduct = product
            },
            onPurchase: {
                await purchaseProduct(product)
            }
        )
    }
    
    private var trialInfoSection: some View {
        HStack {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(.green)
            Text("Start with 14-day free trial")
                .font(.callout)
                .fontWeight(.medium)
        }
        .padding(.horizontal)
    }
    
    private var bottomSection: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") {
                Task {
                    await restorePurchases()
                }
            }
            .font(.callout)
            .disabled(isProcessingPurchase)
            
            Text("Cancel anytime in Settings. Terms apply.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical)
    }
    
    // MARK: - Actions
    
    private func purchaseProduct(_ product: Product) async {
        isProcessingPurchase = true
        defer { isProcessingPurchase = false }
        
        do {
            let result = try await storeManager.purchase(product)
            if result {
                dismiss()
            }
        } catch StoreError.userCancelled {
            // User cancelled, no error needed
            return
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
    
    private func restorePurchases() async {
        isProcessingPurchase = true
        defer { isProcessingPurchase = false }
        
        do {
            try await storeManager.restorePurchases()
            
            if storeManager.hasActiveSubscription {
                dismiss()
            } else {
                errorMessage = "No active subscription found"
                showError = true
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

// MARK: - Supporting Views

struct FeatureRowItem: View {
    let icon: String
    let text: String
    let isIncluded: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isIncluded ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(isIncluded ? .green : .red)
                .font(.title3)
            
            Text(text)
                .font(.callout)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

struct SubscriptionOptionCard: View {
    let product: Product
    let isSelected: Bool
    let isPopular: Bool
    let isProcessing: Bool
    let onSelect: () -> Void
    let onPurchase: () async -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            if isPopular {
                popularBadge
            }
            
            VStack(spacing: 16) {
                productInfoRow
                purchaseButton
            }
            .padding()
        }
        .background(backgroundColorForCard)
        .overlay(borderForCard)
        .cornerRadius(12)
        .onTapGesture {
            if !isProcessing {
                onSelect()
            }
        }
    }
    
    private var popularBadge: some View {
        Text("MOST POPULAR • SAVE 33%")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.green)
            .cornerRadius(12)
    }
    
    private var productInfoRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.displayName)
                    .font(.headline)
                
                Text(product.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(product.displayPrice)
                    .font(.title3)
                    .fontWeight(.bold)
                
                if let period = periodText {
                    Text(period)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var purchaseButton: some View {
        Button(action: {
            Task { await onPurchase() }
        }) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Subscribe")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .disabled(isProcessing)
    }
    
    private var backgroundColorForCard: Color {
        isPopular ? Color.blue.opacity(0.1) : Color(.systemGray6)
    }
    
    private var borderForCard: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(isPopular ? Color.blue : Color.clear, lineWidth: 2)
    }
    
    private var periodText: String? {
        guard let subscription = product.subscription else { return nil }
        
        switch subscription.subscriptionPeriod.unit {
        case .month:
            return "per month"
        case .year:
            return "per year"
        case .week:
            return "per week"
        case .day:
            return "per day"
        @unknown default:
            return nil
        }
    }
}

// MARK: - Preview
#if DEBUG
struct PaywallView_Previews: PreviewProvider {
    static var previews: some View {
        PaywallView()
    }
}
#endif
