# Leftova - Recipe Discovery iOS App

<div align="center">
  <img src="https://img.shields.io/badge/iOS-17.0+-blue.svg" alt="iOS Version">
  <img src="https://img.shields.io/badge/Swift-5.9+-orange.svg" alt="Swift Version">
  <img src="https://img.shields.io/badge/Xcode-15.0+-blue.svg" alt="Xcode Version">
  <img src="https://img.shields.io/badge/License-MIT-green.svg" alt="License">
</div>

## 🍽️ Overview

Leftova is a SwiftUI-based recipe discovery app that helps users find recipes based on ingredients they have available. The app features a freemium model with usage-based limits, subscription tiers, and integration with Supabase for backend services.

### Key Features
- **Ingredient-based recipe search** - Find recipes using ingredients you have at home
- **Text-based recipe search** - Search recipes by name or description
- **Recipe saving and management** - Build your personal cookbook
- **Usage tracking and limits** - Freemium model with daily limits
- **Premium subscriptions** - Unlimited access with StoreKit 2
- **Real-time usage monitoring** - Live updates on remaining searches and saves
- **Clean, modern UI** - SwiftUI with native iOS design patterns

## 🏗️ Architecture

Leftova follows **Clean Architecture** principles with a modern SwiftUI + MVVM pattern:

```
Leftova/
├── Core/                           # Core business logic
│   ├── Services/                   # Business services
│   └── Repositories/               # Data access layer
├── Features/                       # Feature modules
│   └── RecipeSearch/              # Search feature
├── Views/                         # SwiftUI views
│   └── components/                # Reusable UI components
├── ViewModels/                    # View models (MVVM)
├── Models/                        # Data models
├── Config/                        # Configuration (gitignored)
└── Documentation/                 # Project documentation
```

### Design Patterns
- **MVVM (Model-View-ViewModel)** - Clean separation of concerns
- **Repository Pattern** - Abstracted data access
- **Protocol-Oriented Programming** - Testable, injectable dependencies
- **Reactive Programming** - `@Published` properties for real-time UI updates
- **Singleton Pattern** - Shared services (UsageService, AuthenticationService)

## 🚀 Quick Start

### Prerequisites
- **Xcode 15.0+**
- **iOS 17.0+** deployment target
- **Supabase account** with configured project
- **Apple Developer account** (for StoreKit testing)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Leftova-App
   ```

2. **Set up configuration**
   ```bash
   # Run setup script
   ./setup.sh
   
   # Or manually:
   cp Leftova/Config/Config.template.swift Leftova/Config/Config.swift
   ```

3. **Configure Supabase credentials**
   Edit `Leftova/Config/Config.swift`:
   ```swift
   enum Config {
       static let supabaseURL = "YOUR_SUPABASE_PROJECT_URL"
       static let supabaseAnonKey = "YOUR_SUPABASE_ANON_KEY"
       // ...
   }
   ```

4. **Open in Xcode**
   ```bash
   open Leftova.xcodeproj
   ```

5. **Build and run**
   - Select target device/simulator
   - Press `⌘R` to build and run

## 📱 App Features

### Core Functionality

#### Recipe Search
- **Single ingredient search** - Available for free users
- **Multi-ingredient search** - Premium feature
- **Text-based search** - Search by recipe name or description
- **Smart filtering** - Results based on ingredient matching
- **Usage limits** - 5 searches per day for free users

#### Recipe Management
- **Save recipes** - Build personal cookbook (20 recipes for free)
- **Recipe details** - Full instructions, nutrition, and metadata
- **Real-time sync** - Instant updates across app
- **Usage tracking** - Live monitoring of saved recipe count

#### User Authentication
- **Email/password signup** - Supabase Auth integration
- **Secure session management** - JWT-based authentication
- **Password reset** - Email-based password recovery
- **User profiles** - Account management and statistics

#### Premium Features
- **Unlimited searches** - No daily limits
- **Unlimited saved recipes** - Build extensive cookbook
- **Multi-ingredient search** - Search with multiple ingredients
- **Priority support** - Enhanced customer service
- **7-day free trial** - Full premium access

### Subscription Model

#### Free Tier
- ✅ 5 searches per day
- ✅ 20 saved recipes
- ✅ Single ingredient search
- ✅ Basic recipe details
- ❌ Multi-ingredient search
- ❌ Unlimited usage

#### Premium Tier
- ✅ Unlimited searches
- ✅ Unlimited saved recipes
- ✅ Multi-ingredient search
- ✅ Advanced filtering
- ✅ Priority support
- ✅ Early feature access

**Pricing**: $4.99/month or $39.99/year (33% discount)

## 🛠️ Technical Implementation

### Backend Integration

#### Supabase Services
```swift
// Authentication
AuthenticationService.shared.signIn(email: email, password: password)

