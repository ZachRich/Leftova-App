//
//  UsageResult.swift
//  Leftova
//
//  Created by Zach Rich on 8/7/25.
//


// File: Models/UsageModels.swift
// This file contains all the data models related to usage tracking and subscriptions

import Foundation

// MARK: - Usage Result Model
struct UsageResult: Codable {
    let allowed: Bool
    let currentCount: Int
    let remaining: Int
    let limit: Int
    let tier: String
    
    enum CodingKeys: String, CodingKey {
        case allowed
        case currentCount = "current_count"
        case remaining
        case limit
        case tier
    }
}

// MARK: - Usage Statistics Model
struct UsageStats: Codable {
    let tier: String
    let searchesToday: Int
    let searchesLimit: Int
    let savedRecipes: Int
    let savedRecipesLimit: Int
    let multiIngredientSearchesToday: Int
    let multiIngredientLimit: Int
    
    enum CodingKeys: String, CodingKey {
        case tier
        case searchesToday = "searches_today"
        case searchesLimit = "searches_limit"
        case savedRecipes = "saved_recipes"
        case savedRecipesLimit = "saved_recipes_limit"
        case multiIngredientSearchesToday = "multi_ingredient_searches_today"
        case multiIngredientLimit = "multi_ingredient_limit"
    }
    
    // Computed properties for convenience
    var searchesRemaining: Int {
        max(0, searchesLimit - searchesToday)
    }
    
    var canSaveMoreRecipes: Bool {
        savedRecipes < savedRecipesLimit
    }
    
    var canUseMultiIngredientSearch: Bool {
        multiIngredientSearchesToday < multiIngredientLimit
    }
    
    var savedRecipesRemaining: Int {
        max(0, savedRecipesLimit - savedRecipes)
    }
}

// MARK: - User Action Enum
enum UserAction: String, CaseIterable {
    case search = "search"
    case saveRecipe = "save_recipe"
    case ingredientSearch = "ingredient_search"
    case multiIngredientSearch = "multi_ingredient_search"
    
    var displayName: String {
        switch self {
        case .search:
            return "Recipe Search"
        case .saveRecipe:
            return "Save Recipe"
        case .ingredientSearch:
            return "Single Ingredient Search"
        case .multiIngredientSearch:
            return "Multi-Ingredient Search"
        }
    }
    
    var icon: String {
        switch self {
        case .search, .ingredientSearch, .multiIngredientSearch:
            return "magnifyingglass"
        case .saveRecipe:
            return "heart"
        }
    }
}

// MARK: - Trial Start Result
struct TrialStartResult: Codable {
    let success: Bool
    let message: String
    let trialEndsAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case success
        case message
        case trialEndsAt = "trial_ends_at"
    }
}
