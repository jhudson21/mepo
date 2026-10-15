import Foundation
import WidgetKit

nonisolated struct WidgetReminder: Codable, Identifiable, Sendable {
    var id: String
    var title: String
    var isCompleted: Bool
    var isImportant: Bool
    var dueText: String?
    var locationName: String?
}

nonisolated struct WidgetMemory: Codable, Identifiable, Sendable {
    var id: String
    var title: String
    var category: String
    var locationName: String?
    var ratingScore: Int?
    var ratingSubject: String?
    var details: String
    var dateText: String?
}

nonisolated struct WidgetPayload: Codable, Sendable {
    var reminders: [WidgetReminder]
    var latestMemory: WidgetMemory?
    var recentMemories: [WidgetMemory] = []
}

final class MepoWidgetStore {
    static let shared = MepoWidgetStore()
    static let appGroupID = "group.com.jordanhudsonpersonalteam.Mepo"
    
    private var defaults: UserDefaults? {
        UserDefaults(suiteName: Self.appGroupID) ?? UserDefaults.standard
    }
    
    private let payloadKey = "mepo_widget_payload"
    
    func save(reminders: [WidgetReminder], latestMemory: WidgetMemory?, recentMemories: [WidgetMemory] = []) {
        let payload = WidgetPayload(reminders: reminders, latestMemory: latestMemory, recentMemories: recentMemories)
        if let data = try? JSONEncoder().encode(payload) {
            defaults?.set(data, forKey: payloadKey)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    static let defaultMemories: [WidgetMemory] = [
        WidgetMemory(
            id: "m1",
            title: "Dinner at Circolo Popolare",
            category: "Food & Drink",
            locationName: "Fitzrovia, London",
            ratingScore: 5,
            ratingSubject: "Truffle Pasta",
            details: "Incredible atmosphere and decadent carbonara served in cheese wheel.",
            dateText: "Yesterday"
        ),
        WidgetMemory(
            id: "m2",
            title: "Flat White & Pastry",
            category: "Coffee & Cafes",
            locationName: "Monmouth Coffee, Covent Garden",
            ratingScore: 5,
            ratingSubject: "Espresso Roast",
            details: "Best pour-over and flat white in the city. Always busy.",
            dateText: "3 days ago"
        ),
        WidgetMemory(
            id: "m3",
            title: "Weekend Book Hunting",
            category: "Books & Arts",
            locationName: "Daunt Books, Marylebone",
            ratingScore: 4,
            ratingSubject: "Travel Section",
            details: "Beautiful oak galleries and skylights filled with travel literature.",
            dateText: "Last week"
        )
    ]
    
    func load() -> WidgetPayload {
        if let data = defaults?.data(forKey: payloadKey),
           let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data) {
            if payload.latestMemory != nil || !payload.recentMemories.isEmpty {
                return payload
            }
            return WidgetPayload(
                reminders: payload.reminders,
                latestMemory: Self.defaultMemories.first,
                recentMemories: Self.defaultMemories
            )
        }
        
        return WidgetPayload(
            reminders: [
                WidgetReminder(id: "1", title: "Pick up fresh coffee beans", isCompleted: false, isImportant: true, dueText: "Today 10:00 AM", locationName: "Monmouth Coffee"),
                WidgetReminder(id: "2", title: "Try seasonal sourdough pastry", isCompleted: false, isImportant: false, dueText: "Tomorrow", locationName: "Gail's Bakery"),
                WidgetReminder(id: "3", title: "Review weekend notes", isCompleted: true, isImportant: false, dueText: nil, locationName: nil)
            ],
            latestMemory: Self.defaultMemories.first,
            recentMemories: Self.defaultMemories
        )
    }
    
    func toggleReminder(id: String) {
        var payload = load()
        if let idx = payload.reminders.firstIndex(where: { $0.id == id }) {
            payload.reminders[idx].isCompleted.toggle()
            if let data = try? JSONEncoder().encode(payload) {
                defaults?.set(data, forKey: payloadKey)
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
    
    func resetToDefaults() {
        defaults?.removeObject(forKey: payloadKey)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