// Usage tracking with RPC functions
let result = await usageService.checkAndPerformAction(.search)

// Recipe data with Row Level Security
let recipes = try await repository.searchByIngredients(ingredients)
```

#### Database Schema
- **users** - User profiles and authentication
- **recipes** - Recipe data with full-text search
- **saved_recipes** - User's saved recipes (RLS protected)
- **usage_stats** - Daily usage tracking per user

### State Management

#### ObservableObject Pattern
```swift
@MainActor
final class RecipeSearchViewModel: ObservableObject {
    @Published var recipes: [Recipe] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Clean dependency injection
    private let repository: RecipeRepositoryProtocol
    private let usageService: UsageServiceProtocol
}
```

#### Real-time Updates
- `@Published` properties for reactive UI
- `@StateObject` for view model lifecycle
- `@ObservedObject` for shared state
- Combine framework for data flow

### Usage Tracking System

#### Architecture
```
User Action → UsageService → Supabase RPC → Database → UI Update
```

#### Implementation
```swift
// Check limits before action
let allowed = await usageService.checkAndPerformAction(.search)

// Server-side validation with RPC
CREATE OR REPLACE FUNCTION check_and_record_usage(
  p_user_id TEXT,
  p_action_type TEXT,
  p_metadata JSONB DEFAULT '{}'
) RETURNS JSONB
```

#### Features
- **Server-side validation** - Prevents client-side bypassing
- **Real-time updates** - Immediate UI reflection
- **Configurable limits** - Easy adjustment via Config.swift
- **Usage analytics** - Track user behavior patterns

### Security Implementation

#### Data Protection
- **Row Level Security (RLS)** - Database-level access control
- **JWT authentication** - Secure session management
- **API key protection** - Config.swift gitignored
- **Input validation** - Client and server-side validation

#### Best Practices
```swift
// RLS Policy Example
CREATE POLICY "Users can view own saved recipes" 
ON saved_recipes FOR SELECT 
USING (auth.uid() = user_id);
```

### Testing Strategy

#### Test Coverage
- **Unit Tests** - Business logic and view models
- **Integration Tests** - Component interactions
- **UI Tests** - User interface and navigation
- **Performance Tests** - App performance benchmarks

#### Test Structure
```
LeftovaTests/
├── TestHelpers/           # Mock services and utilities
├── Unit/                  # Unit tests for components
├── Integration/           # End-to-end test scenarios
└── Performance/           # Performance benchmarks
```

#### Mock Services
```swift
class MockUsageService: UsageServiceProtocol {
    var searchesRemaining = 5
    var canUseAdvancedSearch = false
    
    func checkAndPerformAction(_ action: UserAction) async -> Bool {
        // Test-controlled behavior
    }
}
```

## 🎨 User Interface

### Design System

#### SwiftUI Components
- **Native iOS styling** - System colors and typography
- **Adaptive layouts** - iPhone and iPad support
- **Dark mode support** - Automatic theme switching
- **Accessibility** - VoiceOver and Dynamic Type support

#### Custom Components
```swift
// Usage limit banner with real-time updates
UsageLimitBanner() // Shows remaining searches/saves

// Smart input components with built-in limits
IngredientInputViewWithLimits(ingredients: $ingredients)
SearchBarWithLimits { query in /* handle search */ }

// Recipe display with save/unsave functionality
RecipeCard(recipe: recipe, isSaved: isSaved) { /* toggle save */ }
```

#### Navigation Structure
```
TabView
├── RecipeSearchView        # Main search interface
├── SavedRecipesView       # Personal cookbook
└── ProfileView            # Account and settings
```

### User Experience

#### Onboarding Flow
1. **App launch** → Authentication required
2. **Sign up/Sign in** → 7-day premium trial starts
3. **First search** → Usage tracking begins
4. **Trial expires** → Convert to free tier

#### Limit Enforcement
- **Proactive warnings** - Show remaining usage
- **Graceful degradation** - Disable features when limits reached
- **Clear upgrade path** - Prominent but not intrusive calls-to-action
- **Real-time feedback** - Immediate UI updates after actions

#### Error Handling
```swift
// User-friendly error messages
catch let error as LimitError {
    errorMessage = "You've reached your daily search limit. Upgrade for unlimited searches!"
}

