import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Interactive Toggle Intent
struct ToggleWidgetReminderIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Reminder"
    
    @Parameter(title: "Reminder ID")
    var id: String
    
    init() {
        self.id = ""
    }
    
    init(id: String) {
        self.id = id
    }
    
    func perform() async throws -> some IntentResult {
        MepoWidgetStore.shared.toggleReminder(id: id)
        return .result()
    }
}

// MARK: - Reminders Timeline Provider
struct RemindersTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> RemindersEntry {
        RemindersEntry(date: Date(), reminders: MepoWidgetStore.shared.load().reminders)
    }

    func getSnapshot(in context: Context, completion: @escaping (RemindersEntry) -> Void) {
        let entry = RemindersEntry(date: Date(), reminders: MepoWidgetStore.shared.load().reminders)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RemindersEntry>) -> Void) {
        let payload = MepoWidgetStore.shared.load()
        let entry = RemindersEntry(date: Date(), reminders: payload.reminders)
        // Refresh every 30 minutes or when reloaded by app
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct RemindersEntry: TimelineEntry {
    let date: Date
    let reminders: [WidgetReminder]
}

// MARK: - Reminders Widget View
struct RemindersWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: RemindersEntry
    
    var pendingCount: Int {
        entry.reminders.filter { !$0.isCompleted }.count
    }
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallRemindersView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            mediumRemindersView
        }
    }
    
    // MARK: - Small View
    @ViewBuilder private var smallRemindersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.blue)
                Text("Reminders")
                    .font(.caption.bold())
                Spacer()
                Text("\(pendingCount)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            Spacer()
            
            if let firstPending = entry.reminders.first(where: { !$0.isCompleted }) ?? entry.reminders.first {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Button(intent: ToggleWidgetReminderIntent(id: firstPending.id)) {
                            Image(systemName: firstPending.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(firstPending.isCompleted ? .green : .secondary)
                        }
                        .buttonStyle(.plain)
                        
                        Text(firstPending.title)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(2)
                            .strikethrough(firstPending.isCompleted)
                            .foregroundColor(firstPending.isCompleted ? .secondary : .primary)
                    }
                    
                    if let loc = firstPending.locationName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                            Text(loc)
                        }
                        .font(.caption2)
                        .foregroundColor(.purple)
                        .lineLimit(1)
                    } else if let due = firstPending.dueText {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                            Text(due)
                        }
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                    }
                }
            } else {
                Text("All tasks done! 🎉")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Medium View
    @ViewBuilder private var mediumRemindersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .foregroundColor(.blue)
                    Text("Day to Day")
                        .font(.subheadline.bold())
                }
                
                Spacer()
                
                Text("\(pendingCount) pending")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .foregroundColor(.blue)
                    .clipShape(Capsule())
            }
            
            Divider()
            
            let displayReminders = Array(entry.reminders.prefix(3))
            if displayReminders.isEmpty {
                Spacer()
                Text("No reminders for today.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                VStack(spacing: 6) {
                    ForEach(displayReminders) { item in
                        HStack(spacing: 8) {
                            Button(intent: ToggleWidgetReminderIntent(id: item.id)) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.body)
                                    .foregroundColor(item.isCompleted ? .green : .secondary)
                            }
                            .buttonStyle(.plain)
                            
                            Text(item.title)
                                .font(.caption.weight(.medium))
                                .lineLimit(1)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .secondary : .primary)
                            
                            if item.isImportant {
                                Image(systemName: "exclamationmark")
                                    .font(.caption2.bold())
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            if let loc = item.locationName {
                                HStack(spacing: 2) {
                                    Image(systemName: "mappin")
                                    Text(loc)
                                }
                                .font(.caption2)
                                .foregroundColor(.purple)
                                .lineLimit(1)
                            } else if let due = item.dueText {
                                Text(due)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Lock Screen Accessory
    @ViewBuilder private var accessoryRectangularView: some View {
        if let first = entry.reminders.first(where: { !$0.isCompleted }) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "checklist")
                    Text("Mepo • \(pendingCount) left")
                        .font(.caption2.bold())
                }
                Text(first.title)
                    .font(.headline)
                    .lineLimit(1)
                if let loc = first.locationName {
                    Text(loc)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Text("All tasks done! 🎉")
                .font(.headline)
        }
    }
}

// MARK: - Reminders Widget Definition
struct RemindersWidget: Widget {
    let kind: String = "RemindersWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RemindersTimelineProvider()) { entry in
            RemindersWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Day to Day Reminders")
        .description("View and check off your top tasks directly from your Home Screen.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

// MARK: - Memories Timeline Provider
struct MemoriesTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> MemoriesEntry {
        MemoriesEntry(date: Date(), memory: MepoWidgetStore.shared.load().latestMemory)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoriesEntry) -> Void) {
        let entry = MemoriesEntry(date: Date(), memory: MepoWidgetStore.shared.load().latestMemory)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoriesEntry>) -> Void) {
        let payload = MepoWidgetStore.shared.load()
        let entry = MemoriesEntry(date: Date(), memory: payload.latestMemory)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct MemoriesEntry: TimelineEntry {
    let date: Date
    let memory: WidgetMemory?
}

// MARK: - Memories Widget View
struct MemoriesWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: MemoriesEntry
    
    var body: some View {
        if let mem = entry.memory {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text(mem.category)
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    if let score = mem.ratingScore {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { s in
                                Image(systemName: s <= score ? "star.fill" : "star")
                                    .font(.system(size: 8))
                                    .foregroundColor(s <= score ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                }
                
                Text(mem.title)
                    .font(.subheadline.bold())
                    .lineLimit(2)
                
                if let loc = mem.locationName {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(loc)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
                
                if family == .systemMedium {
                    Text(mem.details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        } else {
            VStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.purple)
                Text("No memories yet")
                    .font(.caption.bold())
                Text("Add places in Mepo to remember them here.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Memories Widget Definition
struct MemoriesWidget: Widget {
    let kind: String = "MemoriesWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MemoriesTimelineProvider()) { entry in
            MemoriesWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Recent Memories")
        .description("Discover recent places, recommendations, and ratings you logged.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
