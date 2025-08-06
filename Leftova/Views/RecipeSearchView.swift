//
//  RecipeSearchView.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//


import SwiftUI

struct RecipeSearchView: View {
    @StateObject private var viewModel = RecipeSearchViewModel()
    @State private var searchMode: SearchMode = .ingredients
    
    enum SearchMode {
        case ingredients, text
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Mode Picker
                Picker("Search Mode", selection: $searchMode) {
                    Text("By Ingredients").tag(SearchMode.ingredients)
                    Text("By Name").tag(SearchMode.text)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Search Input
                if searchMode == .ingredients {
                    IngredientInputView(ingredients: $viewModel.selectedIngredients)
                        .onChange(of: viewModel.selectedIngredients) { _ in
                            Task {
                                await viewModel.searchRecipes()
                            }
                        }
                } else {
                    SearchBar(text: $viewModel.searchText)
                        .padding(.horizontal)
                        .onSubmit {
                            Task {
                                await viewModel.searchByText()
                            }
                        }
                }
                
                // Results
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                    Spacer()
                } else {
                    RecipeListView(
                        recipes: viewModel.recipes,
                        savedRecipeIds: viewModel.savedRecipeIds,
                        onToggleSave: { recipeId in
                            Task {
                                await viewModel.toggleSaveRecipe(recipeId)
                            }
                        }
                    )
                }
            }
            .navigationTitle("Recipe Search")
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search recipes...", text: $text)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
    }
}