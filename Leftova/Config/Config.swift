//
//  Config.swift
//  Leftova
//
//  Central configuration file for app-wide settings
//
//  ⚠️  IMPORTANT SECURITY NOTES:
//  - This file is gitignored to prevent exposing API keys
//  - Copy from Config.template.swift for initial setup  
//  - Never commit actual API keys to version control
//  - Use environment variables in CI/CD pipelines
//

import Foundation

/**
 Central configuration enum containing all app settings.
 
 This configuration system provides:
 - Type-safe access to all settings
 - Environment-specific configurations
 - Easy adjustment of freemium model parameters
 - Centralized management of external service credentials
 
 Security:
 - File is gitignored to prevent credential exposure
 - Template file provided for easy setup
 - Supports environment variable overrides for CI/CD
 
 Usage:
 ```swift
 let url = Config.supabaseURL
 let limit = Config.FreeTier.dailySearchLimit
 ```
 */
enum Config {
    
    // MARK: - Backend Configuration
    
    /// Supabase project URL - the base URL for your Supabase instance
    /// Format: https://your-project-ref.supabase.co
    static let supabaseURL = "https://sfstuksodesluvsimeur.supabase.co"
    
    /**
     Supabase anonymous key for client-side authentication.
     
     You can use either format:
     - JWT format: "eyJ..." (recommended for new projects)  
     - Publishable format: "sb_publishable_..." (legacy, still supported)
     
     Both formats provide the same security and functionality.
     Supabase maintains backward compatibility between formats.
     
     Security: This key is safe for client-side use as it only allows
     operations permitted by your Row Level Security (RLS) policies.
     */
    static let supabaseAnonKey = "key"
    
    // MARK: - StoreKit Configuration
    
    /**
     StoreKit subscription configuration for in-app purchases.
     
     These identifiers must match exactly with the products configured
     in App Store Connect. Any mismatch will result in purchase failures.
     
     Setup Requirements:
     1. Create products in App Store Connect with these exact IDs
     2. Configure subscription group with the specified group ID
     3. Set up subscription pricing and availability
     4. Test with sandbox accounts before production release
     */
    struct StoreKit {
        
        /// Monthly subscription product ID - must match App Store Connect
        static let monthlySubscriptionID = "com.leftova.premium.monthly"
        
        /// Annual subscription product ID - must match App Store Connect  
        static let annualSubscriptionID = "com.leftova.premium.annual"
        
        /// Subscription group identifier for related subscriptions
        static let subscriptionGroupID = "leftova_premium"
        
        /// Sandbox mode detection (automatically determined)
        static var isSandboxEnvironment: Bool {
            #if DEBUG
            return true
            #else
            // Production detection logic could be added here
            return false
            #endif
        }
    }
    
    struct FreeTier {
        // Search limits
        static let dailySearchLimit = 5         // 5 searches per day (enough for casual use)
        static let dailyIngredientSearchLimit = 5 // Same as daily search limit (they share the same counter)
        
        // Recipe limits  
        static let savedRecipesLimit = 20       // 20 saved recipes (reasonable cookbook size)
        
        // Advanced features
        static let multiIngredientSearchLimit = 0  // 0 = not allowed for free users (premium feature)
        static let canUseAdvancedSearch = false    // Multi-ingredient search is premium only
        
        // Trial configuration
        static let trialDurationDays = 7        // 7-day free trial (standard for apps)
        
        // Warning thresholds - when to show orange/warning colors
        struct WarningThresholds {
            static let searchesRemaining = 2    // Show warning when <= 2 searches remaining
            static let savedRecipesRemaining = 5 // Show warning when <= 5 recipe slots remaining
        }
        
        // UI configuration
        struct UI {
            static let searchResultLimit = 10   // Max 10 results per search for free users
            static let unlimitedValue = 999999  // Value to represent unlimited usage
        }
    }
}

