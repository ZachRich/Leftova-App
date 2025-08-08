//
//  SmartPaywallTrigger.swift
//  Leftova
//
//  Created by Zach Rich on 8/7/25.
//
import Foundation
import SwiftUI

// MARK: - Paywall Trigger Enum
enum PaywallTrigger {
    case onboardingComplete
    case limitReached
    case sessionBased
}

struct SmartPaywallTrigger: ViewModifier {
    @Binding var shouldShowPaywall: Bool
    let trigger: PaywallTrigger
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                checkPaywallTrigger()
            }
    }
    
    private func checkPaywallTrigger() {
        switch trigger {
        case .onboardingComplete:
            // Show after user saves 3rd recipe
            if UserDefaults.standard.integer(forKey: "saved_recipes") >= 3 {
                shouldShowPaywall = true
            }
        case .limitReached:
            // Contextual trigger when hitting limits
            shouldShowPaywall = true
        case .sessionBased:
            // Show after 5th app session
            if UserDefaults.standard.integer(forKey: "app_sessions") >= 5 {
                shouldShowPaywall = true
            }
        }
    }
}
