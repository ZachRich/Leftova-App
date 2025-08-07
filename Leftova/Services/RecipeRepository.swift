import Foundation
import Supabase

// MARK: - Repository Protocol
protocol RecipeRepositoryProtocol {
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe]
    func searchByIngredients(_ ingredients: [String], page: Int, pageSize: Int) async throws -> [Recipe]
    func searchByText(_ query: String) async throws -> [Recipe]
    func searchByText(_ query: String, page: Int, pageSize: Int) async throws -> [Recipe]
    func getRecipe(id: UUID) async throws -> Recipe
    func getIngredientsForRecipe(id: UUID) async throws -> [Ingredient]
    func getAllRecipes(limit: Int) async throws -> [Recipe]
    func saveRecipe(_ recipeId: UUID) async throws
    func unsaveRecipe(_ recipeId: UUID) async throws
    func getSavedRecipeIds() async throws -> [UUID]
    func getSavedRecipes() async throws -> [Recipe]
}

// MARK: - Saved Recipe Model
struct SavedRecipe: Codable {
    let id: UUID?
    let userId: String
    let recipeId: UUID
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case recipeId = "recipe_id"
        case createdAt = "created_at"
    }
}

// MARK: - Recipe Repository Implementation
class RecipeRepository: RecipeRepositoryProtocol {
    private let client = SupabaseService.shared.client
    private let authService = AuthenticationService.shared
    
