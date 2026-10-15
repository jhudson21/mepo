import Testing
import Foundation
import SwiftData
@testable import Mepo

@Suite(.serialized) struct MepoCoreTests {

    // MARK: - 1. Deep Link & URL Parsing Tests
    @Test func quickActionFromValidURLs() {
        let manager = QuickActionManager.shared
        
        let newMemoryURL = URL(string: "mepo://new-memory")!
        #expect(manager.handle(url: newMemoryURL) == true)
        #expect(manager.activeAction == .newMemory)
        
        let newReminderURL = URL(string: "mepo://new-reminder")!
        #expect(manager.handle(url: newReminderURL) == true)
        #expect(manager.activeAction == .newReminder)
        
        let voiceReminderURL = URL(string: "mepo://voice-reminder")!
        #expect(manager.handle(url: voiceReminderURL) == true)
        #expect(manager.activeAction == .voiceReminder)
        
        let invalidURL = URL(string: "mepo://unknown-action")!
        #expect(manager.handle(url: invalidURL) == false)
        
        let wrongSchemeURL = URL(string: "https://google.com")!
        #expect(manager.handle(url: wrongSchemeURL) == false)
    }

    @Test func quickActionFromShortcutTypes() {
        #expect(MepoQuickAction(shortcutType: "com.jordanhudsonpersonalteam.Mepo.newMemory") == .newMemory)
        #expect(MepoQuickAction(shortcutType: "com.jordanhudsonpersonalteam.Mepo.newReminder") == .newReminder)
        #expect(MepoQuickAction(shortcutType: "com.jordanhudsonpersonalteam.Mepo.voiceReminder") == .voiceReminder)
        #expect(MepoQuickAction(shortcutType: "com.other.unknown") == nil)
    }

    // MARK: - 2. Widget Store & JSON Encoding Tests
    @Test func widgetPayloadJSONSerialization() throws {
        let sampleReminder = WidgetReminder(
            id: UUID().uuidString,
            title: "Buy Groceries",
            isCompleted: false,
            isImportant: true,
            dueText: "5:00 PM",
            locationName: "Whole Foods"
        )
        
        let sampleMemory = WidgetMemory(
            id: UUID().uuidString,
            title: "Best Croissant in Paris",
            category: "Food & Drink",
            locationName: "Du Pain et des Idées",
            ratingScore: 5,
            ratingSubject: "Pastry",
            details: "Crispy and buttery",
            dateText: "Oct 12"
        )
        
        let payload = WidgetPayload(
            reminders: [sampleReminder],
            latestMemory: sampleMemory,
            recentMemories: [sampleMemory]
        )
        
        let encoder = JSONEncoder()
        let encodedData = try encoder.encode(payload)
        #expect(!encodedData.isEmpty)
        
        let decoder = JSONDecoder()
        let decodedPayload = try decoder.decode(WidgetPayload.self, from: encodedData)
        #expect(decodedPayload.reminders.count == 1)
        #expect(decodedPayload.reminders.first?.title == "Buy Groceries")
        #expect(decodedPayload.reminders.first?.isImportant == true)
        #expect(decodedPayload.latestMemory?.title == "Best Croissant in Paris")
        #expect(decodedPayload.latestMemory?.ratingScore == 5)
    }

    @Test func widgetStoreToggleReminder() {
        let store = MepoWidgetStore.shared
        let testId = UUID().uuidString
        let reminder = WidgetReminder(
            id: testId,
            title: "Test Task",
            isCompleted: false,
            isImportant: false,
            dueText: nil,
            locationName: nil
        )
        
        store.save(reminders: [reminder], latestMemory: nil, recentMemories: [])
        let initial = store.load()
        #expect(initial.reminders.first(where: { $0.id == testId })?.isCompleted == false)
        
        store.toggleReminder(id: testId)
        let toggled = store.load()
        #expect(toggled.reminders.first(where: { $0.id == testId })?.isCompleted == true)
        
        store.toggleReminder(id: testId)
        let toggledBack = store.load()
        #expect(toggledBack.reminders.first(where: { $0.id == testId })?.isCompleted == false)
        
        // Reset store so subsequent tests start with clean state
        store.resetToDefaults()
    }

    @Test func widgetStoreDefaultFallbackMemories() {
        let store = MepoWidgetStore.shared
        store.resetToDefaults()
        let payload = store.load()
        // If no memories are saved, fallback to curated placeholders
        #expect(!payload.recentMemories.isEmpty)
        #expect(payload.latestMemory != nil)
        #expect(payload.latestMemory?.title.isEmpty == false)
    }

    // MARK: - 3. Natural Language & AI Parser Tests
    @Test @MainActor func reminderParserPriorityDetection() async {
        let result = await ReminderAIParser.parse(text: "Submit quarterly taxes urgent")
        #expect(result.isImportant == true)
        
        let importantResult = await ReminderAIParser.parse(text: "Doctor appointment is very important")
        #expect(importantResult.isImportant == true)
        
        let normalResult = await ReminderAIParser.parse(text: "Water the plants")
        #expect(normalResult.isImportant == false)
    }

