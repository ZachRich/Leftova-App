# Leftova Developer Guide

## 🎯 Quick Start for Developers

### Prerequisites
- **Xcode 15.0+**
- **iOS 17.0+** deployment target
- **Swift 5.9+**
- **Supabase account** with configured project
- **Basic knowledge of SwiftUI and MVVM patterns**

### First-Time Setup

1. **Clone and Setup**
   ```bash
   git clone <repository-url>
   cd Leftova-App
   ./setup.sh  # This creates Config.swift and installs git hooks
   ```

2. **Configure Supabase**
   Edit `Leftova/Config/Config.swift` with your credentials:
   ```swift
   static let supabaseURL = "https://your-project.supabase.co"
   static let supabaseAnonKey = "your-anon-key-here"
   ```

3. **Test the Setup**
   ```bash
   # Build and run tests
   xcodebuild test -scheme Leftova -destination 'platform=iOS Simulator,name=iPhone 15'
   ```

## 🏗️ Architecture Deep Dive

### Clean Architecture Layers

```
┌─────────────────────────────────────────────────────────┐
│                    Presentation Layer                    │
├─────────────────────────────────────────────────────────┤
│ • SwiftUI Views (RecipeSearchView, ProfileView, etc.)  │
│ • ViewModels (RecipeSearchViewModel, etc.)             │
│ • UI Components (UsageLimitBanner, RecipeCard, etc.)   │
└─────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────┐
│                   Business Logic Layer                  │
├─────────────────────────────────────────────────────────┤
│ • Services (UsageService, AuthenticationService)       │
│ • Use Cases (Recipe search, User management)           │
│ • Business Rules (Usage limits, Subscription logic)    │
└─────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────┐
│                      Data Layer                         │
├─────────────────────────────────────────────────────────┤
│ • Repositories (RecipeRepository)                      │
│ • API Clients (Supabase integration)                   │
│ • Data Models (Recipe, UsageStats, AuthUser)           │
└─────────────────────────────────────────────────────────┘
```

### Key Design Principles

1. **Protocol-Oriented Programming**: All services implement protocols for testability
2. **Dependency Injection**: Dependencies are injected via initializers
3. **Single Responsibility**: Each class has one clear purpose
4. **Reactive Programming**: UI updates automatically via `@Published` properties
5. **Error Handling**: Comprehensive error types with user-friendly messages

## 🔧 Development Patterns

### MVVM with SwiftUI

```swift
// ViewModel Example
@MainActor
final class RecipeSearchViewModel: ObservableObject {
    // MARK: - Published Properties (trigger UI updates)
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // MARK: - Dependencies (injected for testability)
    private let repository: RecipeRepositoryProtocol
    private let usageService: UsageServiceProtocol
    
    // MARK: - Initialization with DI
    init(
        repository: RecipeRepositoryProtocol = RecipeRepository(),
        usageService: UsageServiceProtocol = UsageService.shared
    ) {
        self.repository = repository
        self.usageService = usageService
    }
    
    // MARK: - Business Logic
    func searchRecipes() async {
        isLoading = true
        errorMessage = nil
        
        do {
            recipes = try await repository.searchByIngredientsWithLimit(selectedIngredients)
        } catch let error as LimitError {
            errorMessage = error.errorDescription
            showPaywall()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
```

### Service Layer Pattern

```swift
// Protocol First
protocol UsageServiceProtocol {
    func checkAndPerformAction(_ action: UserAction) async -> Bool
    var searchesRemaining: Int { get }
    // ... other methods
}

// Implementation with real Supabase integration
@MainActor
final class UsageService: UsageServiceProtocol, ObservableObject {
    static let shared = UsageService()
    
    @Published var searchesRemaining = 5
    
    func checkAndPerformAction(_ action: UserAction) async -> Bool {
        // Server-side validation via Supabase RPC
        let result = try await supabase.rpc("check_and_record_usage", params: ...)
        return result.allowed
    }
}

// Mock for testing
class MockUsageService: UsageServiceProtocol {
    var searchesRemaining = 5
    var mockResults: [UserAction: Bool] = [:]
    
    func checkAndPerformAction(_ action: UserAction) async -> Bool {
        return mockResults[action] ?? true
    }
}
```