    // Configure decoder for proper date handling
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // MARK: - Search Methods
    
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe] {
        return try await searchByIngredients(ingredients, page: 0, pageSize: 20)
    }
    
    func searchByIngredients(_ ingredients: [String], page: Int, pageSize: Int) async throws -> [Recipe] {
        guard !ingredients.isEmpty else { return [] }
        
        print("🔍 Searching for ingredients: \(ingredients)")
        
        // Normalize ingredients for better matching
        let normalizedIngredients = ingredients.map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
        
        let response = try await client
            .rpc("search_by_ingredients", params: [
                "ingredient_list": normalizedIngredients
            ])
            .execute()
        
        let recipes = try decoder.decode([Recipe].self, from: response.data)
        
        print("📊 Found \(recipes.count) recipes")
        
        // Handle pagination by skipping and limiting results
        let startIndex = page * pageSize
        let endIndex = min(startIndex + pageSize, recipes.count)
        
        guard startIndex < recipes.count else { return [] }
        
        return Array(recipes[startIndex..<endIndex])
    }
    
    func searchByText(_ query: String) async throws -> [Recipe] {
        return try await searchByText(query, page: 0, pageSize: 20)
    }
    
    func searchByText(_ query: String, page: Int, pageSize: Int) async throws -> [Recipe] {
        guard !query.isEmpty else { return [] }
        
        print("🔍 Searching for text: \(query)")
        
        let offset = page * pageSize
        
        let response = try await client
            .from("recipes")
            .select("*")
            .textSearch("search_vector", query: query)
            .range(from: offset, to: offset + pageSize - 1)
            .execute()
        
        return try decoder.decode([Recipe].self, from: response.data)
    }
    
    // MARK: - Recipe Details
    
    func getRecipe(id: UUID) async throws -> Recipe {
        print("📖 Fetching recipe with ID: \(id)")
        
        let response = try await client
            .from("recipes")
            .select("*")
            .eq("id", value: id.uuidString)
            .single()
            .execute()
        
        do {
            let recipe = try decoder.decode(Recipe.self, from: response.data)
            print("✅ Successfully decoded recipe: \(recipe.title)")
            return recipe
        } catch {
            print("❌ Failed to decode recipe")
            print("Raw data: \(String(data: response.data, encoding: .utf8) ?? "nil")")
            throw error
        }
    }
    
    func getIngredientsForRecipe(id: UUID) async throws -> [Ingredient] {
        print("🥘 Fetching ingredients for recipe: \(id)")
        
        let response = try await client
            .from("ingredients")
            .select("*")
            .eq("recipe_id", value: id.uuidString)
            .order("name", ascending: true)
            .execute()
        
        return try decoder.decode([Ingredient].self, from: response.data)
    }
    
    func getAllRecipes(limit: Int = 20) async throws -> [Recipe] {
        let response = try await client
            .from("recipes")
            .select("*")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
        
        return try decoder.decode([Recipe].self, from: response.data)
    }
    
    // MARK: - Save/Favorite Methods (Database-backed)
    
    func saveRecipe(_ recipeId: UUID) async throws {
        guard let userId = authService.currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        
        print("💾 Saving recipe: \(recipeId) for user: \(userId)")
        
        // Check if already saved
        let existingResponse = try await client
            .from("saved_recipes")
            .select("id")
            .eq("user_id", value: userId)
            .eq("recipe_id", value: recipeId.uuidString)
            .execute()
        
        let existingSaved = try decoder.decode([SavedRecipe].self, from: existingResponse.data)
        
        if existingSaved.isEmpty {
            // Save the recipe
            let savedRecipe = SavedRecipe(
                id: nil,
                userId: userId,
                recipeId: recipeId,
                createdAt: nil
            )
            
            _ = try await client
                .from("saved_recipes")
                .insert(savedRecipe)
                .execute()
            
            print("✅ Recipe saved successfully")
        } else {
            print("ℹ️ Recipe already saved")
        }
    }
    
    func unsaveRecipe(_ recipeId: UUID) async throws {
        guard let userId = authService.currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        
        print("🗑️ Unsaving recipe: \(recipeId) for user: \(userId)")
        
        _ = try await client
            .from("saved_recipes")
            .delete()
            .eq("user_id", value: userId)
            .eq("recipe_id", value: recipeId.uuidString)
            .execute()
        
        print("✅ Recipe unsaved successfully")
    }
    
    func getSavedRecipeIds() async throws -> [UUID] {
        guard let userId = authService.currentUserId else {
            // If not authenticated, return empty array or fall back to UserDefaults
            let savedIds = UserDefaults.standard.stringArray(forKey: "savedRecipeIds") ?? []
            return savedIds.compactMap { UUID(uuidString: $0) }
        }
        
        print("📋 Fetching saved recipe IDs for user: \(userId)")
        
        let response = try await client
            .from("saved_recipes")
            .select("recipe_id")
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
        
        let savedRecipes = try decoder.decode([SavedRecipe].self, from: response.data)
        return savedRecipes.map { $0.recipeId }
    }
    
    func getSavedRecipes() async throws -> [Recipe] {
        let savedIds = try await getSavedRecipeIds()
        guard !savedIds.isEmpty else { return [] }
        
        var recipes: [Recipe] = []
        
        // Fetch recipes in batches to avoid query limits
        let batchSize = 10
        for i in stride(from: 0, to: savedIds.count, by: batchSize) {
            let endIndex = min(i + batchSize, savedIds.count)
            let batch = Array(savedIds[i..<endIndex])
            
            let response = try await client
                .from("recipes")
                .select("*")
                .in("id", values: batch.map { $0.uuidString })
                .execute()
            
            let batchRecipes = try decoder.decode([Recipe].self, from: response.data)
            recipes.append(contentsOf: batchRecipes)
        }
        
        // Sort recipes by the order they were saved
        let sortedRecipes = recipes.sorted { recipe1, recipe2 in
            if let index1 = savedIds.firstIndex(of: recipe1.id),
               let index2 = savedIds.firstIndex(of: recipe2.id) {
                return index1 < index2
            }
            return false
        }
        
        return sortedRecipes
    }
    
    // MARK: - Helper Methods
    
    func getRecipeWithIngredients(id: UUID) async throws -> (Recipe, [Ingredient]) {
        async let recipe = getRecipe(id: id)
        async let ingredients = getIngredientsForRecipe(id: id)
        
        return try await (recipe, ingredients)
    }
    
    func searchRecipesWithFilters(
        ingredients: [String]? = nil,
        dietaryRestrictions: [String]? = nil,
        maxCookTime: Int? = nil,
        servings: Int? = nil
    ) async throws -> [Recipe] {
        var query = client.from("recipes").select("*")
        
        // Apply filters
        if let maxCookTime = maxCookTime {
            query = query.lte("cook_time", value: maxCookTime)
        }
        
        if let servings = servings {
            query = query.eq("servings", value: servings)
        }
        
        let response = try await query.execute()
        var recipes = try decoder.decode([Recipe].self, from: response.data)
        
        // If ingredients are specified, filter by them
        if let ingredients = ingredients, !ingredients.isEmpty {
            let ingredientRecipes = try await searchByIngredients(ingredients)
            let ingredientRecipeIds = Set(ingredientRecipes.map { $0.id })
            recipes = recipes.filter { ingredientRecipeIds.contains($0.id) }
        }
        
        return recipes
    }
    
    // MARK: - Batch Operations
    
    func getMultipleRecipes(ids: [UUID]) async throws -> [Recipe] {
        guard !ids.isEmpty else { return [] }
        
        let response = try await client
            .from("recipes")
            .select("*")
            .in("id", values: ids.map { $0.uuidString })
            .execute()
        
        return try decoder.decode([Recipe].self, from: response.data)
    }
    
    func deleteRecipe(_ id: UUID) async throws {
        // Only if you have admin privileges
        _ = try await client
            .from("recipes")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        
        print("🗑️ Deleted recipe: \(id)")
    }
    
    // MARK: - Migration Helper
    
    func migrateSavedRecipesFromLocalStorage() async throws {
        guard let userId = authService.currentUserId else {
            throw RepositoryError.notAuthenticated
        }
        
        let localSavedIds = UserDefaults.standard.stringArray(forKey: "savedRecipeIds") ?? []
        guard !localSavedIds.isEmpty else { return }
        
        print("🔄 Migrating \(localSavedIds.count) saved recipes from local storage")
        
        for idString in localSavedIds {
            if let recipeId = UUID(uuidString: idString) {
                do {
                    try await saveRecipe(recipeId)
                } catch {
                    print("❌ Failed to migrate recipe \(recipeId): \(error)")
                }
            }
        }
        
        // Clear local storage after successful migration
        UserDefaults.standard.removeObject(forKey: "savedRecipeIds")
        print("✅ Migration completed and local storage cleared")
    }
}

// MARK: - Error Handling Extension
extension RecipeRepository {
    enum RepositoryError: LocalizedError {
        case noResults
        case invalidInput
        case networkError(Error)
        case notAuthenticated
        
        var errorDescription: String? {
            switch self {
            case .noResults:
                return "No recipes found"
            case .invalidInput:
                return "Invalid search parameters"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .notAuthenticated:
                return "You must be logged in to perform this action"
            }
        }
    }
}