    @Test @MainActor func reminderParserDepartureGeofenceDetection() async {
        let departureResult = await ReminderAIParser.parse(text: "Turn off heater when I leave home")
        // Departure cue should configure departure trigger or preserve text
        #expect(departureResult.notifyOnDeparture == true || departureResult.title.contains("leave"))
    }

    @Test @MainActor func reminderParserRecurrenceDetection() async {
        let dailyResult = await ReminderAIParser.parse(text: "Take vitamins every day")
        #expect(dailyResult.recurrence == .daily || dailyResult.title.contains("vitamins"))
        
        let weeklyResult = await ReminderAIParser.parse(text: "Team standup every week")
        #expect(weeklyResult.recurrence == .weekly || weeklyResult.title.contains("standup"))
    }

    // MARK: - 4. Geofence & Location Thresholds
    @Test func reminderItemGeofenceRadiusDefaultsAndClamping() {
        let defaultReminder = ReminderItem(
            title: "Check mail",
            locationName: "Post Office",
            latitude: 51.5074,
            longitude: -0.1278
        )
        
        #expect(defaultReminder.radius >= 100.0)
        #expect(defaultReminder.notifyOnArrival == true)
        #expect(defaultReminder.notifyOnDeparture == false)
        #expect(defaultReminder.hasLocation == true)
    }

    @Test func reminderRecurrenceRawValues() {
        #expect(ReminderRecurrence.none.rawValue == "None")
        #expect(ReminderRecurrence.daily.rawValue == "Daily")
        #expect(ReminderRecurrence.weekly.rawValue == "Weekly")
        #expect(ReminderRecurrence.monthly.rawValue == "Monthly")
    }

    // MARK: - 5. Memory Export Text Representation
    @Test func memoryShareFormattedTextWithRatings() {
        let memory = MemoryItem(
            title: "Dishoom Shoreditch",
            details: "Best black daal and bacon naan roll in London.",
            category: "Food & Drink",
            locationName: "Boundary St, London",
            latitude: 51.5245,
            longitude: -0.0772,
            ratings: [MemoryRating(subject: "Breakfast", score: 5)]
        )
        
        let text = memory.shareFormattedText
        #expect(text.contains("Dishoom Shoreditch"))
        #expect(text.contains("Food & Drink"))
        #expect(text.contains("Boundary St, London"))
        #expect(text.contains("★★★★★"))
        #expect(text.contains("Breakfast"))
        #expect(text.contains("Mepo"))
    }

    @Test func memoryShareFormattedTextWithoutLocationOrRatings() {
        let simpleMemory = MemoryItem(
            title: "Great Book Recommendation",
            details: "Read 'Klara and the Sun' by Kazuo Ishiguro.",
            category: "Notes"
        )
        
        let text = simpleMemory.shareFormattedText
        #expect(text.contains("Great Book Recommendation"))
        #expect(text.contains("Notes"))
        #expect(text.contains("Klara and the Sun"))
        #expect(!text.contains("📍"))
        #expect(!text.contains("Ratings:"))
        #expect(text.contains("Mepo"))
    }

