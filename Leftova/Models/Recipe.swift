import Foundation

struct Recipe: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String?
    let sourceUrl: String?
    let sourceName: String?
    let imageUrl: String?
    let servings: Int?
    let prepTime: Int?
    let cookTime: Int?
    let difficulty: String?
    let cuisine: String?
    let nutrition: Nutrition?
    let createdAt: Date?
    let updatedAt: Date?
    
    // For search results
    var matchCount: Int?
    var totalIngredients: Int?
    
    // Handle instructions as JSON string
    private let instructionsJson: String?  // Keep the original name for the raw JSON
    
    // Parsed instructions - this is what the views use
    var instructions: [Instruction]? {
        guard let instructionsJson = instructionsJson else { return nil }
        guard let data = instructionsJson.data(using: .utf8) else { return nil }
        
        do {
            return try JSONDecoder().decode([Instruction].self, from: data)
        } catch {
            print("Failed to parse instructions: \(error)")
            return nil
        }
    }
    
    // Computed property to get instructions as string array
    var instructionsArray: [String] {
        guard let instructions = instructions else { return [] }
        return instructions
            .sorted { $0.step < $1.step }
            .map { $0.text }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
        case sourceUrl = "source_url"
        case sourceName = "source_name"
        case imageUrl = "image_url"
        case servings
        case prepTime = "prep_time"
        case cookTime = "cook_time"
        case difficulty, cuisine, nutrition
        case instructionsJson = "instructions"  // Map "instructions" from DB to instructionsJson
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case matchCount = "match_count"
        case totalIngredients = "total_ingredients"
    }
}
