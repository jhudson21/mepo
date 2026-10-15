import SwiftUI
import SwiftData
import MapKit

// MARK: - Sample Data Loader
@MainActor
struct SampleDataLoader {
    static let sampleMemoryTitles: Set<String> = [
        "Circolo Popolare",
        "Monmouth Coffee Company",
        "Daunt Books",
        "Tate Modern & River Walk"
    ]
    
    static let sampleReminderTitles: Set<String> = [
        "Pick up freshly roasted beans at Monmouth",
        "Review weekend travel itinerary notes",
        "Return architecture book to Daunt Books",
        "Reserve dinner table for Friday evening"
    ]
    
    @discardableResult
    static func loadSampleData(into modelContext: ModelContext) -> (memoriesAdded: Int, remindersAdded: Int) {
        let existingMemories = (try? modelContext.fetch(FetchDescriptor<MemoryItem>())) ?? []
        let existingReminders = (try? modelContext.fetch(FetchDescriptor<ReminderItem>())) ?? []
        
        let existingMemTitles = Set(existingMemories.map { $0.title })
        let existingRemTitles = Set(existingReminders.map { $0.title })
        
        // Sample Memories
        let circolo = MemoryItem(
            title: "Circolo Popolare",
            details: "Incredible festive atmosphere with walls lined in vintage bottles and decadent carbonara served straight from a pecorino wheel.",
            category: "Food & Drink",
            locationName: "Fitzrovia, London",
            latitude: 51.5173,
            longitude: -0.1345,
            ratings: [
                MemoryRating(subject: "Truffle Pasta", score: 5),
                MemoryRating(subject: "Ambience", score: 5)
            ],
            createdAt: Date.now.addingTimeInterval(-86400 * 2)
        )
        
        let monmouth = MemoryItem(
            title: "Monmouth Coffee Company",
            details: "The benchmark for flat whites in London. Freshly roasted beans, artisanal sourdough pastries, and warm communal seating.",
            category: "Coffee & Cafes",
            locationName: "Covent Garden, London",
            latitude: 51.5134,
            longitude: -0.1265,
            ratings: [
                MemoryRating(subject: "Flat White", score: 5),
                MemoryRating(subject: "Pastries", score: 4)
            ],
            createdAt: Date.now.addingTimeInterval(-86400 * 4)
        )
        
        let daunt = MemoryItem(
            title: "Daunt Books",
            details: "Edwardian bookshop famous for its long oak galleries, skylights, and travel literature arranged thoughtfully by destination.",
            category: "Books & Arts",
            locationName: "Marylebone High St, London",
            latitude: 51.5204,
            longitude: -0.1518,
            ratings: [
                MemoryRating(subject: "Architecture", score: 5),
                MemoryRating(subject: "Travel Books", score: 5)
            ],
            createdAt: Date.now.addingTimeInterval(-86400 * 7)
        )
        
        let tate = MemoryItem(
            title: "Tate Modern & River Walk",
            details: "Monumental Turbine Hall installation followed by an espresso on the terrace looking across the Thames toward St Paul's.",
            category: "Places & Travel",
            locationName: "Bankside, London",
            latitude: 51.5076,
            longitude: -0.0994,
            ratings: [
                MemoryRating(subject: "Exhibitions", score: 5),
                MemoryRating(subject: "Thames View", score: 5)
            ],
            createdAt: Date.now.addingTimeInterval(-86400 * 12)
        )
        
        let sampleMemories = [circolo, monmouth, daunt, tate]
        var memsAdded = 0
        for memory in sampleMemories {
            if !existingMemTitles.contains(memory.title) {
                modelContext.insert(memory)
                memsAdded += 1
            }
        }
        
        // Sample Reminders
        let calendar = Calendar.current
        let todayFivePM = calendar.date(bySettingHour: 17, minute: 0, second: 0, of: .now) ?? .now
        let tomorrowTenAM = calendar.date(byAdding: .day, value: 1, to: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: .now) ?? .now)
        
        let reminder1 = ReminderItem(
            title: "Pick up freshly roasted beans at Monmouth",
            notes: "Ask for the seasonal single origin espresso roast.",
            dueDate: todayFivePM,
            hasTime: true,
            isImportant: true,
            locationName: "Monmouth Coffee Company",
            latitude: 51.5134,
            longitude: -0.1265,
            notifyOnArrival: true,
            linkedMemoryTitle: "Monmouth Coffee Company"
        )
        
        let reminder2 = ReminderItem(
            title: "Review weekend travel itinerary notes",
            notes: "Check restaurant reservations and train departure times.",
            dueDate: tomorrowTenAM,
            hasTime: true,
            isImportant: false,
            recurrence: .weekly
        )
        
        let reminder3 = ReminderItem(
            title: "Return architecture book to Daunt Books",
            notes: "Return borrowed copy before Friday.",
            dueDate: calendar.date(byAdding: .day, value: 3, to: .now),
            hasTime: false,
            isImportant: true,
            locationName: "Daunt Books",
            latitude: 51.5204,
            longitude: -0.1518,
            notifyOnArrival: true,
            linkedMemoryTitle: "Daunt Books"
        )
        
        let reminder4 = ReminderItem(
            title: "Reserve dinner table for Friday evening",
            notes: "Requested window booth.",
            dueDate: .now,
            isCompleted: true,
            completedAt: Date.now.addingTimeInterval(-3600 * 3)
        )
        
