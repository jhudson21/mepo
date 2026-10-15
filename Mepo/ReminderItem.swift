import Foundation
import SwiftData

// MARK: - Reminder Recurrence
enum ReminderRecurrence: String, Codable, CaseIterable, Identifiable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .none: return ""
        case .daily: return "arrow.clockwise"
        case .weekly: return "arrow.triangle.2.circlepath"
        case .monthly: return "calendar.badge.clock"
        }
    }
}

// MARK: - Reminder Item Model
@Model
class ReminderItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date? = nil
    var hasTime: Bool = false
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var isImportant: Bool = false
    var recurrenceRaw: String = "None"
    var createdAt: Date = Date.now
    
    // Location Trigger & Memories Bridge
    var locationName: String? = nil
    var latitude: Double? = nil
    var longitude: Double? = nil
    var radius: Double = 150.0
    var notifyOnArrival: Bool = true
    var notifyOnDeparture: Bool = false
    var linkedMemoryTitle: String? = nil
    
    var recurrence: ReminderRecurrence {
        get { ReminderRecurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }
    
    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        notes: String = "",
        dueDate: Date? = nil,
        hasTime: Bool = false,
        isCompleted: Bool = false,
        completedAt: Date? = nil,
        isImportant: Bool = false,
        recurrence: ReminderRecurrence = .none,
        locationName: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        radius: Double = 150.0,
        notifyOnArrival: Bool = true,
        notifyOnDeparture: Bool = false,
        linkedMemoryTitle: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasTime = hasTime
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.isImportant = isImportant
        self.recurrenceRaw = recurrence.rawValue
        self.locationName = locationName
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.notifyOnArrival = notifyOnArrival
        self.notifyOnDeparture = notifyOnDeparture
        self.linkedMemoryTitle = linkedMemoryTitle
        self.createdAt = createdAt
    }
    
    /// Advance to next due date if recurring, or toggle completion state
    func toggleCompletion() {
        if isCompleted {
            isCompleted = false
            completedAt = nil
        } else {
            if recurrence != .none, let currentDue = dueDate {
                // Calculate next occurrence
                let calendar = Calendar.current
                var nextDate: Date?
                switch recurrence {
                case .daily:
                    nextDate = calendar.date(byAdding: .day, value: 1, to: currentDue)
                case .weekly:
                    nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDue)
                case .monthly:
                    nextDate = calendar.date(byAdding: .month, value: 1, to: currentDue)
                case .none:
                    break
                }
                
                if let next = nextDate {
                    self.dueDate = next
                    // Keep isCompleted false so it rolls over into the next cycle
                    self.isCompleted = false
                    self.completedAt = .now
                    return
                }
            }
            
            isCompleted = true
            completedAt = .now
        }
    }
}
