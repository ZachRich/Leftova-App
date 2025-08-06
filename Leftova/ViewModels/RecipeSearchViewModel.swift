//
//  RecipeSearchViewModel.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//

import Foundation
import SwiftUI

@MainActor
class RecipeSearchViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var selectedIngredients: [String] = []
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var savedRecipeIds: Set<UUID> = []
    
    private let repository: RecipeRepositoryProtocol
    
    init(repository: RecipeRepositoryProtocol = RecipeRepository()) {
        self.repository = repository
    }
    
    func searchRecipes() async {
        guard !selectedIngredients.isEmpty else {
            recipes = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            recipes = try await repository.searchByIngredients(selectedIngredients)
            await loadSavedRecipeIds()
        } catch {
            errorMessage = "Failed to search recipes: \(error.localizedDescription)"
            recipes = []
        }
        
        isLoading = false
    }
    
    func searchByText() async {
        guard !searchText.isEmpty else {
            recipes = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            recipes = try await repository.searchByText(searchText)
            await loadSavedRecipeIds()
        } catch {
            errorMessage = "Failed to search recipes: \(error.localizedDescription)"
            recipes = []
        }
        
        isLoading = false
    }
    
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
                try await repository.unsaveRecipe(recipeId)
                savedRecipeIds.remove(recipeId)
            } else {
                try await repository.saveRecipe(recipeId)
                savedRecipeIds.insert(recipeId)
            }
        } catch {
            print("Failed to toggle save recipe: \(error)")
        }
    }
}
