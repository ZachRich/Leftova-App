//
//  RecipeRepository.swift
//  Leftova
//
//  Modern recipe repository with clean architecture
//

import Foundation
import Supabase

// MARK: - Repository Protocol
protocol RecipeRepositoryProtocol {
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe]
    func searchByText(_ query: String) async throws -> [Recipe]
    func saveRecipe(_ recipeId: UUID) async throws
    func unsaveRecipe(_ recipeId: UUID) async throws
    func getSavedRecipes() async throws -> [Recipe]
    func getSavedRecipeIds() async throws -> [UUID]
    func getRecipe(id: UUID) async throws -> Recipe?
    
    // Usage-aware methods
    func searchByIngredientsWithLimit(_ ingredients: [String]) async throws -> [Recipe]
    func searchByTextWithLimit(_ query: String) async throws -> [Recipe]
    func saveRecipeWithLimit(_ recipeId: UUID) async throws
}

// MARK: - Repository Implementation
final class RecipeRepository: RecipeRepositoryProtocol {
    // MARK: - Dependencies
    private let client: SupabaseClient
    private let decoder: JSONDecoder
    private let authService: AuthenticationServiceProtocol
    private let usageService: UsageServiceProtocol
    
    // MARK: - Initialization
    init(
        client: SupabaseClient = SupabaseService.shared.client,
        decoder: JSONDecoder = SupabaseService.shared.decoder,
        authService: AuthenticationServiceProtocol = AuthenticationService.shared,
        usageService: UsageServiceProtocol = UsageService.shared
    ) {
        self.client = client
        self.decoder = decoder
        self.authService = authService
        self.usageService = usageService
    }
    
    // MARK: - Search Methods
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe] {
        guard let userId = authService.currentUserId else {
            throw RecipeError.notAuthenticated
        }
        
        struct SearchParams: Codable {
            let ingredient_list: [String]
        }
        
        let params = SearchParams(ingredient_list: ingredients)
        
        let response = try await client
            .rpc("search_by_ingredients", params: params)
            .execute()
        
        var recipes = try decoder.decode([Recipe].self, from: response.data)
        
        // Limit results for free users
        if !usageService.isPremium {
            recipes = Array(recipes.prefix(Config.FreeTier.UI.searchResultLimit))
        }
        
        return recipes
    }
    
    func searchByText(_ query: String) async throws -> [Recipe] {
        guard let userId = authService.currentUserId else {
            throw RecipeError.notAuthenticated
        }
        
        // Since you don't have a text search RPC, using direct table query temporarily
        // You may want to create a text search RPC function later
        let limit = usageService.isPremium ? 100 : Config.FreeTier.UI.searchResultLimit
        
        let response = try await client
            .from("recipes")
            .select("*")
            .or("title.ilike.%\(query)%,description.ilike.%\(query)%")
            .limit(limit)
            .execute()
        
        return try decoder.decode([Recipe].self, from: response.data)
    }
    
    // MARK: - Save/Unsave Methods
    func saveRecipe(_ recipeId: UUID) async throws {
        guard let userId = authService.currentUserId else {
            throw RecipeError.notAuthenticated
        }
        
        let saveData = SaveRecipeRequest(
            userId: userId,
            recipeId: recipeId.uuidString
        )
        
        _ = try await client
            .from("saved_recipes")
            .insert(saveData)
            .execute()
    }
    
    func unsaveRecipe(_ recipeId: UUID) async throws {
        guard let userId = authService.currentUserId else {
            throw RecipeError.notAuthenticated
        }
        
        _ = try await client
            .from("saved_recipes")
            .delete()
            .eq("user_id", value: userId)
            .eq("recipe_id", value: recipeId.uuidString)
            .execute()
    }
    
    // MARK: - Get Saved Recipes
    func getSavedRecipes() async throws -> [Recipe] {
        guard let userId = authService.currentUserId else {
            throw RecipeError.notAuthenticated
        }
        
        // Join saved_recipes with recipes table to get full recipe data in one query
        let response = try await client
            .from("saved_recipes")
            .select("""
                recipe_id,
                recipes!inner(*)
            """)
            .eq("user_id", value: userId)
            .execute()
        
        // Parse the joined data
        struct SavedRecipeWithDetails: Codable {
            let recipeId: String
            let recipes: Recipe
            
            enum CodingKeys: String, CodingKey {
                case recipeId = "recipe_id"
                case recipes
            }
        }
        
        do {
            let savedRecipesWithDetails = try decoder.decode([SavedRecipeWithDetails].self, from: response.data)
            return savedRecipesWithDetails.map { $0.recipes }
        } catch {
            print("Failed to decode saved recipes: \(error)")
            // Fallback to fetching one by one if the join fails
            return try await getSavedRecipesFallback(userId: userId)
        }
    }
    
    private func getSavedRecipesFallback(userId: String) async throws -> [Recipe] {
        // First get the saved recipe IDs
        let response = try await client
            .from("saved_recipes")
            .select("recipe_id")
            .eq("user_id", value: userId)
            .execute()
        
        let savedData = try decoder.decode([SavedRecipeData].self, from: response.data)
        let recipeIds = savedData.compactMap { UUID(uuidString: $0.recipeId) }
        
        guard !recipeIds.isEmpty else { return [] }
        
        // Fetch recipes one by one
        var recipes: [Recipe] = []
        for recipeId in recipeIds {
            if let recipe = try await getRecipe(id: recipeId) {
                recipes.append(recipe)
            }
        }
        
        return recipes
    }
    
    func getSavedRecipeIds() async throws -> [UUID] {
        guard let userId = authService.currentUserId else {
            throw RecipeError.notAuthenticated
        }
        
        let response = try await client
            .from("saved_recipes")
            .select("recipe_id")
            .eq("user_id", value: userId)
            .execute()
        
        let savedData = try decoder.decode([SavedRecipeData].self, from: response.data)
        return savedData.compactMap { UUID(uuidString: $0.recipeId) }
    }
    
    func getRecipe(id: UUID) async throws -> Recipe? {
        do {
            let response = try await client
                .from("recipes")
                .select("*")
                .eq("id", value: id.uuidString)
                .single()
                .execute()
            
            return try decoder.decode(Recipe.self, from: response.data)
        } catch {
            // If the recipe doesn't exist, return nil instead of throwing
            print("Failed to get recipe \(id): \(error)")
            return nil
        }
    }
}

