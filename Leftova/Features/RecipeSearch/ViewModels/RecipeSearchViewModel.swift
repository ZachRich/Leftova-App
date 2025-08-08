//
//  RecipeSearchViewModel.swift
//  Leftova
//
//  Modern recipe search view model with clean architecture
//

import Foundation
import SwiftUI

@MainActor
final class RecipeSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var selectedIngredients: [String] = []
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var savedRecipeIds: Set<UUID> = []
    @Published var showingPaywall = false
    
    // MARK: - Dependencies
    private let repository: RecipeRepositoryProtocol
    private let usageService: UsageServiceProtocol
    
    // MARK: - Initialization
    init(
        repository: RecipeRepositoryProtocol = RecipeRepository(),
        usageService: UsageServiceProtocol = UsageService.shared
    ) {
        self.repository = repository
        self.usageService = usageService
    }
    
    // MARK: - Search Methods
    func searchRecipes() async {
        guard !selectedIngredients.isEmpty else {
            recipes = []
            return
        }
        
        await performSearch {
            try await repository.searchByIngredientsWithLimit(selectedIngredients)
        }
    }
    
    func searchByText() async {
        guard !searchText.isEmpty else {
            recipes = []
            return
        }
        
        await performSearch {
            try await repository.searchByTextWithLimit(searchText)
        }
    }
    
    // MARK: - Recipe Management
    func loadSavedRecipeIds() async {
        do {
            let ids = try await repository.getSavedRecipeIds()
            savedRecipeIds = Set(ids)
        } catch {
            print("Failed to load saved recipe IDs: \(error)")
        }
    }
    
    func toggleSaveRecipe(_ recipeId: UUID) async {
        do {
            if savedRecipeIds.contains(recipeId) {
                print("Unsaving recipe: \(recipeId)")
                try await repository.unsaveRecipe(recipeId)
                savedRecipeIds.remove(recipeId)
                print("Recipe unsaved successfully")
            } else {
                print("Saving recipe: \(recipeId)")
                // Use the limit-aware save method
                if let repo = repository as? RecipeRepository {
                    try await repo.saveRecipeWithLimit(recipeId)
                } else {
                    try await repository.saveRecipe(recipeId)
                }
                savedRecipeIds.insert(recipeId)
                print("Recipe saved successfully")
            }
            // Refresh usage stats to update saved recipe count immediately
            await usageService.refreshUsageStats()
        } catch let error as LimitError {
            handleLimitError(error)
        } catch {
            print("Error toggling save: \(error)")
            errorMessage = "Failed to save recipe: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Ingredient Management
    func addIngredient(_ ingredient: String) {
        let trimmed = ingredient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Check for duplicates
        guard !selectedIngredients.contains(where: { $0.lowercased() == trimmed.lowercased() }) else {
            return
        }
        
        // Check limits for multi-ingredient search (free users can only search one ingredient at a time)
        if !usageService.isPremium && !selectedIngredients.isEmpty {
            errorMessage = "Multi-ingredient search is a premium feature. Upgrade to search with multiple ingredients!"
            showingPaywall = true
            return
        }
        
        selectedIngredients.append(trimmed)
    }
    
    func removeIngredient(_ ingredient: String) {
        selectedIngredients.removeAll { $0 == ingredient }
    }
    
    func clearIngredients() {
        selectedIngredients.removeAll()
        recipes = []
        errorMessage = nil
    }
    
    // MARK: - State Management
    func clearSearch() {
        searchText = ""
        recipes = []
        errorMessage = nil
    }
    
    func refreshData() async {
        await loadSavedRecipeIds()
        
        // Re-run last search if we have criteria
        if !selectedIngredients.isEmpty {
            await searchRecipes()
        } else if !searchText.isEmpty {
            await searchByText()
        }
    }
    
    // MARK: - Private Methods
    private func performSearch(_ searchOperation: () async throws -> [Recipe]) async {
        isLoading = true
        errorMessage = nil
        
        do {
            recipes = try await searchOperation()
            await loadSavedRecipeIds()
            // Refresh usage stats to update UI immediately
            await usageService.refreshUsageStats()
        } catch let error as LimitError {
            handleLimitError(error)
        } catch {
            errorMessage = "Failed to search recipes: \(error.localizedDescription)"
            recipes = []
        }
        
        isLoading = false
    }
    
    private func handleLimitError(_ error: LimitError) {
        errorMessage = error.errorDescription
        showingPaywall = true
        recipes = []
    }
}