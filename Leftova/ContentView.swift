//
//  ContentView.swift
//  Leftova
//
//  Created by Zach Rich on 8/6/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            RecipeSearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
            
            SavedRecipesView()
                .tabItem {
                    Label("Saved", systemImage: "heart.fill")
                }
        }
    }
}