// Graceful fallbacks
guard let userId = authService.currentUserId else {
    // Handle unauthenticated state
    return
}
```

## 🔧 Configuration

### Environment Setup

#### Development Configuration
```swift
// Leftova/Config/Config.swift (gitignored)
enum Config {
    // Supabase credentials
    static let supabaseURL = "https://your-project.supabase.co"
    static let supabaseAnonKey = "your-anon-key"
    
    // StoreKit products
    struct StoreKit {
        static let monthlySubscriptionID = "com.leftova.premium.monthly"
        static let annualSubscriptionID = "com.leftova.premium.annual"
    }
    
    // Free tier limits (easily adjustable)
    struct FreeTier {
        static let dailySearchLimit = 5
        static let savedRecipesLimit = 20
        static let canUseAdvancedSearch = false
        static let trialDurationDays = 7
    }
}
```

#### Build Configurations
- **Debug** - Development with logging
- **Release** - Production optimized
- **Testing** - Unit test configuration

### Feature Flags
```swift
// Easy feature toggling
struct FreeTier {
    static let canUseAdvancedSearch = false  // Disable multi-ingredient for free
    static let showUsageBanner = true       // Control banner visibility
    static let trialDurationDays = 7        // Adjust trial length
}
```

## 📊 Analytics & Monitoring

### Usage Metrics
- **Search patterns** - Popular ingredients and queries
- **Conversion rates** - Free to premium upgrade rates
- **User retention** - Daily, weekly, monthly active users
- **Feature usage** - Most used app features

### Performance Monitoring
- **App launch time** - Cold and warm start performance
- **Search latency** - Response time for recipe queries
- **Memory usage** - Efficient resource management
- **Network requests** - API call optimization

### Error Tracking
```swift
// Comprehensive error logging
do {
    let recipes = try await repository.searchByIngredients(ingredients)
} catch {
    print("Search failed: \(error)")
    // Log to analytics service
    Analytics.track("search_failed", parameters: ["error": error.localizedDescription])
}
```

## 🧪 Testing

### Running Tests

#### Unit Tests
```bash
# Command line
xcodebuild test -scheme Leftova -destination 'platform=iOS Simulator,name=iPhone 15'

# Xcode IDE
⌘U (Test All) or ⌘⌥U (Test Without Building)
```

#### UI Tests
```bash
# Command line
xcodebuild test -scheme Leftova -only-testing:LeftovaUITests

# Xcode IDE
Navigate to Test Navigator (⌘6) → Run UI Tests
```

### Test Categories

#### Unit Tests (LeftovaTests/)
- **RecipeSearchViewModelTests** - Search functionality
- **UsageServiceTests** - Usage tracking and limits
- **AuthenticationServiceTests** - User authentication
- **ConfigTests** - Configuration validation

#### Integration Tests
- **RecipeSearchIntegrationTests** - End-to-end search flows
- **UsageIntegrationTests** - Complete usage scenarios
- **AuthenticationFlowTests** - Sign up/in/out flows

#### UI Tests (LeftovaUITests/)
- **RecipeSearchUITests** - Search interface testing
- **NavigationTests** - App navigation flows
- **PaywallTests** - Subscription interface testing

#### Performance Tests
```swift
func test_searchPerformance() {
    measure(metrics: [XCTClockMetric()]) {
        // Performance benchmark
        await viewModel.searchRecipes()
    }
}
```

### Test Data Management
```swift
// Consistent test fixtures
struct TestFixtures {
    static let freeUser = AuthUser(id: "test-free-user", email: "free@test.com")
    static let sampleRecipe = Recipe(title: "Test Recipe", description: "...")
    static let freeUserUsageStats = UsageStats(tier: "free", searchesToday: 3)
}

// Builder pattern for flexible test data
let recipe = RecipeBuilder()
    .withTitle("Custom Recipe")
    .withServings(4)
    .withDifficulty("Easy")
    .build()
