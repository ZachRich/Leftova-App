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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