        let sampleReminders = [reminder1, reminder2, reminder3, reminder4]
        var remsAdded = 0
        for reminder in sampleReminders {
            if !existingRemTitles.contains(reminder.title) {
                modelContext.insert(reminder)
                remsAdded += 1
            }
        }
        
        try? modelContext.save()
        syncSystemIntegrations(modelContext: modelContext)
        return (memsAdded, remsAdded)
    }
    
    @discardableResult
    static func clearSampleData(from modelContext: ModelContext) -> (memoriesRemoved: Int, remindersRemoved: Int) {
        let existingMemories = (try? modelContext.fetch(FetchDescriptor<MemoryItem>())) ?? []
        let existingReminders = (try? modelContext.fetch(FetchDescriptor<ReminderItem>())) ?? []
        
        var memsRemoved = 0
        for memory in existingMemories where sampleMemoryTitles.contains(memory.title) {
            SpotlightManager.shared.deindexMemory(id: memory.id)
            modelContext.delete(memory)
            memsRemoved += 1
        }
        
        var remsRemoved = 0
        for reminder in existingReminders where sampleReminderTitles.contains(reminder.title) {
            SpotlightManager.shared.deindexReminder(id: reminder.id)
            NotificationManager.shared.cancelNotification(for: reminder)
            modelContext.delete(reminder)
            remsRemoved += 1
        }
        
        try? modelContext.save()
        syncSystemIntegrations(modelContext: modelContext)
        return (memsRemoved, remsRemoved)
    }
    
    static func syncSystemIntegrations(modelContext: ModelContext) {
        let currentMemories = (try? modelContext.fetch(FetchDescriptor<MemoryItem>())) ?? []
        let currentReminders = (try? modelContext.fetch(FetchDescriptor<ReminderItem>())) ?? []
        
        let calendar = Calendar.current
        let widgetReminders = currentReminders.prefix(5).map { r in
            var dueText: String? = nil
            if let due = r.dueDate {
                if calendar.isDateInToday(due) {
                    dueText = r.hasTime ? "Today " + due.formatted(date: .omitted, time: .shortened) : "Today"
                } else if calendar.isDateInTomorrow(due) {
                    dueText = "Tomorrow"
                } else {
                    dueText = due.formatted(date: .abbreviated, time: .omitted)
                }
            }
            return WidgetReminder(
                id: r.id.uuidString,
                title: r.title,
                isCompleted: r.isCompleted,
                isImportant: r.isImportant,
                dueText: dueText,
                locationName: r.locationName
            )
        }
        
        let widgetMemories = currentMemories.prefix(5).map { m in
            WidgetMemory(
                id: m.id.uuidString,
                title: m.title,
                category: m.category,
                locationName: m.locationName,
                ratingScore: m.ratings.first?.score,
                ratingSubject: m.ratings.first?.subject,
                details: m.details,
                dateText: m.createdAt.formatted(date: .abbreviated, time: .omitted)
            )
        }
        
        MepoWidgetStore.shared.save(
            reminders: Array(widgetReminders),
            latestMemory: widgetMemories.first,
            recentMemories: Array(widgetMemories)
        )
        
        SpotlightManager.shared.indexMemories(currentMemories)
        for r in currentReminders {
            SpotlightManager.shared.indexReminder(r)
            if !r.isCompleted, let due = r.dueDate, due > .now {
                Task {
                    await NotificationManager.shared.scheduleNotification(for: r)
                }
            }
        }
    }
}

// MARK: - Welcome & Onboarding View
struct WelcomeOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Binding var hasCompletedOnboarding: Bool
    
    var onExploreWithSampleData: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .indigo, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 28)
                    
                    Text("Welcome to Mepo")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    
                    Text("Your intelligent companion for memorable places, rich notes, and location-aware reminders.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                
                // Feature Highlights
                VStack(alignment: .leading, spacing: 20) {
                    OnboardingFeatureRow(
                        icon: "mappin.and.ellipse",
                        iconColor: .purple,
                        title: "Memories & Places",
                        description: "Save favorite spots with interactive map pins, detailed notes, photos, and personal ratings."
                    )
                    
                    OnboardingFeatureRow(
                        icon: "checklist",
                        iconColor: .blue,
                        title: "Smart Day-to-Day Tasks",
                        description: "Natural language input with AI priority cues, due dates, and arrival or departure geofence alerts."
                    )
                    
                    OnboardingFeatureRow(
                        icon: "square.grid.2x2",
                        iconColor: .indigo,
                        title: "Widgets & Spotlight",
                        description: "Toggle tasks right from your Home Screen with interactive widgets, voice dictation, and system search."
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button {
                        SampleDataLoader.loadSampleData(into: modelContext)
                        hasCompletedOnboarding = true
                        onExploreWithSampleData?()
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                            Text("Explore with Sample Data")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    
                    Button {
                        SampleDataLoader.clearSampleData(from: modelContext)
                        hasCompletedOnboarding = true
                        dismiss()
                    } label: {
                        Text("Start Fresh")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.08),
                        Color.blue.opacity(0.04),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
        }
    }
}

// MARK: - Onboarding Feature Row
private struct OnboardingFeatureRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
