//
//  IngredientInputView.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//


import SwiftUI

struct IngredientInputView: View {
    @Binding var ingredients: [String]
    @State private var currentIngredient = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What's in your kitchen?")
                .font(.headline)
            
            HStack {
                TextField("Add ingredient", text: $currentIngredient)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isInputFocused)
                    .onSubmit {
                        addIngredient()
                    }
                
                Button("Add") {
                    addIngredient()
                }
                .disabled(currentIngredient.isEmpty)
            }
            
            if !ingredients.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(ingredients, id: \.self) { ingredient in
                            IngredientChip(
                                ingredient: ingredient,
                                onDelete: {
                                    ingredients.removeAll { $0 == ingredient }
                                }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func addIngredient() {
        let trimmed = currentIngredient.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !ingredients.contains(trimmed) {
            ingredients.append(trimmed)
            currentIngredient = ""
        }
    }
}

// IngredientChip is now in its own component file