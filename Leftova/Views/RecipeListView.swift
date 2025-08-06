//
//  RecipeListView.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//


import SwiftUI
import Kingfisher

struct RecipeListView: View {
    let recipes: [Recipe]
    let savedRecipeIds: Set<UUID>
    let onToggleSave: (UUID) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(recipes) { recipe in
                    NavigationLink(destination: RecipeDetailView(recipeId: recipe.id)) {
                        RecipeCard(
                            recipe: recipe,
                            isSaved: savedRecipeIds.contains(recipe.id),
                            onToggleSave: {
                                onToggleSave(recipe.id)
                            }
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }
}

struct RecipeCard: View {
    let recipe: Recipe
    let isSaved: Bool
    let onToggleSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image
            if let imageUrl = recipe.imageUrl, let url = URL(string: imageUrl) {
                KFImage(url)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 200)
                    .cornerRadius(12)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                    )
            }
            
            // Content
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if let description = recipe.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 16) {
                        if let prepTime = recipe.prepTime {
                            Label("\(prepTime)m", systemImage: "clock")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let matchCount = recipe.matchCount,
                           let totalIngredients = recipe.totalIngredients {
                            Label("\(matchCount)/\(totalIngredients)", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .foregroundColor(isSaved ? .red : .gray)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}