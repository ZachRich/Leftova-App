# Leftova iOS App - API Documentation

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Core Services](#core-services)
- [View Models](#view-models)
- [Data Models](#data-models)
- [UI Components](#ui-components)
- [Configuration](#configuration)
- [Error Handling](#error-handling)
- [Testing Framework](#testing-framework)

## Architecture Overview

Leftova follows Clean Architecture principles with clear separation of concerns:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Presentation  │    │   Business      │    │      Data       │
│   Layer         │◄──►│   Logic Layer   │◄──►│     Layer       │
│                 │    │                 │    │                 │
│ • SwiftUI Views │    │ • Services      │    │ • Repositories  │
│ • ViewModels    │    │ • UseCases      │    │ • API Clients   │
│ • Components    │    │ • Validation    │    │ • Data Models   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Core Services

### AuthenticationService

**Purpose**: Manages user authentication with Supabase Auth

```swift
@MainActor
final class AuthenticationService: AuthenticationServiceProtocol, ObservableObject {
    static let shared = AuthenticationService()
    
    // MARK: - Published Properties
    @Published var currentUser: AuthUser?
    @Published var isAuthenticated: Bool
    
    // MARK: - Core Methods
    
    /// Sign up new user with email/password
    func signUp(email: String, password: String) async throws -> AuthUser
    
    /// Authenticate existing user
    func signIn(email: String, password: String) async throws -> AuthUser
    
    /// Sign out current user and clear session
    func signOut() async throws
    
    /// Send password reset email
    func resetPassword(email: String) async throws
    
    /// Get current authenticated user
    func getCurrentUser() async throws -> AuthUser?
}
```

**Key Features:**
- JWT-based session management
- Real-time authentication state via `@Published` properties
- Secure password reset flow
- Error handling with typed AuthError enum

**Usage Example:**
```swift
// Sign in user
do {
    let user = try await AuthenticationService.shared.signIn(
        email: "user@example.com",
        password: "securePassword"
    )
    print("Signed in: \(user.email)")
} catch {
    // Handle authentication error
    showErrorAlert(error.localizedDescription)
}
```

### UsageService

**Purpose**: Tracks usage limits and enforces freemium model restrictions

```swift
@MainActor
final class UsageService: UsageServiceProtocol, ObservableObject {
    static let shared = UsageService()
    
    // MARK: - Published Properties
    @Published var searchesRemaining: Int
    @Published var recipeSlotsRemaining: Int
    @Published var canUseAdvancedSearch: Bool
    @Published var currentTier: String
    @Published var usageStats: UsageStats?
    
    // MARK: - Core Methods
    
    /// Check if action is allowed and perform server-side validation
    func checkAndPerformAction(_ action: UserAction) async -> Bool
    
    /// Refresh usage statistics from server
    func refreshUsageStats() async
    
    /// Get user-friendly limit message for UI display
    func formattedLimitMessage(for action: UserAction) -> String
    
    /// Check if usage warning should be displayed
    func shouldShowLimitWarning(for action: UserAction) -> Bool
    
    /// Get color for usage indicators (green/yellow/red)
    func getLimitColor(for action: UserAction) -> Color
}
```

**Server Integration:**
- Uses Supabase RPC functions for secure validation
- Prevents client-side limit bypassing
- Real-time usage tracking

**Usage Example:**
```swift
// Check if search is allowed
let canSearch = await UsageService.shared.checkAndPerformAction(.search)
if canSearch {
    // Perform search
    searchRecipes()
} else {
    // Show upgrade prompt
    showPaywall = true
}

// Display usage status in UI
Text(usageService.formattedLimitMessage(for: .search))
    .foregroundColor(usageService.getLimitColor(for: .search))
```

### RecipeRepository

**Purpose**: Manages recipe data access with usage limit integration

```swift
final class RecipeRepository: RecipeRepositoryProtocol {
    
    // MARK: - Search Methods
    
    /// Search recipes by ingredients (basic, no limits)
    func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe]
    
    /// Search recipes by text query (basic, no limits)
    func searchByText(_ query: String) async throws -> [Recipe]
    
    // MARK: - Usage-Aware Methods
    
    /// Search by ingredients with automatic usage limit checking
    func searchByIngredientsWithLimit(_ ingredients: [String]) async throws -> [Recipe]
    
    /// Search by text with automatic usage limit checking
    func searchByTextWithLimit(_ query: String) async throws -> [Recipe]
    
    /// Save recipe with limit enforcement
    func saveRecipeWithLimit(_ recipeId: UUID) async throws
    
    // MARK: - Recipe Management
    
    /// Get user's saved recipes
    func getSavedRecipes() async throws -> [Recipe]
    
    /// Get saved recipe IDs for UI state
    func getSavedRecipeIds() async throws -> [UUID]
    
    /// Remove recipe from saved list
    func unsaveRecipe(_ recipeId: UUID) async throws
}
```

**Architecture Features:**
- Protocol-based design for testability
- Usage-aware methods that integrate with UsageService
- Efficient data fetching with join queries
- Error handling with typed errors (LimitError, RecipeError)

**Usage Example:**
```swift
// Search with automatic limit checking
do {
    let recipes = try await repository.searchByIngredientsWithLimit(["chicken", "rice"])
    updateUI(with: recipes)
} catch LimitError.searchLimitReached {
    showUpgradePrompt()
} catch {
    showErrorMessage(error.localizedDescription)
}
```

## View Models

### RecipeSearchViewModel

**Purpose**: Manages recipe search UI state and business logic

```swift
@MainActor
final class RecipeSearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var selectedIngredients: [String] = []
    @Published var searchText = ""
    @Published var errorMessage: String?
    @Published var savedRecipeIds: Set<UUID> = []
    @Published var showingPaywall = false
    
    // MARK: - Dependencies (Protocol-based for testing)
    private let repository: RecipeRepositoryProtocol
    private let usageService: UsageServiceProtocol
    
    // MARK: - Search Methods
    
    /// Search recipes by selected ingredients
    func searchRecipes() async
    
    /// Search recipes by text query
    func searchByText() async
    
    // MARK: - Recipe Management
    
    /// Toggle save/unsave status for a recipe
    func toggleSaveRecipe(_ recipeId: UUID) async
    
    /// Load saved recipe IDs for UI state
    func loadSavedRecipeIds() async
    
    // MARK: - Ingredient Management
    
    /// Add ingredient to selection (with limit checking)
    func addIngredient(_ ingredient: String)
    
    /// Remove ingredient from selection
    func removeIngredient(_ ingredient: String)
    
    /// Clear all selected ingredients
    func clearIngredients()
}
```

**Features:**
- MVVM pattern with clean separation
- Real-time UI updates via `@Published`
- Error handling with user-friendly messages
- Dependency injection for testability

### ProfileViewModel

**Purpose**: Manages user profile and account information

```swift
@MainActor
final class ProfileViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var user: AuthUser?
    @Published var usageStats: UsageStats?
    @Published var subscriptionStatus: UserSubscriptionStatus?
    @Published var isLoading = false
    @Published var showingDeleteAccount = false
    
    // MARK: - Computed Properties
    var savedRecipesCount: Int { usageStats?.savedRecipes ?? 0 }
    var subscriptionTier: String { subscriptionStatus?.subscriptionTier ?? "free" }
    var isPremium: Bool { subscriptionTier == "premium" }
    
    // MARK: - Methods
    
    /// Load user profile data
    func loadUserData() async
    
    /// Load usage statistics
    func loadStats() async
    
    /// Delete user account
    func deleteAccount() async
    
    /// Sign out current user
    func signOut() async
}
```

## Data Models

### Recipe

**Purpose**: Core recipe data model with full metadata

```swift
struct Recipe: Codable, Identifiable {
    // MARK: - Core Properties
    let id: UUID
    let title: String
    let description: String?
    let sourceUrl: String?
    let sourceName: String?
    let imageUrl: String?
    
    // MARK: - Recipe Details
    let servings: Int?
    let prepTime: Int?      // Minutes
    let cookTime: Int?      // Minutes
    let difficulty: String? // "Easy", "Medium", "Hard"
    let cuisine: String?
    let nutrition: Nutrition?
    let createdAt: Date?
    let updatedAt: Date?
    
    // MARK: - Search-Specific Properties
    var matchCount: Int?        // Ingredients matched in search
    var totalIngredients: Int?  // Total ingredients in recipe
    
    // MARK: - Computed Properties
    
    /// Parsed instructions from JSON string
    var instructions: [Instruction]? {
        guard let instructionsJson = instructionsJson else { return nil }
        // Parse JSON instructions
        return parseInstructions(from: instructionsJson)
    }
    
    /// Instructions as ordered string array
    var instructionsArray: [String] {
        instructions?.sorted { $0.step < $1.step }.map { $0.text } ?? []
    }
}
```

### UsageStats

**Purpose**: User usage statistics and limits

```swift
struct UsageStats: Codable {
    // MARK: - Server Properties
    let tier: String                  // "free" or "premium"
    let searchesToday: Int           // Searches performed today
    let searchesLimit: Int           // Daily search limit
    let savedRecipes: Int            // Currently saved recipes
    let savedRecipesLimit: Int       // Maximum saved recipes
    let multiIngredientSearchesToday: Int
    let multiIngredientLimit: Int
    
    // MARK: - Computed Properties
    
    /// Remaining searches for today
    var searchesRemaining: Int {
        max(0, searchesLimit - searchesToday)
    }
    
    /// Available recipe save slots
    var savedRecipesRemaining: Int {
        max(0, savedRecipesLimit - savedRecipes)
    }
    
    /// Whether user can save more recipes
    var canSaveMoreRecipes: Bool {
        savedRecipes < savedRecipesLimit
    }
    
    /// Whether multi-ingredient search is available
    var canUseMultiIngredientSearch: Bool {
        multiIngredientSearchesToday < multiIngredientLimit
    }
}
```

### UserAction

**Purpose**: Enumeration of trackable user actions

```swift
enum UserAction: String, CaseIterable {
    case search = "search"
    case saveRecipe = "save_recipe"
    case ingredientSearch = "ingredient_search"
    case multiIngredientSearch = "multi_ingredient_search"
    
    // MARK: - Display Properties
    
    var displayName: String {
        switch self {
        case .search: return "Recipe Search"
        case .saveRecipe: return "Save Recipe"
        case .ingredientSearch: return "Single Ingredient Search"
        case .multiIngredientSearch: return "Multi-Ingredient Search"
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
```

## UI Components

### UsageLimitBanner

**Purpose**: Display current usage status and limits

```swift
struct UsageLimitBanner: View {
    @StateObject private var usageService = UsageService.shared
    @StateObject private var subscriptionService = SubscriptionService.shared
    
    var body: some View {
        // Real-time usage display with color coding
        // Upgrade prompts for free users
        // Premium status for subscribed users
    }
    
    // MARK: - Helper Methods
    
    /// Get current number of searches performed
    private func getCurrentSearches() -> Int
    
    /// Get search limit for current user
    private func getSearchesLimit() -> Int
    
    /// Get current saved recipes count
    private func getCurrentSavedRecipes() -> Int
    
    /// Get saved recipes limit for current user
    private func getSavedRecipesLimit() -> Int
}
```

### IngredientInputViewWithLimits

**Purpose**: Ingredient input with built-in limit enforcement

```swift
struct IngredientInputViewWithLimits: View {
    @Binding var ingredients: [String]
    var showBanner: Bool = true
    
    @State private var currentIngredient = ""
    @State private var showUpgradePrompt = false
    @StateObject private var usageService = UsageService.shared
    
    var body: some View {
        VStack {
            // Header with limit information (optional)
            if showBanner { headerView }
            
            // Input field with validation
            inputFieldView
            
            // Selected ingredients display
            selectedIngredientsView
            
            // Upgrade prompt (for free users at limit)
            if showBanner && shouldShowUpgradeHint {
                upgradeHintView
            }
        }
    }
    
    // MARK: - Computed Properties
    
    /// Whether input should be disabled due to limits
    private var shouldDisableInput: Bool
    
    /// Whether to show upgrade hint
    private var shouldShowUpgradeHint: Bool
    
    /// Number of ingredients remaining for free users
    private var remainingIngredients: Int
}
```

### RecipeCard

**Purpose**: Individual recipe display with save functionality

```swift
struct RecipeCard: View {
    let recipe: Recipe
    let isSaved: Bool
    let onToggleSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Recipe image with fallback
            recipeImageView
            
            // Recipe content (title, description, metadata)
            recipeContentView
            
            // Action buttons (save/unsave)
            actionButtonsView
        }
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 5)
    }
    
    // MARK: - Subviews
    
    private var recipeImageView: some View {
        // KFImage for efficient image loading
        // Fallback placeholder for missing images
    }
    
    private var recipeContentView: some View {
        // Title, description, metadata display
        // Ingredient matching information
        // Cooking time, servings, difficulty
    }
    
    private var actionButtonsView: some View {
        // Save/unsave toggle button
        // Visual feedback for saved state
    }
}
```

## Configuration

### Config.swift Structure

```swift
enum Config {
    // MARK: - Backend Configuration
    static let supabaseURL = "YOUR_SUPABASE_URL"
    static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
    
    // MARK: - StoreKit Configuration
    struct StoreKit {
        static let monthlySubscriptionID = "com.leftova.premium.monthly"
        static let annualSubscriptionID = "com.leftova.premium.annual"
        static let subscriptionGroupID = "leftova_premium"
    }
    
    // MARK: - Free Tier Configuration
    struct FreeTier {
        // Usage Limits
        static let dailySearchLimit = 5
        static let savedRecipesLimit = 20
        static let multiIngredientSearchLimit = 0  // 0 = disabled
        static let canUseAdvancedSearch = false
        
        // Trial Configuration
        static let trialDurationDays = 7
        
        // Warning Thresholds
        struct WarningThresholds {
            static let searchesRemaining = 2
            static let savedRecipesRemaining = 5
        }
        
        // UI Configuration
        struct UI {
            static let searchResultLimit = 10
            static let unlimitedValue = 999999
        }
    }
}
```

**Configuration Features:**
- Centralized settings management
- Easy adjustment of freemium limits
- Environment-specific configurations
- Type-safe configuration access

## Error Handling

### Error Types

```swift
// Authentication Errors
enum AuthError: LocalizedError {
    case notAuthenticated
    case invalidCredentials
    case networkError
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .invalidCredentials:
            return "Invalid email or password"
        case .networkError:
            return "Network connection failed"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}

// Usage Limit Errors
enum LimitError: LocalizedError {
    case searchLimitReached
    case saveLimitReached
    case multiIngredientNotAllowed
    
    var errorDescription: String? {
        switch self {
        case .searchLimitReached:
            return "You've reached your daily search limit. Upgrade to Premium for unlimited searches."
        case .saveLimitReached:
            return "You've reached your saved recipe limit. Upgrade to Premium for unlimited saves."
        case .multiIngredientNotAllowed:
            return "Multi-ingredient search is a Premium feature."
        }
    }
    
    var recoverySuggestion: String? {
        return "Upgrade to Premium"
    }
}

// Recipe Data Errors
enum RecipeError: LocalizedError {
    case notAuthenticated
    case networkError
    case invalidData
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .networkError:
            return "Network connection error"
        case .invalidData:
            return "Invalid recipe data received"
        case .notFound:
            return "Recipe not found"
        }
    }
}
```

### Error Handling Patterns

```swift
// In ViewModels
func performAction() async {
    do {
        let result = try await service.performOperation()
        updateUI(with: result)
    } catch let error as LimitError {
        // Handle usage limits specifically
        showUpgradePrompt(for: error)
    } catch let error as AuthError {
        // Handle authentication errors
        showAuthenticationFlow()
    } catch {
        // Generic error handling
        showErrorMessage(error.localizedDescription)
    }
}

// In Services
func performOperation() async throws -> Result {
    guard let userId = authService.currentUserId else {
        throw AuthError.notAuthenticated
    }
    
    guard hasCapacity() else {
        throw LimitError.searchLimitReached
    }
    
    do {
        return try await apiCall()
    } catch {
        throw RecipeError.networkError
    }
}
```

## Testing Framework

### Test Structure

```
LeftovaTests/
├── TestHelpers/
│   ├── TestFixtures.swift      # Test data fixtures
│   ├── MockServices.swift     # Mock service implementations
│   └── TestUtilities.swift    # Test utilities and helpers
├── Unit/
│   ├── Services/
│   ├── ViewModels/
│   ├── Models/
│   └── Config/
├── Integration/
│   └── End-to-end test scenarios
└── Performance/
    └── Performance benchmarks
```

### Mock Services

```swift
// Mock Authentication Service
@MainActor
class MockAuthenticationService: AuthenticationServiceProtocol, ObservableObject {
    @Published var currentUser: AuthUser?
    @Published var isAuthenticated = false
    
    // Test control properties
    var shouldFailLogin = false
    var loginDelay: TimeInterval = 0
    
    func signIn(email: String, password: String) async throws -> AuthUser {
        if loginDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(loginDelay * 1_000_000_000))
        }
        
        if shouldFailLogin {
            throw AuthError.invalidCredentials
        }
        
        let user = AuthUser(id: "test-user", email: email)
        currentUser = user
        isAuthenticated = true
        return user
    }
    
    // Additional mock methods...
}

// Mock Usage Service
@MainActor
class MockUsageService: UsageServiceProtocol, ObservableObject {
    @Published var searchesRemaining = 5
    @Published var recipeSlotsRemaining = 10
    @Published var currentTier = "free"
    
    // Test control
    var checkAndPerformActionResults: [UserAction: Bool] = [:]
    
    func checkAndPerformAction(_ action: UserAction) async -> Bool {
        return checkAndPerformActionResults[action] ?? true
    }
    
    // Additional mock methods...
}
```

### Test Examples

```swift
// Unit Test Example
class UsageServiceTests: XCTestCase {
    var mockAuthService: MockAuthenticationService!
    var usageService: UsageService!
    
    override func setUp() {
        mockAuthService = MockAuthenticationService()
        usageService = UsageService(authService: mockAuthService)
    }
    
    func testSearchLimitEnforcement() async {
        // Given
        mockAuthService.setCurrentUser(TestFixtures.freeUser)
        usageService.searchesRemaining = 0
        
        // When
        let result = await usageService.checkAndPerformAction(.search)
        
        // Then
        XCTAssertFalse(result, "Should deny search when limit reached")
    }
}

// Integration Test Example
class RecipeSearchIntegrationTests: XCTestCase {
    var viewModel: RecipeSearchViewModel!
    var mockRepository: MockRecipeRepository!
    var mockUsageService: MockUsageService!
    
    override func setUp() {
        mockRepository = MockRecipeRepository()
        mockUsageService = MockUsageService()
        viewModel = RecipeSearchViewModel(
            repository: mockRepository,
            usageService: mockUsageService
        )
    }
    
    func testSearchFlowWithLimits() async {
        // Given
        mockRepository.setSearchResults(TestFixtures.sampleRecipes)
        mockUsageService.checkAndPerformActionResults[.search] = true
        
        // When
        viewModel.selectedIngredients = ["chicken"]
        await viewModel.searchRecipes()
        
        // Then
        XCTAssertEqual(viewModel.recipes.count, 2)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingPaywall)
    }
}
```

### Performance Testing

```swift
class PerformanceTests: XCTestCase {
    func testSearchPerformance() {
        let repository = MockRecipeRepository()
        repository.setSearchResults(MockDataGenerator.randomRecipes(count: 1000))
        
        measure(metrics: [XCTClockMetric()]) {
            let expectation = XCTestExpectation()
            Task {
                _ = try await repository.searchByIngredients(["chicken"])
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10.0)
        }
    }
    
    func testMemoryUsage() {
        measure(metrics: [XCTMemoryMetric()]) {
            let recipes = MockDataGenerator.randomRecipes(count: 500)
            let encoder = JSONEncoder()
            _ = recipes.compactMap { try? encoder.encode($0) }
        }
    }
}
```

---

This API documentation provides comprehensive coverage of the Leftova iOS app's architecture, components, and usage patterns. It serves as both a reference for developers working on the project and documentation for the codebase's design decisions and implementation details.