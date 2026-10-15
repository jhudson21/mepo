import AppIntents
import SwiftData
import Foundation

// MARK: - Add Quick Reminder Intent
struct AddQuickReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Quick Reminder"
    static var description = IntentDescription("Quickly adds a day-to-day reminder to Mepo.")
    
    @Parameter(title: "Task Title")
    var title: String
    
    @Parameter(title: "Important", default: false)
    var isImportant: Bool
    
    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$title) to Mepo")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let container = try ModelContainer(for: MemoryItem.self, ReminderItem.self)
            let context = ModelContext(container)
            
            let reminder = ReminderItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                isImportant: isImportant
            )
            
            context.insert(reminder)
            try context.save()
            
            await NotificationManager.shared.scheduleNotification(for: reminder)
            SpotlightManager.shared.indexReminder(reminder)
            
            return .result(dialog: "Added '\(reminder.title)' to Mepo.")
        } catch {
            return .result(dialog: "Could not save reminder.")
        }
    }
}

// MARK: - Log Memory Intent
struct LogMemoryIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Memory"
    static var description = IntentDescription("Log a new memory, place, or note in Mepo.")
    
    @Parameter(title: "Title")
    var title: String
    
    @Parameter(title: "Category", default: "Notes")
    var category: String
    
    @Parameter(title: "Details", default: "")
    var details: String
    
    static var parameterSummary: some ParameterSummary {
        Summary("Log memory \(\.$title) in Mepo")
    }
    
    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            let container = try ModelContainer(for: MemoryItem.self, ReminderItem.self)
            let context = ModelContext(container)
            
            let memory = MemoryItem(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                category: category.isEmpty ? "Notes" : category
            )
            
            context.insert(memory)
            try context.save()
            
            SpotlightManager.shared.indexMemory(memory)
            
            return .result(dialog: "Logged '\(memory.title)' in Mepo.")
        } catch {
            return .result(dialog: "Could not save memory.")
        }
    }
}

// MARK: - Toggle Reminder Intent (For Interactive Widgets & Shortcuts)
struct ToggleReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Reminder"
    static var description = IntentDescription("Toggles completion status for a reminder.")
    
    @Parameter(title: "Reminder ID")
    var reminderId: String
    
    init() {
        self.reminderId = ""
    }
    
    init(reminderId: String) {
        self.reminderId = reminderId
    }
    
    @MainActor
    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: reminderId) else { return .result() }
        do {
            let container = try ModelContainer(for: MemoryItem.self, ReminderItem.self)
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<ReminderItem>(predicate: #Predicate { $0.id == uuid })
            if let reminder = try context.fetch(descriptor).first {
                reminder.toggleCompletion()
                try context.save()
                if reminder.isCompleted {
                    NotificationManager.shared.cancelNotification(for: reminder)
                } else {
                    await NotificationManager.shared.scheduleNotification(for: reminder)
                }
            }
        } catch {
            // Ignore error
        }
        return .result()
    }
}

// MARK: - Mepo Shortcuts Provider
struct MepoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddQuickReminderIntent(),
            phrases: [
                "Add a reminder in \(.applicationName)",
                "New \(.applicationName) reminder",
                "Remind me in \(.applicationName)"
            ],
            shortTitle: "Add Reminder",
            systemImageName: "checklist"
        )
        AppShortcut(
            intent: LogMemoryIntent(),
            phrases: [
                "Log a memory in \(.applicationName)",
                "New memory in \(.applicationName)",
                "Record memory in \(.applicationName)"
            ],
            shortTitle: "Log Memory",
            systemImageName: "sparkles"
        )
    }
}