### Repository Pattern

```swift
// Repository handles data access and business rules
final class RecipeRepository: RecipeRepositoryProtocol {
    private let client: SupabaseClient
    private let usageService: UsageServiceProtocol
    
    // Usage-aware method that integrates limits
    func searchByIngredientsWithLimit(_ ingredients: [String]) async throws -> [Recipe] {
        // 1. Check usage limits first
        if ingredients.count > 1 {
            let allowed = await usageService.checkAndPerformAction(.multiIngredientSearch)
            guard allowed else { throw LimitError.multiIngredientNotAllowed }
        } else {
            let allowed = await usageService.checkAndPerformAction(.search)
            guard allowed else { throw LimitError.searchLimitReached }
        }
        
        // 2. Perform actual search
        return try await searchByIngredients(ingredients)
    }
    
    // Basic search method (no limits, used internally)
    private func searchByIngredients(_ ingredients: [String]) async throws -> [Recipe] {
        let response = try await client.rpc("search_by_ingredients", params: ...)
        return try decoder.decode([Recipe].self, from: response.data)
    }
}
```

## 📱 UI Development

### Component Architecture

```swift
// Reusable component with configuration
struct UsageLimitBanner: View {
    @StateObject private var usageService = UsageService.shared
    var showUpgradeButton: Bool = true
    
    var body: some View {
        HStack {
            // Usage information
            VStack(alignment: .leading) {
                Text("Daily Searches: \(usageService.searchesRemaining)")
                Text("Saved Recipes: \(usageService.recipeSlotsRemaining)")
            }
            
            Spacer()
            
            // Conditional upgrade button
            if showUpgradeButton && !usageService.isPremium {
                Button("Upgrade") { /* show paywall */ }
            }
        }
        .padding()
        .background(bannerColor)
        .cornerRadius(12)
    }
    
    private var bannerColor: Color {
        usageService.shouldShowLimitWarning(for: .search) ? .orange.opacity(0.2) : .blue.opacity(0.1)
    }
}
```

### State Management Best Practices

```swift
// 1. Use @StateObject for ViewModels (owns the object)
struct RecipeSearchView: View {
    @StateObject private var viewModel = RecipeSearchViewModel()
    
    var body: some View { /* ... */ }
}

// 2. Use @ObservedObject for passed-in objects
struct RecipeCard: View {
    @ObservedObject var viewModel: RecipeSearchViewModel
    let recipe: Recipe
    
    var body: some View { /* ... */ }
}

// 3. Use @EnvironmentObject for app-wide state
struct ContentView: View {
    var body: some View {
        TabView {
            RecipeSearchView()
                .environmentObject(UsageService.shared)
        }
    }
}

struct RecipeSearchView: View {
    @EnvironmentObject var usageService: UsageService
    
    var body: some View { /* ... */ }
}
```

## 🔐 Security Implementation

### API Key Management

```swift
// ❌ NEVER do this (exposed in binary)
let apiKey = "hardcoded-secret-key"

// ✅ DO this (Config.swift is gitignored)
enum Config {
    static let supabaseURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? ""
    static let supabaseAnonKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? ""
}

// ✅ Alternative: Use secure loading
private static func loadConfig() -> [String: String] {
    guard let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
          let plist = NSDictionary(contentsOfFile: path) as? [String: String] else {
        fatalError("Secrets.plist not found - copy from Secrets.template.plist")
    }
    return plist
}
```

### Row Level Security Integration

```swift
// All data access goes through authenticated user context
func getSavedRecipes() async throws -> [Recipe] {
    guard let userId = authService.currentUserId else {
        throw RecipeError.notAuthenticated
    }
    
    // RLS policy ensures user can only see their own saved recipes
    let response = try await client
        .from("saved_recipes")
        .select("recipe_id, recipes!inner(*)")
        .eq("user_id", value: userId)
        .execute()
    
    return try decoder.decode([Recipe].self, from: response.data)
}
```

