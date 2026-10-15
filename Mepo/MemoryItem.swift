import Foundation
import SwiftData
import FoundationModels

@Model
class MemoryItem {
    var id: UUID = UUID()
    var title: String = ""
    var details: String = ""
    var category: String = "Notes"
    var locationName: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    
    @Attribute(.externalStorage)
    var photoData: Data? = nil
    var createdAt: Date = Date.now
    
    var ratings: [MemoryRating] = []
    
    init(id: UUID = UUID(), title: String = "", details: String = "", category: String = "Notes", locationName: String? = nil, latitude: Double? = nil, longitude: Double? = nil, photoData: Data? = nil, ratings: [MemoryRating] = [], createdAt: Date = .now) {
        self.id = id
        self.title = title
        self.details = details
        self.category = category
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.photoData = photoData
        self.ratings = ratings
        self.createdAt = createdAt
    }
    
    var shareFormattedText: String {
        var text = "\(title) (\(category))\n"
        if let loc = locationName {
            text += "📍 \(loc)\n"
        }
        if !details.isEmpty {
            text += "\n\(details)\n"
        }
        if !ratings.isEmpty {
            text += "\nRatings:\n"
            for r in ratings {
                let stars = String(repeating: "★", count: r.score) + String(repeating: "☆", count: 5 - r.score)
                text += "• \(r.subject): \(stars) (\(r.score)/5)\n"
            }
        }
        text += "\n— Captured with Mepo"
        return text
    }
}

// Struct for SwiftData nested array support (must be Codable)
struct MemoryRating: Codable, Hashable {
    var subject: String
    var score: Int
}

@Generable(description: "A memory entry extracted from user natural language")
struct ExtractedMemory {
    @Guide(description: "A short, readable title for this memory")
    var title: String
    
    @Guide(description: "Detailed information to remember, summarizing the experience")
    var details: String
    
    @Guide(description: "A category like 'Food & Drink', 'Travel', or 'Notes'")
    var category: String
    
    @Guide(description: "The name of the business, restaurant, or location if mentioned, including the city if available.")
    var locationName: String?
    
    @Guide(description: "Extract any mentioned scores, ratings, or verdicts out of 5 stars.")
    var ratings: [ExtractedRating]
}

@Generable(description: "A rating extracted from the text")
struct ExtractedRating {
    @Guide(description: "The subject being rated (e.g. 'Club Sandwich' or 'Fish and Chips')")
    var subject: String
    
    @Guide(description: "The numeric score out of 5")
    var score: Int
}
