//
//  IngredientChip.swift
//  Leftova
//
//  Created by Claude Code on 8/7/25.
//

import SwiftUI

struct IngredientChip: View {
    let ingredient: String
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(ingredient)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(16)
    }
}