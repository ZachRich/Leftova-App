import SwiftUI
import Kingfisher

struct RecipeDetailView: View {
    let recipeId: UUID
    @StateObject private var viewModel = RecipeDetailViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                LoadingView()
            } else if let recipe = viewModel.recipe {
                RecipeContentView(
                    recipe: recipe,
                    ingredients: viewModel.ingredients
                )
            } else if let error = viewModel.errorMessage {
                ErrorView(
                    message: error,
                    retryAction: {
                        Task {
                            await viewModel.loadRecipe(id: recipeId)
                        }
                    }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                SaveButton(
                    isSaved: viewModel.isSaved,
                    action: {
                        Task {
                            await viewModel.toggleSave()
                        }
                    }
                )
                .opacity(viewModel.recipe != nil ? 1 : 0)
            }
        }
        .task {
            await viewModel.loadRecipe(id: recipeId)
        }
    }
}

// MARK: - Sub Views
struct LoadingView: View {
    var body: some View {
        ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 100)
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.red)
            
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            Button("Try Again", action: retryAction)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SaveButton: View {
    let isSaved: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isSaved ? "heart.fill" : "heart")
                .foregroundColor(isSaved ? .red : .gray)
        }
    }
}

struct RecipeContentView: View {
    let recipe: Recipe
    let ingredients: [Ingredient]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            RecipeHeaderImage(imageUrl: recipe.imageUrl)
            
            VStack(alignment: .leading, spacing: 16) {
                RecipeTitleSection(recipe: recipe)
                RecipeMetadataSection(recipe: recipe)
                
                Divider()
                
                if !ingredients.isEmpty {
                    IngredientsSection(ingredients: ingredients)
                    Divider()
                }
                
                // Handle instructions - use the structured format if available
                if let instructions = recipe.instructions, !instructions.isEmpty {
                    InstructionsSection(instructions: instructions)
                } else if !recipe.instructionsArray.isEmpty {
                    // Fallback to string array
                    StringInstructionsSection(instructions: recipe.instructionsArray)
                }
            }
            .padding()
        }
    }
}

// MARK: - Recipe Components
struct RecipeHeaderImage: View {
    let imageUrl: String?
    
    var body: some View {
        Group {
            if let imageUrl = imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 300)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 300)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

struct RecipeTitleSection: View {
    let recipe: Recipe
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(recipe.title)
                .font(.largeTitle)
                .bold()
            
            if let description = recipe.description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct RecipeMetadataSection: View {
    let recipe: Recipe
    
    var body: some View {
        HStack(spacing: 24) {
            if let prepTime = recipe.prepTime {
                MetadataItem(title: "Prep Time", value: "\(prepTime) min")
            }
            
            if let cookTime = recipe.cookTime {
                MetadataItem(title: "Cook Time", value: "\(cookTime) min")
            }
            
            if let servings = recipe.servings {
                MetadataItem(title: "Servings", value: "\(servings)")
            }
        }
    }
}

struct MetadataItem: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.headline)
        }
    }
}

struct IngredientsSection: View {
    let ingredients: [Ingredient]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title2)
                .bold()
            
            ForEach(ingredients) { ingredient in
                IngredientRow(ingredient: ingredient)
            }
        }
    }
}

struct IngredientRow: View {
    let ingredient: Ingredient
    
    var body: some View {
        HStack {
            Text("•")
                .foregroundColor(.secondary)
            
            HStack(spacing: 4) {
                if let amount = ingredient.amount {
                    Text(formatAmount(amount))
                        .bold()
                }
                
                if let unit = ingredient.unit {
                    Text(unit)
                        .foregroundColor(.secondary)
                }
                
                Text(ingredient.name)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", amount)
        } else {
            return String(format: "%.1f", amount)
        }
    }
}

struct InstructionsSection: View {
    let instructions: [Instruction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instructions")
                .font(.title2)
                .bold()
            
            ForEach(instructions.sorted { $0.step < $1.step }, id: \.step) { instruction in
                InstructionRow(
                    index: instruction.step - 1,
                    instruction: instruction.text
                )
            }
        }
    }
}

struct StringInstructionsSection: View {
    let instructions: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Instructions")
                .font(.title2)
                .bold()
            
            ForEach(Array(instructions.enumerated()), id: \.offset) { index, instruction in
                InstructionRow(index: index, instruction: instruction)
            }
        }
    }
}

struct InstructionRow: View {
    let index: Int
    let instruction: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index + 1)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(instruction)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - View Model
@MainActor
class RecipeDetailViewModel: ObservableObject {
    @Published var recipe: Recipe?
    @Published var ingredients: [Ingredient] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSaved = false
    
    private let repository: RecipeRepositoryProtocol
    
    init(repository: RecipeRepositoryProtocol = RecipeRepository()) {
        self.repository = repository
    }
    
    func loadRecipe(id: UUID) async {
        isLoading = true
        errorMessage = nil
        
        do {
            recipe = try await repository.getRecipe(id: id)
            ingredients = try await repository.getIngredientsForRecipe(id: id)
            
            let savedIds = try await repository.getSavedRecipeIds()
            isSaved = savedIds.contains(id)
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
                try await repository.saveRecipe(recipe.id)
                isSaved = true
            }
        } catch {
            print("Failed to toggle save: \(error)")
        }
    }
}
