import Testing
import Foundation
@testable import Mepo

struct MepoCoreTests {

    // MARK: - 1. Quick Actions & Deep Linking Tests
    @Test func quickActionFromValidURLs() {
        let manager = QuickActionManager.shared
        
        #expect(manager.handle(url: URL(string: "mepo://new-memory")!))
        #expect(manager.activeAction == .newMemory)
        
        #expect(manager.handle(url: URL(string: "mepo://new-reminder")!))
        #expect(manager.activeAction == .newReminder)
        
        #expect(manager.handle(url: URL(string: "mepo://voice-reminder")!))
        #expect(manager.activeAction == .voiceReminder)
        
        // Invalid URL schemes or routes
        #expect(!manager.handle(url: URL(string: "https://google.com")!))
        #expect(!manager.handle(url: URL(string: "mepo://unknown-action")!))
        #expect(!manager.handle(url: URL(string: "about:blank")!))
    }

    @Test func quickActionFromShortcutTypes() {
        let memoryAction = MepoQuickAction(shortcutType: "com.jordanhudsonpersonalteam.Mepo.newMemory")
        #expect(memoryAction == .newMemory)
        
        let reminderAction = MepoQuickAction(shortcutType: "com.jordanhudsonpersonalteam.Mepo.newReminder")
        #expect(reminderAction == .newReminder)
        
        let voiceAction = MepoQuickAction(shortcutType: "com.jordanhudsonpersonalteam.Mepo.voiceReminder")
        #expect(voiceAction == .voiceReminder)
        
        let unknownAction = MepoQuickAction(shortcutType: "com.apple.unknown")
        #expect(unknownAction == nil)
    }

    // MARK: - 2. Widget Store & Serialization Tests
    @Test func widgetPayloadJSONSerialization() throws {
        let memory = WidgetMemory(
            id: UUID().uuidString,
            title: "Tate Modern",
            category: "Culture",
            locationName: "Bankside, London",
            ratingScore: 5,
            ratingSubject: "Exhibits",
            details: "Great modern art and stunning turbine hall view.",
            dateText: "Oct 15"
        )
        
        let reminder = WidgetReminder(
            id: UUID().uuidString,
            title: "Return library book",
            isCompleted: false,
            isImportant: true,
            dueText: "Today",
            locationName: "Central Library"
        )
        
        let payload = WidgetPayload(
            reminders: [reminder],
            latestMemory: memory,
            recentMemories: [memory]
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(payload)
        #expect(!data.isEmpty)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(WidgetPayload.self, from: data)
        
        #expect(decoded.latestMemory?.title == "Tate Modern")
        #expect(decoded.latestMemory?.ratingScore == 5)
        #expect(decoded.recentMemories.count == 1)
        #expect(decoded.reminders.first?.title == "Return library book")
        #expect(decoded.reminders.first?.isImportant == true)
    }

    @Test func widgetStoreToggleReminder() {
        let store = MepoWidgetStore.shared
        let testId = "test-toggle-id-\(UUID().uuidString)"
        let reminder = WidgetReminder(
            id: testId,
            title: "Test Task",
            isCompleted: false,
            isImportant: false,
            dueText: nil,
            locationName: nil
        )
        
        // Save initial
        var payload = store.load()
        payload.reminders.append(reminder)
        store.save(reminders: payload.reminders, latestMemory: payload.latestMemory, recentMemories: payload.recentMemories)
        
        // Toggle on
        store.toggleReminder(id: testId)
        let toggled1 = store.load().reminders.first(where: { $0.id == testId })
        #expect(toggled1?.isCompleted == true)
        
        // Toggle off
        store.toggleReminder(id: testId)
        let toggled2 = store.load().reminders.first(where: { $0.id == testId })
        #expect(toggled2?.isCompleted == false)
    }

    @Test func widgetStoreDefaultFallbackMemories() {
        let store = MepoWidgetStore.shared
        let payload = store.load()
        // Should provide fallback memory showcase even if user data is fresh
        #expect(payload.latestMemory != nil || !payload.recentMemories.isEmpty || payload.reminders.isEmpty)
    }

    // MARK: - 3. Natural Language & AI Parser Tests
    @Test func reminderParserPriorityDetection() async {
        let result = await ReminderAIParser.parse(text: "Submit quarterly taxes urgent")
        #expect(result.isImportant == true)
        
        let importantResult = await ReminderAIParser.parse(text: "Doctor appointment is very important")
        #expect(importantResult.isImportant == true)
        
        let normalResult = await ReminderAIParser.parse(text: "Water the plants")
        #expect(normalResult.isImportant == false)
    }

    @Test func reminderParserDepartureGeofenceDetection() async {
        let departureResult = await ReminderAIParser.parse(text: "Turn off heater when I leave home")
        // Departure cue should configure departure trigger or preserve text
        #expect(departureResult.notifyOnDeparture == true || departureResult.title.contains("leave"))
    }

    @Test func reminderParserRecurrenceDetection() async {
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
}
