//
//  SavedRecipesView.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//


import SwiftUI

struct SavedRecipesView: View {
    @StateObject private var viewModel = SavedRecipesViewModel()
    
    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading saved recipes...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.savedRecipes.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No saved recipes yet")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Recipes you save will appear here")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    RecipeListView(
                        recipes: viewModel.savedRecipes,
                        savedRecipeIds: Set(viewModel.savedRecipes.map { $0.id }),
                        onToggleSave: { recipeId in
                            Task {
                                await viewModel.unsaveRecipe(recipeId)
                            }
                        }
                    )
                }
            }
            .navigationTitle("Saved Recipes")
            .task {
                await viewModel.loadSavedRecipes()
            }
        }
    }
}

@MainActor
class SavedRecipesViewModel: ObservableObject {
    @Published var savedRecipes: [Recipe] = []
    @Published var isLoading = false
    
    private let repository: RecipeRepositoryProtocol
    
    init(repository: RecipeRepositoryProtocol = RecipeRepository()) {
        self.repository = repository
    }
    
    func loadSavedRecipes() async {
        isLoading = true
        
        do {
            let savedIds = try await repository.getSavedRecipeIds()
            var recipes: [Recipe] = []
            
            for id in savedIds {
                if let recipe = try? await repository.getRecipe(id: id) {
                    recipes.append(recipe)
                }
            }
            
            savedRecipes = recipes
        } catch {
            print("Failed to load saved recipes: \(error)")
        }
        
        isLoading = false
    }
    
    func unsaveRecipe(_ recipeId: UUID) async {
        do {
            try await repository.unsaveRecipe(recipeId)
            savedRecipes.removeAll { $0.id == recipeId }
        } catch {
            print("Failed to unsave recipe: \(error)")
        }
    }
}