### Input Validation

```swift
// Always validate user inputs
extension String {
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return self.range(of: emailRegex, options: [.regularExpression, .caseInsensitive]) != nil
    }
    
    var sanitizedIngredient: String? {
        let trimmed = self.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 50 else { return nil }
        
        // Remove potentially harmful characters
        let allowed = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: "-'"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
    }
}

// Use in ViewModels
func addIngredient(_ input: String) {
    guard let sanitized = input.sanitizedIngredient else {
        errorMessage = "Invalid ingredient name"
        return
    }
    
    selectedIngredients.append(sanitized)
}
```

## 🧪 Testing Strategy

### Unit Testing

```swift
// Test ViewModels with mocked dependencies
class RecipeSearchViewModelTests: XCTestCase {
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
    
    func testSearchWithResults() async {
        // Given
        let expectedRecipes = [TestFixtures.sampleRecipe]
        mockRepository.setSearchResults(expectedRecipes)
        mockUsageService.checkAndPerformActionResults[.search] = true
        
        // When
        viewModel.selectedIngredients = ["chicken"]
        await viewModel.searchRecipes()
        
        // Then
        XCTAssertEqual(viewModel.recipes.count, 1)
        XCTAssertEqual(viewModel.recipes[0].title, "Chicken Recipe")
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testSearchWhenLimitReached() async {
        // Given
        mockUsageService.checkAndPerformActionResults[.search] = false
        
        // When
        viewModel.selectedIngredients = ["chicken"]
        await viewModel.searchRecipes()
        
        // Then
        XCTAssertTrue(viewModel.recipes.isEmpty)
        XCTAssertTrue(viewModel.showingPaywall)
    }
}
```

### Integration Testing

```swift
// Test complete workflows
class RecipeSearchIntegrationTests: XCTestCase {
    func testCompleteSearchAndSaveFlow() async {
        // This tests the entire flow from search to save
        let authService = MockAuthenticationService()
        let usageService = MockUsageService()
        let repository = MockRecipeRepository()
        
        // Set up test scenario
        authService.setCurrentUser(TestFixtures.freeUser)
        usageService.searchesRemaining = 5
        repository.setSearchResults([TestFixtures.sampleRecipe])
        
        let viewModel = RecipeSearchViewModel(
            repository: repository,
            usageService: usageService
        )
        
        // Perform search
        viewModel.selectedIngredients = ["chicken"]
        await viewModel.searchRecipes()
        
        XCTAssertEqual(viewModel.recipes.count, 1)
        
        // Save recipe
        let recipeId = viewModel.recipes[0].id
        await viewModel.toggleSaveRecipe(recipeId)
        
        XCTAssertTrue(viewModel.savedRecipeIds.contains(recipeId))
    }
}
```

### UI Testing

```swift
// Test user interactions
class RecipeSearchUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUp() {
        app = XCUIApplication()
        app.launchEnvironment["TESTING"] = "1"
        app.launch()
    }
    
    func testSearchFlow() {
        // Navigate to search
        app.tabBars.buttons["Search"].tap()
        
        // Add ingredient
        let ingredientField = app.textFields["Add ingredient"]
        ingredientField.tap()
        ingredientField.typeText("chicken")
        app.buttons["Add"].tap()
        
        // Verify ingredient chip appears
        XCTAssertTrue(app.staticTexts["chicken"].exists)
        
        // Wait for search results
        let recipeCell = app.cells.firstMatch
        XCTAssertTrue(recipeCell.waitForExistence(timeout: 10))
        
        // Test save functionality
        let saveButton = recipeCell.buttons["Save Recipe"]
        saveButton.tap()
        
        // Verify saved state
        XCTAssertTrue(app.images["heart.fill"].exists)
    }
}
```

## 🚀 Performance Optimization

### Memory Management