```

## 🚀 Deployment

### App Store Release

#### Pre-release Checklist
- [ ] All tests pass (unit, integration, UI, performance)
- [ ] Security audit completed
- [ ] Configuration verified for production
- [ ] StoreKit products configured
- [ ] App Store metadata updated
- [ ] Screenshots and marketing materials ready

#### Build Process
1. **Version bump** - Update CFBundleVersion and CFBundleShortVersionString
2. **Production build** - Archive with Release configuration
3. **Code signing** - Valid distribution certificate
4. **Upload to App Store Connect** - Via Xcode or Transporter
5. **TestFlight testing** - Internal and external testing
6. **App Store review** - Submit for review

#### Release Management
```swift
// Version management
struct AppVersion {
    static let current = "1.0.0"
    static let minimumSupported = "1.0.0"
    
    // Feature flags for gradual rollout
    static let newFeatureEnabled = true
}
```

### CI/CD Pipeline

#### GitHub Actions Example
```yaml
name: iOS Build and Test
on: [push, pull_request]
jobs:
  test:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v2
    - name: Build and Test
      run: |
        xcodebuild clean test \
          -scheme Leftova \
          -destination 'platform=iOS Simulator,name=iPhone 15' \
          CODE_SIGNING_REQUIRED=NO
```

## 🔒 Security

### Data Protection
- **Encryption at rest** - Supabase database encryption
- **Encryption in transit** - HTTPS/TLS for all API calls
- **Secure credential storage** - iOS Keychain for sensitive data
- **Row Level Security** - Database-level access control

### Privacy Compliance
- **GDPR compliance** - User data rights and deletion
- **Privacy policy** - Clear data usage disclosure
- **Minimal data collection** - Only necessary user information
- **Opt-in analytics** - User consent for data tracking

### Security Best Practices
```swift
// Secure configuration management
enum Config {
    // ❌ DON'T: Hard-code sensitive values
    static let apiKey = "hardcoded-secret"
    
    // ✅ DO: Use environment or secure storage
    static let apiKey = ProcessInfo.processInfo.environment["API_KEY"] ?? ""
}

// Input validation
func validateEmail(_ email: String) -> Bool {
    let emailRegex = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
    return email.range(of: emailRegex, options: .regularExpression, range: nil, locale: nil) != nil
}
```

## 🤝 Contributing

### Development Setup
1. **Fork the repository**
2. **Clone your fork**
3. **Run setup script** - `./setup.sh`
4. **Create feature branch** - `git checkout -b feature/amazing-feature`
5. **Make changes and test**
6. **Commit with descriptive messages**
7. **Push and create Pull Request**

### Code Standards
- **Swift Style Guide** - Follow Apple's Swift API Design Guidelines
- **SwiftLint** - Automated code style enforcement
- **Documentation** - Comprehensive inline documentation
- **Testing** - Minimum 80% code coverage for new features

### Pull Request Process
1. **Update documentation** - README, code comments, changelog
2. **Add tests** - Unit, integration, and UI tests as appropriate
3. **Verify security** - No exposed credentials or vulnerabilities
4. **Performance check** - No significant performance regressions
5. **Review approval** - At least one maintainer approval required

## 📚 API Documentation

### Core Services

#### AuthenticationService
```swift
protocol AuthenticationServiceProtocol {
    /// Current authenticated user
    var currentUser: AuthUser? { get }
    
    /// Sign up new user with email/password
    func signUp(email: String, password: String) async throws -> AuthUser
    
    /// Sign in existing user
    func signIn(email: String, password: String) async throws -> AuthUser
    
    /// Sign out current user
    func signOut() async throws
    
    /// Send password reset email
    func resetPassword(email: String) async throws
}
```

#### UsageService
```swift
protocol UsageServiceProtocol {
    /// Remaining searches for current user
    var searchesRemaining: Int { get }
    
    /// Check if action is allowed and perform it
    func checkAndPerformAction(_ action: UserAction) async -> Bool
    
    /// Refresh usage statistics from server
    func refreshUsageStats() async
    
    /// Get formatted limit message for UI display
    func formattedLimitMessage(for action: UserAction) -> String
}
```

#### RecipeRepository
```swift
protocol RecipeRepositoryProtocol {
    /// Search recipes by ingredients with usage limits
    func searchByIngredientsWithLimit(_ ingredients: [String]) async throws -> [Recipe]
    
    /// Search recipes by text with usage limits
    func searchByTextWithLimit(_ query: String) async throws -> [Recipe]
    
