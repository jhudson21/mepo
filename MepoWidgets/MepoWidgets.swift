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
        let payload = MepoWidgetStore.shared.load()
        return MemoriesEntry(date: Date(), memory: payload.latestMemory, recentMemories: payload.recentMemories)
    }

    func getSnapshot(in context: Context, completion: @escaping (MemoriesEntry) -> Void) {
        let payload = MepoWidgetStore.shared.load()
        let entry = MemoriesEntry(date: Date(), memory: payload.latestMemory, recentMemories: payload.recentMemories)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MemoriesEntry>) -> Void) {
        let payload = MepoWidgetStore.shared.load()
        let entry = MemoriesEntry(date: Date(), memory: payload.latestMemory, recentMemories: payload.recentMemories)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct MemoriesEntry: TimelineEntry {
    let date: Date
    let memory: WidgetMemory?
    let recentMemories: [WidgetMemory]
}

// MARK: - Memories Widget View
struct MemoriesWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: MemoriesEntry
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallMemoriesView
        case .systemLarge:
            largeMemoriesView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            mediumMemoriesView
        }
    }
    
    // MARK: - Small Memories View
    @ViewBuilder private var smallMemoriesView: some View {
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
                
                Spacer()
                
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
            }
        } else {
            emptyView
        }
    }
    
    // MARK: - Medium Memories View
    @ViewBuilder private var mediumMemoriesView: some View {
        if let mem = entry.memory {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text(mem.category)
                            .font(.caption2.bold())
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
                    
                    if let date = mem.dateText {
                        Text(date)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let score = mem.ratingScore {
                        HStack(spacing: 3) {
                            if let sub = mem.ratingSubject {
                                Text(sub)
                                    .font(.caption2.weight(.medium))
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 1) {
                                ForEach(1...5, id: \.self) { s in
                                    Image(systemName: s <= score ? "star.fill" : "star")
                                        .font(.system(size: 9))
                                        .foregroundColor(s <= score ? .yellow : .gray.opacity(0.3))
                                }
                            }
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(mem.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let loc = mem.locationName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(loc)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                }
                
                if !mem.details.isEmpty {
                    Text(mem.details)
                        .font(.caption)
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(2)
                }
                
                Spacer()
                
                if entry.recentMemories.count > 1 {
                    HStack {
                        Text("+\(entry.recentMemories.count - 1) other saved places")
                            .font(.caption2.bold())
                            .foregroundColor(.purple)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        } else {
            emptyView
        }
    }
    
    // MARK: - Large Memories View (Memory Showcase)
    @ViewBuilder private var largeMemoriesView: some View {
        if let hero = entry.memory {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        Text("MEPO SHOWCASE")
                            .font(.caption.bold())
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    Text("\(entry.recentMemories.count) Places")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                // Hero Memory Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(hero.category)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .foregroundColor(.purple)
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        if let score = hero.ratingScore {
                            HStack(spacing: 1) {
                                ForEach(1...5, id: \.self) { s in
                                    Image(systemName: s <= score ? "star.fill" : "star")
                                        .font(.system(size: 9))
                                        .foregroundColor(s <= score ? .yellow : .gray.opacity(0.3))
                                }
                            }
                        }
                    }
                    
                    Text(hero.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    if let loc = hero.locationName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(loc)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                    
                    if !hero.details.isEmpty {
                        Text(hero.details)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Recent Highlights List
                if entry.recentMemories.count > 1 {
                    Text("Recent Highlights")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 6) {
                        ForEach(Array(entry.recentMemories.dropFirst().prefix(3))) { item in
                            HStack(spacing: 8) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.purple)
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.subheadline.bold())
                                        .lineLimit(1)
                                    if let loc = item.locationName {
                                        Text(loc)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                if let score = item.ratingScore {
                                    HStack(spacing: 1) {
                                        ForEach(1...5, id: \.self) { s in
                                            Image(systemName: s <= score ? "star.fill" : "star")
                                                .font(.system(size: 7))
                                                .foregroundColor(s <= score ? .yellow : .gray.opacity(0.3))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Spacer()
            }
        } else {
            emptyView
        }
    }
    
    // MARK: - Lock Screen Accessory
    @ViewBuilder private var accessoryRectangularView: some View {
        if let mem = entry.memory {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text(mem.category)
                        .font(.caption2.bold())
                }
                Text(mem.title)
                    .font(.headline)
                    .lineLimit(1)
                if let loc = mem.locationName {
                    Text(loc)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            Text("Mepo Memories")
                .font(.headline)
        }
    }
    
    @ViewBuilder private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.purple)
            Text("No memories yet")
                .font(.caption.bold())
            Text("Add places in Mepo to showcase them here.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

// MARK: - Quick Add Timeline Provider & Entry
struct QuickAddEntry: TimelineEntry {
    let date: Date
}

struct QuickAddTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickAddEntry {
        QuickAddEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickAddEntry) -> Void) {
        completion(QuickAddEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickAddEntry>) -> Void) {
        let entry = QuickAddEntry(date: Date())
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Quick Add Widget View
struct QuickAddWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: QuickAddEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallQuickAddView
        case .systemMedium:
            mediumQuickAddView
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            mediumQuickAddView
        }
    }

    // MARK: - Small Family View
    @ViewBuilder private var smallQuickAddView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("QUICK CAPTURE")
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
            }

            Link(destination: URL(string: "mepo://new-memory")!) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("Memory")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Link(destination: URL(string: "mepo://new-reminder")!) {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                    Text("Reminder")
                        .font(.subheadline.bold())
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Medium Family View
    @ViewBuilder private var mediumQuickAddView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("MEPO QUICK ACTIONS")
                        .font(.caption2.bold())
                        .foregroundColor(.purple)
                }
                Spacer()
                Text("One-Tap Capture")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                Link(destination: URL(string: "mepo://new-memory")!) {
                    VStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.title2)
                        Text("New Memory")
                            .font(.subheadline.bold())
                        Text("Places & ratings")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(colors: [Color.purple, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Link(destination: URL(string: "mepo://new-reminder")!) {
                    VStack(spacing: 6) {
                        Image(systemName: "checklist")
                            .font(.title2)
                        Text("New Reminder")
                            .font(.subheadline.bold())
                        Text("Tasks & alerts")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Link(destination: URL(string: "mepo://voice-reminder")!) {
                    VStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                        Text("Dictate")
                            .font(.subheadline.bold())
                        Text("Voice note")
                            .font(.caption2)
                            .opacity(0.8)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        LinearGradient(colors: [Color.orange, Color.red.opacity(0.85)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
    }

    // MARK: - Lock Screen Circular Accessory
    @ViewBuilder private var accessoryCircularView: some View {
        Link(destination: URL(string: "mepo://new-memory")!) {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 1) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                    Image(systemName: "sparkles")
                        .font(.system(size: 12))
                }
            }
        }
    }

    // MARK: - Lock Screen Rectangular Accessory
    @ViewBuilder private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("Mepo Quick Add")
                    .font(.caption2.bold())
            }
            HStack(spacing: 6) {
                Link(destination: URL(string: "mepo://new-memory")!) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                        Text("Memory")
                    }
                    .font(.caption.bold())
                }
                Text("•")
                    .foregroundColor(.secondary)
                Link(destination: URL(string: "mepo://new-reminder")!) {
                    HStack(spacing: 2) {
                        Image(systemName: "plus")
                        Text("Task")
                    }
                    .font(.caption.bold())
                }
            }
        }
    }
}

// MARK: - Quick Add Widget Definition
struct QuickAddWidget: Widget {
    let kind: String = "QuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickAddTimelineProvider()) { entry in
            QuickAddWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Add")
        .description("Instantly add new memories, reminders, or dictate voice notes.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}
