//
//  RecipeDetailViewModel.swift
//  Leftova
//
//  Created by Claude Code on 8/7/25.
//

import Foundation
import SwiftUI

@MainActor
final class RecipeDetailViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recipe: Recipe?
    @Published var ingredients: [Ingredient] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSaved = false
    @Published var showingPaywall = false
    
    // MARK: - Dependencies
    private let repository: RecipeRepositoryProtocol
    private let usageService: UsageServiceProtocol
    
    // MARK: - Initialization
    init(repository: RecipeRepositoryProtocol = RecipeRepository(), usageService: UsageServiceProtocol = UsageService.shared) {
        self.repository = repository
        self.usageService = usageService
    }
    
    // MARK: - Public Methods
    func loadRecipe(id: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            recipe = try await repository.getRecipe(id: id)
            await loadIngredients(for: id)
            await checkIfSaved(id: id)
        } catch {
            errorMessage = "Failed to load recipe: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func toggleSave() async {
        guard let recipe = recipe else { return }
        
        do {
            if isSaved {
                try await repository.unsaveRecipe(recipe.id)
                isSaved = false
            } else {
                // Use the limit-aware save method
                if let repo = repository as? RecipeRepository {
                    try await repo.saveRecipeWithLimit(recipe.id)
                } else {
                    try await repository.saveRecipe(recipe.id)
                }
                isSaved = true
            }
            // Refresh usage stats to update saved recipe count immediately
            await usageService.refreshUsageStats()
        } catch let error as LimitError {
            // Show paywall if limit reached
            errorMessage = error.errorDescription
            showingPaywall = true
        } catch {
            errorMessage = "Failed to save recipe: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Private Methods
    private func loadIngredients(for recipeId: UUID) async {
        do {
            // This would be implemented if you have ingredient fetching
            ingredients = []
        } catch {
            print("Failed to load ingredients: \(error)")
        }
    }
    
    private func checkIfSaved(id: UUID) async {
        do {
            let savedIds = try await repository.getSavedRecipeIds()
            isSaved = savedIds.contains(id)
        } catch {
            print("Failed to check if recipe is saved: \(error)")
        }
    }
}