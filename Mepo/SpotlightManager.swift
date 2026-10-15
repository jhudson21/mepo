import Foundation
import CoreSpotlight
import UniformTypeIdentifiers
import SwiftData

@MainActor
final class SpotlightManager {
    static let shared = SpotlightManager()
    
    static let memoryDomain = "com.jordanhudsonpersonalteam.Mepo.memories"
    static let reminderDomain = "com.jordanhudsonpersonalteam.Mepo.reminders"
    
    var selectedMemoryId: UUID? = nil
    var selectedReminderId: UUID? = nil
    
    private init() {}
    
    func indexMemory(_ memory: MemoryItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = memory.title
        attributeSet.contentDescription = memory.details.isEmpty ? memory.category : "\(memory.category) • \(memory.details)"
        attributeSet.keywords = [memory.category, "Memory", "Mepo", memory.title]
        
        if let locationName = memory.locationName {
            attributeSet.namedLocation = locationName
            attributeSet.keywords?.append(locationName)
        }
        
        if let lat = memory.latitude, let lon = memory.longitude {
            attributeSet.latitude = NSNumber(value: lat)
            attributeSet.longitude = NSNumber(value: lon)
        }
        
        if let photoData = memory.photoData {
            attributeSet.thumbnailData = photoData
        }
        
        attributeSet.contentCreationDate = memory.createdAt
        
        let item = CSSearchableItem(
            uniqueIdentifier: "memory-\(memory.id.uuidString)",
            domainIdentifier: Self.memoryDomain,
            attributeSet: attributeSet
        )
        
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error {
                print("Failed to index memory: \(error.localizedDescription)")
            }
        }
    }
    
    func indexMemories(_ memories: [MemoryItem]) {
        for memory in memories {
            indexMemory(memory)
        }
    }
    
    func deindexMemory(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["memory-\(id.uuidString)"])
    }
    
    func indexReminder(_ reminder: ReminderItem) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .content)
        attributeSet.title = reminder.title
        attributeSet.contentDescription = reminder.notes.isEmpty ? (reminder.dueDate?.formatted() ?? "Task") : reminder.notes
        attributeSet.keywords = ["Reminder", "Task", "Mepo", reminder.title]
        
        if let location = reminder.locationName {
            attributeSet.namedLocation = location
            attributeSet.keywords?.append(location)
        }
        
        let item = CSSearchableItem(
            uniqueIdentifier: "reminder-\(reminder.id.uuidString)",
            domainIdentifier: Self.reminderDomain,
            attributeSet: attributeSet
        )
        
        CSSearchableIndex.default().indexSearchableItems([item])
    }
    
    func deindexReminder(id: UUID) {
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["reminder-\(id.uuidString)"])
    }
    
    func handleSpotlightActivity(identifier: String) -> Bool {
        if identifier.hasPrefix("memory-") {
            let uuidString = String(identifier.dropFirst("memory-".count))
            if let uuid = UUID(uuidString: uuidString) {
                selectedMemoryId = uuid
                return true
            }
        } else if identifier.hasPrefix("reminder-") {
            let uuidString = String(identifier.dropFirst("reminder-".count))
            if let uuid = UUID(uuidString: uuidString) {
                selectedReminderId = uuid
                return true
            }
        }
        return false
    }
}