```swift
// Use weak references to avoid retain cycles
class RecipeDetailViewModel: ObservableObject {
    private weak var navigationController: UINavigationController?
    private let repository: RecipeRepositoryProtocol
    
    // Use @Published sparingly - only for UI-bound properties
    @Published var recipe: Recipe?
    @Published var isLoading = false
    
    // Internal state doesn't need @Published
    private var ingredients: [String] = []
    private var cachedImages: [String: UIImage] = [:]
}

// Properly manage async tasks
class RecipeSearchViewModel: ObservableObject {
    private var searchTask: Task<Void, Never>?
    
    func searchRecipes() async {
        // Cancel previous search
        searchTask?.cancel()
        
        searchTask = Task {
            // Perform search
            do {
                let results = try await repository.search(...)
                
                // Check if task was cancelled
                guard !Task.isCancelled else { return }
                
                await MainActor.run {
                    self.recipes = results
                }
            } catch {
                // Handle error
            }
        }
    }
    
    deinit {
        searchTask?.cancel()
    }
}
```

### Network Optimization

```swift
// Implement caching for frequently accessed data
class RecipeRepository {
    private let cache = NSCache<NSString, RecipeData>()
    
    func getRecipe(id: UUID) async throws -> Recipe {
        let cacheKey = NSString(string: id.uuidString)
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey) {
            return cached.recipe
        }
        
        // Fetch from network
        let recipe = try await fetchRecipeFromNetwork(id: id)
        
        // Cache result
        let cacheData = RecipeData(recipe: recipe, timestamp: Date())
        cache.setObject(cacheData, forKey: cacheKey)
        
        return recipe
    }
}

// Batch API calls when possible
func loadInitialData() async {
    async let usageStats = usageService.refreshUsageStats()
    async let savedRecipes = repository.getSavedRecipeIds()
    async let userProfile = profileService.loadProfile()
    
    // Wait for all to complete
    await (usageStats, savedRecipes, userProfile)
}
```

## 🔄 State Management Patterns

### Reactive Updates

```swift
// Services publish changes automatically
@MainActor
final class UsageService: ObservableObject {
    @Published var searchesRemaining: Int = 5
    
    func performSearch() async {
        // Update occurs automatically
        searchesRemaining -= 1
        
        // All UI observing this service updates instantly
    }
}

// ViewModels react to service changes
@MainActor
final class RecipeSearchViewModel: ObservableObject {
    @Published var canSearch: Bool = true
    
    private let usageService: UsageService
    private var cancellables = Set<AnyCancellable>()
    
    init(usageService: UsageService) {
        self.usageService = usageService
        
        // React to usage changes
        usageService.$searchesRemaining
            .map { $0 > 0 }
            .assign(to: &$canSearch)
    }
}
```

### Complex State Coordination

```swift
// Coordinate multiple services for complex features
@MainActor
final class AppStateManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var hasActiveSubscription = false
    @Published var canUseAdvancedFeatures = false
    
    private let authService: AuthenticationService
    private let subscriptionService: SubscriptionService
    private var cancellables = Set<AnyCancellable>()
    
    init(authService: AuthenticationService, subscriptionService: SubscriptionService) {
        self.authService = authService
        self.subscriptionService = subscriptionService
        
        // Combine multiple publishers
        Publishers.CombineLatest(
            authService.$isAuthenticated,
            subscriptionService.$hasActiveSubscription
        )
        .map { isAuth, hasSub in
            return isAuth && hasSub
        }
        .assign(to: &$canUseAdvancedFeatures)
    }
}
```

## 🐛 Debugging Techniques

### Logging Strategy

```swift
import os.log

extension Logger {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let viewCycle = Logger(subsystem: subsystem, category: "viewcycle")
    static let network = Logger(subsystem: subsystem, category: "network")
    static let usage = Logger(subsystem: subsystem, category: "usage")
    static let auth = Logger(subsystem: subsystem, category: "auth")
}

// Use throughout the app
func searchRecipes() async {
    Logger.usage.info("Starting recipe search with \(selectedIngredients.count) ingredients")
    
    do {
        let recipes = try await repository.search(...)
        Logger.usage.info("Search completed with \(recipes.count) results")
    } catch {
        Logger.usage.error("Search failed: \(error.localizedDescription)")
    }
}
```

### Debug Builds

