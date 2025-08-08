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
                // Add the usage limit banner at the top
                UsageLimitBanner()
                
                // Search Mode Picker
                Picker("Search Mode", selection: $searchMode) {
                    Text("By Ingredients").tag(SearchMode.ingredients)
                    Text("By Name").tag(SearchMode.text)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Search Input - Use simplified components without individual banners
                if searchMode == .ingredients {
                    IngredientInputViewWithLimits(ingredients: $viewModel.selectedIngredients, showBanner: false)
                        .onChange(of: viewModel.selectedIngredients) { _ in
                            Task {
                                await viewModel.searchRecipes()
                            }
                        }
                } else {
                    SearchBarWithLimits(showBanner: false) { query in
                        viewModel.searchText = query
                        Task {
                            await viewModel.searchByText()
                        }
                    }
                }
                
                // Results (keep your existing RecipeListView)
                if viewModel.isLoading {
                    Spacer()
                    ProgressView("Searching...")
                    Spacer()
                } else if let error = viewModel.errorMessage {
                    Spacer()
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
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