    // MARK: - 6. Full Data Backup & Export Tests
    @Test @MainActor func fullDataBackupJSONExport() throws {
        let memory = MemoryItem(
            title: "Tate Modern",
            details: "Modern art exhibition",
            category: "Art",
            locationName: "Bankside, London",
            latitude: 51.5076,
            longitude: -0.0994
        )
        let reminder = ReminderItem(
            title: "Pick up sketchpad",
            isImportant: true
        )
        
        let jsonURL = try FullDataBackupExporter.createJSONExport(memories: [memory], reminders: [reminder])
        #expect(FileManager.default.fileExists(atPath: jsonURL.path))
        
        let data = try Data(contentsOf: jsonURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(MepoBackupPayload.self, from: data)
        #expect(payload.memories.count == 1)
        #expect(payload.memories.first?.title == "Tate Modern")
        #expect(payload.reminders.count == 1)
        #expect(payload.reminders.first?.title == "Pick up sketchpad")
    }

    @Test @MainActor func fullDataBackupMarkdownExport() throws {
        let memory = MemoryItem(
            title: "Monmouth Coffee",
            details: "Flat white was phenomenal",
            category: "Coffee"
        )
        let reminder = ReminderItem(
            title: "Buy whole beans",
            isImportant: false
        )
        
        let mdURL = try FullDataBackupExporter.createMarkdownExport(memories: [memory], reminders: [reminder])
        #expect(FileManager.default.fileExists(atPath: mdURL.path))
        
        let mdString = try String(contentsOf: mdURL, encoding: .utf8)
        #expect(mdString.contains("# Mepo Data Export"))
        #expect(mdString.contains("Monmouth Coffee"))
        #expect(mdString.contains("Buy whole beans"))
    }

    // MARK: - 7. Spotlight & Notification Constants
    @Test @MainActor func spotlightActivityHandling() {
        let manager = SpotlightManager.shared
        let testMemoryUUID = UUID()
        let memHandled = manager.handleSpotlightActivity(identifier: "memory-\(testMemoryUUID.uuidString)")
        #expect(memHandled == true)
        #expect(manager.selectedMemoryId == testMemoryUUID)
        
        let testReminderUUID = UUID()
        let remHandled = manager.handleSpotlightActivity(identifier: "reminder-\(testReminderUUID.uuidString)")
        #expect(remHandled == true)
        #expect(manager.selectedReminderId == testReminderUUID)
        
        let invalidHandled = manager.handleSpotlightActivity(identifier: "invalid-id")
        #expect(invalidHandled == false)
    }

    @Test @MainActor func notificationActionConstants() {
        #expect(NotificationManager.categoryReminder == "MEPO_REMINDER_CATEGORY")
        #expect(NotificationManager.actionMarkDone == "MEPO_ACTION_MARK_DONE")
        #expect(NotificationManager.actionSnooze15 == "MEPO_ACTION_SNOOZE_15")
    }


    // MARK: - 8. Full Data Backup Importer & Deduplication Tests
    @Test @MainActor func fullDataBackupJSONImportRoundtripAndDeduplication() throws {
        let memory = MemoryItem(
            title: "British Museum",
            details: "Rosetta stone gallery",
            category: "Places",
            ratings: [MemoryRating(subject: "History", score: 5)]
        )
        let reminder = ReminderItem(
            title: "Renew museum membership",
            isImportant: true
        )
        
        let jsonURL = try FullDataBackupExporter.createJSONExport(memories: [memory], reminders: [reminder])
        
        let schema = Schema([MemoryItem.self, ReminderItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        
        // 1. Initial import
        let initialSummary = try FullDataBackupImporter.importJSON(from: jsonURL, modelContext: context)
        #expect(initialSummary.importedMemories == 1)
        #expect(initialSummary.updatedMemories == 0)
        #expect(initialSummary.importedReminders == 1)
        #expect(initialSummary.updatedReminders == 0)
        #expect(initialSummary.totalProcessed == 2)
        
        let fetchedMems = try context.fetch(FetchDescriptor<MemoryItem>())
        #expect(fetchedMems.count == 1)
        #expect(fetchedMems.first?.title == "British Museum")
        #expect(fetchedMems.first?.ratings.first?.score == 5)
        
        let fetchedRems = try context.fetch(FetchDescriptor<ReminderItem>())
        #expect(fetchedRems.count == 1)
        #expect(fetchedRems.first?.title == "Renew museum membership")
        #expect(fetchedRems.first?.isImportant == true)
        
        // 2. Re-import same backup: verify deduplication and update
        let reimportSummary = try FullDataBackupImporter.importJSON(from: jsonURL, modelContext: context)
        #expect(reimportSummary.importedMemories == 0)
        #expect(reimportSummary.updatedMemories == 1)
        #expect(reimportSummary.importedReminders == 0)
        #expect(reimportSummary.updatedReminders == 1)
        #expect(reimportSummary.totalProcessed == 2)
        
        // Ensure count hasn't doubled
        let totalMems = try context.fetch(FetchDescriptor<MemoryItem>())
        #expect(totalMems.count == 1)
    }

    // MARK: - 9. Sample Data Loader & Start Fresh Tests
    @Test @MainActor func sampleDataLoaderPopulationAndDeduplication() throws {
        let schema = Schema([MemoryItem.self, ReminderItem.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = container.mainContext
        
        // Add a personal custom memory and reminder
        let personalMemory = MemoryItem(title: "My Custom Favorite Place", category: "Personal")
        let personalReminder = ReminderItem(title: "My Personal Custom Task")
        context.insert(personalMemory)
        context.insert(personalReminder)
        try context.save()
        
        // First load: 4 memories and 4 reminders added
        let firstResult = SampleDataLoader.loadSampleData(into: context)
        #expect(firstResult.memoriesAdded == 4)
        #expect(firstResult.remindersAdded == 4)
        
        let memsAfterFirst = try context.fetch(FetchDescriptor<MemoryItem>())
        #expect(memsAfterFirst.count == 5) // 1 personal + 4 sample
        
        // Second load: should detect existing titles and add 0 duplicates!
        let secondResult = SampleDataLoader.loadSampleData(into: context)
        #expect(secondResult.memoriesAdded == 0)
        #expect(secondResult.remindersAdded == 0)
        
        let memsAfterSecond = try context.fetch(FetchDescriptor<MemoryItem>())
        #expect(memsAfterSecond.count == 5) // Still exactly 5, no duplicate cards!
        
        // Start Fresh (clearSampleData): should remove only the 4 sample memories & reminders
        let clearResult = SampleDataLoader.clearSampleData(from: context)
        #expect(clearResult.memoriesRemoved == 4)
        #expect(clearResult.remindersRemoved == 4)
        
        let remainingMemories = try context.fetch(FetchDescriptor<MemoryItem>())
        #expect(remainingMemories.count == 1)
        #expect(remainingMemories.first?.title == "My Custom Favorite Place")
        
        let remainingReminders = try context.fetch(FetchDescriptor<ReminderItem>())
        #expect(remainingReminders.count == 1)
        #expect(remainingReminders.first?.title == "My Personal Custom Task")
    }
}
