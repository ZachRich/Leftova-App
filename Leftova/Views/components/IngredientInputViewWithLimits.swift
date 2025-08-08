// File: Views/Components/IngredientInputViewWithLimits.swift
// Fixed version without shared singleton ambiguity

import SwiftUI

struct IngredientInputViewWithLimits: View {
    @Binding var ingredients: [String]
    var showBanner: Bool
    @State private var currentIngredient = ""
    @State private var showUpgradePrompt = false
    @StateObject private var usageService = UsageService.shared
    @FocusState private var isInputFocused: Bool
    
    // Initializers for different use cases
    init(ingredients: Binding<[String]>, showBanner: Bool = true) {
        self._ingredients = ingredients
        self.showBanner = showBanner
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with limit info - only show if showBanner is true
            if showBanner {
                headerView
            }
            
            // Input field
            inputFieldView
            
            // Selected ingredients chips
            if !ingredients.isEmpty {
                selectedIngredientsView
            }
            
            // Upgrade prompt - only show if showBanner is true
            if showBanner && shouldShowUpgradeHint {
                upgradeHintView
            }
        }
        .padding()
        .sheet(isPresented: $showUpgradePrompt) {
            PaywallView()
        }
        .task {
            await usageService.refreshUsageStats()
        }
    }
    
    // MARK: - Computed Properties
    
    private var shouldDisableInput: Bool {
        !usageService.isPremium && !Config.FreeTier.canUseAdvancedSearch && ingredients.count >= 1
    }
    
    private var shouldShowUpgradeHint: Bool {
        !usageService.isPremium && !Config.FreeTier.canUseAdvancedSearch && ingredients.count >= 1
    }
    
    private var remainingIngredients: Int {
        if usageService.isPremium { 
            return Config.FreeTier.UI.unlimitedValue
        } else if Config.FreeTier.canUseAdvancedSearch {
            return Config.FreeTier.UI.unlimitedValue  // No limit if advanced search is enabled for free users
        } else {
            return max(0, 1 - ingredients.count)
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Text("What's in your kitchen?")
                .font(.headline)
            
            Spacer()
            
            if !usageService.isPremium {
                Label(
                    Config.FreeTier.canUseAdvancedSearch 
                        ? "Multi-ingredient (Free)" 
                        : (ingredients.isEmpty ? "1 ingredient (Free)" : "Limit reached"),
                    systemImage: (Config.FreeTier.canUseAdvancedSearch || ingredients.isEmpty) ? "info.circle" : "exclamationmark.circle"
                )
                .font(.caption)
                .foregroundColor((Config.FreeTier.canUseAdvancedSearch || ingredients.isEmpty) ? .blue : .orange)
            } else {
                Label("Unlimited", systemImage: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.yellow)
            }
        }
    }
    
    private var inputFieldView: some View {
        HStack {
            TextField(
                shouldDisableInput ? "Upgrade for multiple ingredients" : "Add ingredient",
                text: $currentIngredient
            )
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .focused($isInputFocused)
            .disabled(shouldDisableInput)
            .onSubmit {
                addIngredient()
            }
            
            Button(action: addIngredient) {
                Label("Add", systemImage: "plus.circle.fill")
                    .labelStyle(.iconOnly)
                    .font(.title2)
            }
            .disabled(currentIngredient.isEmpty || shouldDisableInput)
            .foregroundColor(shouldDisableInput ? .gray : .blue)
        }
    }
    
    private var selectedIngredientsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ingredients, id: \.self) { ingredient in
                    IngredientChip(
                        ingredient: ingredient,
                        onDelete: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                ingredients.removeAll { $0 == ingredient }
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var upgradeHintView: some View {
        Button(action: { showUpgradePrompt = true }) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Want to add more ingredients?")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Text("Upgrade for multi-ingredient search")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                LinearGradient(
                    colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
    private func addIngredient() {
        let trimmed = currentIngredient.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else { return }
        
        // Check for duplicates
        guard !ingredients.contains(where: { $0.lowercased() == trimmed.lowercased() }) else {
            currentIngredient = ""
            return
        }
        
        // Check limits for free users
        if !usageService.isPremium && !Config.FreeTier.canUseAdvancedSearch && ingredients.count >= 1 {
            showUpgradePrompt = true
            return
        }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            ingredients.append(trimmed)
            currentIngredient = ""
        }
    }
}
