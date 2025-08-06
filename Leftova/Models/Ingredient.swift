import Foundation

// MARK: - Ingredient Model
struct Ingredient: Codable, Identifiable, Equatable {
    let id: UUID
    let recipeId: UUID
    let name: String
    let amount: Double?
    let unit: String?
    
    // Computed properties for display
    var displayAmount: String {
        guard let amount = amount else { return "" }
        
        // Handle common fractions
        if amount == 0.25 {
            return "¼"
        } else if amount == 0.33 {
            return "⅓"
        } else if amount == 0.5 {
            return "½"
        } else if amount == 0.66 {
            return "⅔"
        } else if amount == 0.75 {
            return "¾"
        } else if amount.truncatingRemainder(dividingBy: 1) == 0 {
            // Whole number
            return String(format: "%.0f", amount)
        } else {
            // Decimal with up to 2 places
            return String(format: "%.2f", amount).trimmingCharacters(in: CharacterSet(charactersIn: "0")).trimmingCharacters(in: CharacterSet(charactersIn: "."))
        }
    }
    
    var displayText: String {
        var parts: [String] = []
        
        if !displayAmount.isEmpty {
            parts.append(displayAmount)
        }
        
        if let unit = unit, !unit.isEmpty {
            parts.append(unit)
        }
        
        parts.append(name)
        
        return parts.joined(separator: " ")
    }
    
    // For search normalization
    var normalizedName: String {
        return name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case name
        case amount
        case unit
    }
}

// MARK: - Ingredient Categories
enum IngredientCategory: String, CaseIterable {
    case protein = "Protein"
    case dairy = "Dairy"
    case grains = "Grains"
    case vegetables = "Vegetables"
    case fruits = "Fruits"
    case spices = "Spices & Herbs"
    case condiments = "Condiments"
    case oils = "Oils & Fats"
    case other = "Other"
    
    // Helper to categorize ingredients
    static func category(for ingredientName: String) -> IngredientCategory {
        let lowercased = ingredientName.lowercased()
        
        // Proteins
        if ["chicken", "beef", "pork", "fish", "salmon", "tuna", "shrimp", "turkey", "bacon", "sausage", "egg", "tofu", "beans", "lentils"].contains(where: lowercased.contains) {
            return .protein
        }
        
        // Dairy
        if ["milk", "cheese", "yogurt", "cream", "butter", "sour cream", "cottage cheese", "mozzarella", "cheddar", "parmesan"].contains(where: lowercased.contains) {
            return .dairy
        }
        
        // Grains
        if ["rice", "pasta", "bread", "flour", "oats", "quinoa", "barley", "noodles", "couscous", "breadcrumbs"].contains(where: lowercased.contains) {
            return .grains
        }
        
        // Vegetables
        if ["onion", "garlic", "tomato", "potato", "carrot", "celery", "pepper", "broccoli", "spinach", "lettuce", "cucumber", "mushroom", "corn", "peas", "beans", "zucchini", "cauliflower", "cabbage", "kale"].contains(where: lowercased.contains) {
            return .vegetables
        }
        
        // Fruits
        if ["apple", "banana", "orange", "lemon", "lime", "berry", "strawberry", "grape", "pineapple", "mango", "peach", "pear", "avocado", "cherry", "melon"].contains(where: lowercased.contains) {
            return .fruits
        }
        
        // Spices & Herbs
        if ["salt", "pepper", "oregano", "basil", "thyme", "rosemary", "sage", "paprika", "cumin", "coriander", "cinnamon", "nutmeg", "ginger", "turmeric", "cayenne", "chili", "parsley", "cilantro", "dill", "mint"].contains(where: lowercased.contains) {
            return .spices
        }
        
        // Condiments
        if ["ketchup", "mustard", "mayonnaise", "sauce", "vinegar", "soy sauce", "hot sauce", "worcestershire", "honey", "jam", "syrup", "dressing"].contains(where: lowercased.contains) {
            return .condiments
        }
        
        // Oils
        if ["oil", "olive oil", "vegetable oil", "coconut oil", "sesame oil", "shortening", "lard"].contains(where: lowercased.contains) {
            return .oils
        }
        
        return .other
    }
}

// MARK: - Common Units
enum IngredientUnit: String, CaseIterable {
    case teaspoon = "tsp"
    case tablespoon = "tbsp"
    case cup = "cup"
    case ounce = "oz"
    case pound = "lb"
    case gram = "g"
    case kilogram = "kg"
    case milliliter = "ml"
    case liter = "L"
    case piece = "piece"
    case slice = "slice"
    case pinch = "pinch"
    case dash = "dash"
    case clove = "clove"
    case can = "can"
    case package = "package"
    case bunch = "bunch"
    
    var plural: String {
        switch self {
        case .teaspoon: return "tsps"
        case .tablespoon: return "tbsps"
        case .cup: return "cups"
        case .ounce: return "oz"
        case .pound: return "lbs"
        case .gram: return "g"
        case .kilogram: return "kg"
        case .milliliter: return "ml"
        case .liter: return "L"
        case .piece: return "pieces"
        case .slice: return "slices"
        case .pinch: return "pinches"
        case .dash: return "dashes"
        case .clove: return "cloves"
        case .can: return "cans"
        case .package: return "packages"
        case .bunch: return "bunches"
        }
    }
    
    // Convert between units (basic conversions)
    func toTeaspoons() -> Double? {
        switch self {
        case .teaspoon: return 1
        case .tablespoon: return 3
        case .cup: return 48
        case .milliliter: return 0.202884
        case .liter: return 202.884
        default: return nil
        }
    }
}

// MARK: - Ingredient Extensions
extension Ingredient {
    // Create a display-friendly ingredient from user input
    static func parse(from input: String) -> (name: String, amount: Double?, unit: String?) {
        let components = input.split(separator: " ", maxSplits: 2)
        
        guard components.count >= 1 else {
            return (name: input, amount: nil, unit: nil)
        }
        
        // Try to parse amount from first component
        if let amount = Double(components[0]) {
            if components.count == 1 {
                return (name: input, amount: nil, unit: nil)
            } else if components.count == 2 {
                return (name: String(components[1]), amount: amount, unit: nil)
            } else {
                // Check if second component is a unit
                let possibleUnit = String(components[1]).lowercased()
                if IngredientUnit.allCases.contains(where: { $0.rawValue == possibleUnit || $0.plural == possibleUnit }) {
                    return (name: String(components[2]), amount: amount, unit: String(components[1]))
                } else {
                    return (name: components[1...].joined(separator: " "), amount: amount, unit: nil)
                }
            }
        }
        
        return (name: input, amount: nil, unit: nil)
    }
}

// MARK: - Array Extensions
extension Array where Element == Ingredient {
    // Group ingredients by category
    func groupedByCategory() -> [IngredientCategory: [Ingredient]] {
        return Dictionary(grouping: self) { ingredient in
            IngredientCategory.category(for: ingredient.name)
        }
    }
    
    // Get unique ingredient names (for search)
    var uniqueNames: [String] {
        let names: [String] = self.map { ingredient in
            ingredient.normalizedName
        }
        let uniqueSet = Set(names)
        return uniqueSet.sorted()
    }
    
    // Filter ingredients by search query
    func filtered(by searchText: String) -> [Ingredient] {
        guard !searchText.isEmpty else { return self }
        
        let lowercasedSearch = searchText.lowercased()
        return self.filter { ingredient in
            ingredient.normalizedName.contains(lowercasedSearch)
        }
    }
}