```swift
#if DEBUG
extension RecipeSearchViewModel {
    // Debug helpers only available in debug builds
    func debugInfo() -> String {
        return """
        Current State:
        - Recipes: \(recipes.count)
        - Loading: \(isLoading)
        - Error: \(errorMessage ?? "none")
        - Ingredients: \(selectedIngredients.joined(separator: ", "))
        """
    }
}

// Debug-only views
struct DebugOverlay: View {
    @ObservedObject var viewModel: RecipeSearchViewModel
    @State private var showDebug = false
    
    var body: some View {
        VStack {
            if showDebug {
                Text(viewModel.debugInfo())
                    .font(.caption)
                    .background(Color.black.opacity(0.8))
                    .foregroundColor(.green)
            }
        }
        .onTapGesture(count: 3) {
            showDebug.toggle()
        }
    }
}
#endif
```

### Performance Profiling

```swift
// Measure operation performance
func measureOperation<T>(
    _ operation: () async throws -> T,
    name: String = #function
) async rethrows -> T {
    let startTime = CFAbsoluteTimeGetCurrent()
    let result = try await operation()
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    
    Logger.performance.info("\(name) took \(timeElapsed) seconds")
    return result
}

// Use in critical operations
func searchRecipes() async {
    recipes = await measureOperation(name: "Recipe Search") {
        try await repository.searchByIngredients(selectedIngredients)
    }
}
```

## 📦 Dependency Management

### Service Registration

```swift
// Dependency container for testability
protocol DependencyContainer {
    var authService: AuthenticationServiceProtocol { get }
    var usageService: UsageServiceProtocol { get }
    var repository: RecipeRepositoryProtocol { get }
}

// Production container
class ProductionContainer: DependencyContainer {
    lazy var authService: AuthenticationServiceProtocol = AuthenticationService.shared
    lazy var usageService: UsageServiceProtocol = UsageService.shared
    lazy var repository: RecipeRepositoryProtocol = RecipeRepository()
}

// Test container
class TestContainer: DependencyContainer {
    var authService: AuthenticationServiceProtocol = MockAuthenticationService()
    var usageService: UsageServiceProtocol = MockUsageService()
    var repository: RecipeRepositoryProtocol = MockRecipeRepository()
}

// Use in app
@main
struct LeftovaApp: App {
    let container: DependencyContainer = ProductionContainer()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container.authService as! AuthenticationService)
                .environmentObject(container.usageService as! UsageService)
        }
    }
}
```

## 🔧 Build Configuration

### Environment-Specific Settings

```swift
// Build configuration detection
enum BuildEnvironment {
    case debug, testflight, appstore
    
    static var current: BuildEnvironment {
        #if DEBUG
        return .debug
        #elseif TESTFLIGHT
        return .testflight
        #else
        return .appstore
        #endif
    }
}

// Environment-specific behavior
extension Config {
    static var apiBaseURL: String {
        switch BuildEnvironment.current {
        case .debug:
            return "https://staging-api.leftova.com"
        case .testflight:
            return "https://beta-api.leftova.com"
        case .appstore:
            return "https://api.leftova.com"
        }
    }
    
    static var logLevel: LogLevel {
        BuildEnvironment.current == .debug ? .verbose : .error
    }
}
```

### Feature Flags

```swift
// Feature toggles for gradual rollout
enum FeatureFlags {
    static var enableNewSearchUI: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: "feature_new_search_ui")
        #endif
    }
    
    static var enableAdvancedFilters: Bool {
        Config.FreeTier.canUseAdvancedSearch || 
        RemoteConfig.shared.bool(forKey: "advanced_filters_enabled")
    }
}

// Use in views
struct RecipeSearchView: View {
    var body: some View {
        VStack {
            if FeatureFlags.enableNewSearchUI {
                NewSearchInterface()
            } else {
                LegacySearchInterface()
            }
        }
    }
}
```

---

This developer guide provides comprehensive coverage of development patterns, best practices, and implementation details for working on the Leftova iOS app. It serves as both a reference for experienced developers and a learning resource for those new to the codebase.