// MARK: - Usage-Aware Methods Extension
extension RecipeRepository {
    /// Search by ingredients with usage limit enforcement
    func searchByIngredientsWithLimit(_ ingredients: [String]) async throws -> [Recipe] {
        // Check if this is a multi-ingredient search
        if ingredients.count > 1 {
            let result = await usageService.checkAndPerformAction(.multiIngredientSearch)
            guard result else {
                throw LimitError.multiIngredientNotAllowed
            }
        } else {
            // Single ingredient searches count toward the general search limit
            let result = await usageService.checkAndPerformAction(.search)
            guard result else {
                throw LimitError.searchLimitReached
            }
        }
        
        return try await searchByIngredients(ingredients)
    }
    
    /// Search by text with usage limit enforcement
    func searchByTextWithLimit(_ query: String) async throws -> [Recipe] {
        let result = await usageService.checkAndPerformAction(.search)
        guard result else {
            throw LimitError.searchLimitReached
        }
        
        return try await searchByText(query)
    }
    
    /// Save a recipe with usage limit enforcement
    func saveRecipeWithLimit(_ recipeId: UUID) async throws {
        let result = await usageService.checkAndPerformAction(.saveRecipe)
        guard result else {
            throw LimitError.saveLimitReached
        }
        
        try await saveRecipe(recipeId)
    }
}

// MARK: - Models
private struct SaveRecipeRequest: Codable {
    let userId: String
    let recipeId: String
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case recipeId = "recipe_id"
    }
}

struct SavedRecipeData: Codable {
    let recipeId: String
    
    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
    }
}

// MARK: - Errors
enum RecipeError: LocalizedError {
    case notAuthenticated
    case networkError
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .networkError:
            return "Network connection error"
        case .invalidData:
            return "Invalid data received"
        }
    }
}

enum LimitError: LocalizedError {
    case searchLimitReached
    case saveLimitReached
    case multiIngredientNotAllowed
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .searchLimitReached:
            return "You've reached your daily search limit. Upgrade to Premium for unlimited searches."
        case .saveLimitReached:
            return "You've reached your saved recipe limit. Upgrade to Premium for unlimited saves."
        case .multiIngredientNotAllowed:
            return "Multi-ingredient search is a Premium feature. Upgrade to search with multiple ingredients."
        case .notAuthenticated:
            return "Please sign in to continue."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .searchLimitReached, .saveLimitReached, .multiIngredientNotAllowed:
            return "Upgrade to Premium"
        case .notAuthenticated:
            return "Sign In"
        }
    }
}