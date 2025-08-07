//
//  LeftovaApp.swift
//  Leftova
//
//  Created by Zachary Rich on 6/6/25.
//

import SwiftUI

@main
struct LeftovaApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var authService = AuthenticationService.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.isAuthenticated {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                } else {
                    AuthenticationView()
                }
            }
            .environmentObject(authService)
            .onAppear {
                // Check authentication state on app launch
                Task {
                    try? await authService.getCurrentUser()
                }
            }
        }
    }
}
