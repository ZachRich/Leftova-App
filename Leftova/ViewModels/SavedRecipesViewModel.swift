//
//  SavedRecipesViewModel.swift
//  Leftova
//
//  Created by Claude Code on 8/7/25.
//

import Foundation
import SwiftUI

@MainActor
class SavedRecipesViewModel: ObservableObject {
    @Published var savedRecipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let repository: RecipeRepositoryProtocol
    private let usageService: UsageServiceProtocol
    
    init(repository: RecipeRepositoryProtocol = RecipeRepository(), usageService: UsageServiceProtocol = UsageService.shared) {
        self.repository = repository
        self.usageService = usageService
    }
    
    func loadSavedRecipes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            print("Loading saved recipes...")
            savedRecipes = try await repository.getSavedRecipes()
            print("Loaded \(savedRecipes.count) saved recipes")
        } catch {
            print("Error loading saved recipes: \(error)")
            errorMessage = "Failed to load saved recipes: \(error.localizedDescription)"
            savedRecipes = []
        }
        
        isLoading = false
    }
    
    func unsaveRecipe(_ recipe: Recipe) async {
        do {
            try await repository.unsaveRecipe(recipe.id)
            savedRecipes.removeAll { $0.id == recipe.id }
            // Refresh usage stats to update saved recipe count immediately
            await usageService.refreshUsageStats()
        } catch {
            errorMessage = "Failed to remove recipe: \(error.localizedDescription)"
        }
    }
    
    func refreshSavedRecipes() async {
        await loadSavedRecipes()
    }
}