    /// Save recipe with limit enforcement
    func saveRecipeWithLimit(_ recipeId: UUID) async throws
    
    /// Get user's saved recipes
    func getSavedRecipes() async throws -> [Recipe]
}
```

### Data Models

#### Recipe Model
```swift
struct Recipe: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let ingredients: [String]
    let instructions: [Instruction]
    let nutrition: Nutrition?
    let servings: Int?
    let prepTime: Int?     // Minutes
    let cookTime: Int?     // Minutes
    let difficulty: String? // "Easy", "Medium", "Hard"
    let cuisine: String?
    let imageUrl: String?
    
    // Search-specific properties
    var matchCount: Int?      // Ingredients matched in search
    var totalIngredients: Int? // Total ingredients in recipe
}
```

#### UsageStats Model
```swift
struct UsageStats: Codable {
    let tier: String              // "free" or "premium"
    let searchesToday: Int        // Searches performed today
    let searchesLimit: Int        // Daily search limit
    let savedRecipes: Int         // Currently saved recipes
    let savedRecipesLimit: Int    // Maximum saved recipes
    let multiIngredientSearchesToday: Int
    let multiIngredientLimit: Int
    
    // Computed properties
    var searchesRemaining: Int { max(0, searchesLimit - searchesToday) }
    var savedRecipesRemaining: Int { max(0, savedRecipesLimit - savedRecipes) }
}
```

## 📈 Roadmap

### Version 1.1 - Enhanced Search
- **Dietary filters** - Vegetarian, vegan, gluten-free options
- **Cuisine filters** - Filter by cuisine type
- **Cooking time filters** - Quick meals, slow cooking options
- **Difficulty filters** - Beginner, intermediate, expert
- **Nutritional search** - Find recipes by nutrition goals

### Version 1.2 - Social Features
- **Recipe sharing** - Share recipes with friends
- **Recipe reviews** - Rate and review recipes
- **Personal notes** - Add private notes to recipes
- **Cooking history** - Track previously made recipes
- **Recipe collections** - Organize recipes into collections

### Version 1.3 - Smart Features
- **Meal planning** - Weekly meal planning tool
- **Shopping lists** - Auto-generate grocery lists
- **Pantry management** - Track available ingredients
- **Recipe suggestions** - AI-powered recipe recommendations
- **Cooking timer integration** - Built-in cooking timers

### Version 2.0 - Platform Expansion
- **iPad optimization** - Enhanced tablet experience
- **macOS app** - Mac Catalyst version
- **Apple Watch** - Cooking timer and shopping list companion
- **Siri integration** - Voice-activated recipe search
- **Shortcuts support** - iOS Shortcuts integration

## 🆘 Troubleshooting

### Common Issues

#### Build Errors
**Config.swift not found**
```bash
# Solution: Copy template and configure
cp Leftova/Config/Config.template.swift Leftova/Config/Config.swift
# Edit Config.swift with your credentials
```

**Supabase connection failed**
```swift
// Check configuration in Config.swift
static let supabaseURL = "https://your-project.supabase.co"  // Correct format
static let supabaseAnonKey = "eyJ..."  // JWT format or sb_publishable_...
```

#### Runtime Errors
**Authentication failed**
- Verify Supabase project is active
- Check anon key permissions
- Confirm email/password format

**Search not working**
- Check RPC functions exist in Supabase
- Verify database permissions
- Check network connectivity

**Usage limits not updating**
- Ensure real-time subscriptions enabled
- Check RLS policies
- Verify user authentication

#### Performance Issues
**Slow search responses**
- Check database indexes
- Optimize RPC functions
- Reduce result set size

**High memory usage**
- Profile with Instruments
- Check for memory leaks
- Optimize image loading

### Debug Mode
```swift
#if DEBUG
    // Enable verbose logging
    print("🔍 Searching with ingredients: \(ingredients)")
    print("📊 Current usage: \(usageStats)")
    print("👤 Current user: \(currentUser?.email ?? "anonymous")")
#endif
```

### Support Contacts
- **GitHub Issues** - Bug reports and feature requests
- **Email Support** - Technical support for developers
- **Community Discord** - Developer community and discussions

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

<div align="center">
  <p>Built with ❤️ using SwiftUI and Supabase</p>
  <p>© 2024 Leftova. All rights reserved.</p>
</div>