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
                                if let recipe = viewModel.savedRecipes.first(where: { $0.id == recipeId }) {
                                    await viewModel.unsaveRecipe(recipe)
                                }
                            }
                        }
                    )
                }
            }
            .navigationTitle("Saved Recipes")
            .task {
                await viewModel.loadSavedRecipes()
            }
            .refreshable {
                await viewModel.refreshSavedRecipes()
            }
            .onAppear {
                Task {
                    await viewModel.loadSavedRecipes()
                }
            }
        }
    }
}

// SavedRecipesViewModel is now in its own file