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
    
    var pendingReminders: [WidgetReminder] {
        entry.reminders.filter { !$0.isCompleted }
    }
    
    var pendingCount: Int {
        pendingReminders.count
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
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "checklist")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                    Text("REMINDERS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.blue)
                }
                Spacer()
                Text("\(pendingCount)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Spacer(minLength: 2)
            
            if let firstItem = entry.reminders.first(where: { !$0.isCompleted }) ?? entry.reminders.first {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Button(intent: ToggleWidgetReminderIntent(id: firstItem.id)) {
                            Image(systemName: firstItem.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(firstItem.isCompleted ? .green : .secondary)
                                .frame(width: 20, height: 20)
                        }
                        .buttonStyle(.plain)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(firstItem.title)
                                .font(.system(size: 13, weight: .semibold))
                                .lineLimit(2)
                                .strikethrough(firstItem.isCompleted)
                                .foregroundColor(firstItem.isCompleted ? .secondary : .primary)
                            
                            if let loc = firstItem.locationName {
                                HStack(spacing: 3) {
                                    Image(systemName: "mappin")
                                    Text(loc)
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.purple)
                                .lineLimit(1)
                            } else if let due = firstItem.dueText {
                                HStack(spacing: 3) {
                                    Image(systemName: "clock")
                                    Text(due)
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue)
                                .lineLimit(1)
                            }
                        }
                    }
                    
                    // Preview of next pending item if available
                    if let secondItem = entry.reminders.filter({ !$0.isCompleted && $0.id != firstItem.id }).first {
                        Divider()
                            .padding(.vertical, 2)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 10, height: 10)
                            Text(secondItem.title)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            } else {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    Text("All done!")
                        .font(.caption.bold())
                    Text("No pending tasks")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            Spacer(minLength: 2)
        }
    }
    
    // MARK: - Medium View
    @ViewBuilder private var mediumRemindersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 6) {
                    Image(systemName: "checklist")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.blue)
                    Text("DAY TO DAY")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text("\(pendingCount) pending")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
            
            Divider()
            
            let displayItems = Array(entry.reminders.prefix(3))
            if displayItems.isEmpty {
                Spacer()
                HStack {
                    Spacer()
                    Text("No reminders scheduled.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                Spacer()
            } else {
                VStack(spacing: 8) {
                    ForEach(displayItems) { item in
                        HStack(alignment: .center, spacing: 8) {
                            Button(intent: ToggleWidgetReminderIntent(id: item.id)) {
                                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(item.isCompleted ? .green : .secondary)
                                    .frame(width: 20, height: 20)
                            }
                            .buttonStyle(.plain)
                            
                            Text(item.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .strikethrough(item.isCompleted)
                                .foregroundColor(item.isCompleted ? .secondary : .primary)
                            
                            if item.isImportant {
                                Image(systemName: "exclamationmark")
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(.orange)
                            }
                            
                            Spacer()
                            
                            if let loc = item.locationName {
                                HStack(spacing: 2) {
                                    Image(systemName: "mappin")
                                    Text(loc)
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(Capsule())
                                .lineLimit(1)
                            } else if let due = item.dueText {
                                HStack(spacing: 2) {
                                    Image(systemName: "clock")
                                    Text(due)
                                }
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .clipShape(Capsule())
                                .lineLimit(1)
                            }
                        }
                    }
                }
            }
            
            Spacer(minLength: 0)
        }
    }
    
    // MARK: - Lock Screen Accessory
    @ViewBuilder private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                Text("Reminders (\(pendingCount))")
                    .font(.caption2.bold())
            }
            if let first = entry.reminders.first(where: { !$0.isCompleted }) ?? entry.reminders.first {
                Text(first.title)
                    .font(.headline)
                    .lineLimit(1)
                if let loc = first.locationName {
                    Text("📍 \(loc)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else if let due = first.dueText {
                    Text("⏰ \(due)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                Text("All tasks completed")
                    .font(.caption)
            }
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
        .description("View and check off pending tasks directly from your home screen.")
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
                // Top Row: Category badge & Star rating
                HStack(alignment: .center) {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundColor(.purple)
                        Text(mem.category.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.purple.opacity(0.14))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    if let score = mem.ratingScore {
                        HStack(spacing: 1) {
                            ForEach(1...5, id: \.self) { s in
                                Image(systemName: s <= score ? "star.fill" : "star")
                                    .font(.system(size: 7))
                                    .foregroundColor(s <= score ? .yellow : .gray.opacity(0.3))
                            }
                        }
                    }
                }
                
                Spacer(minLength: 4)
                
                // Memory Title
                Text(mem.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Location
                if let loc = mem.locationName {
                    HStack(spacing: 3) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 9))
                        Text(loc)
                            .font(.system(size: 10, weight: .medium))
                    }
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
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                            .foregroundColor(.purple)
                        Text(mem.category.uppercased())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.14))
                    .clipShape(Capsule())
                    
                    if let date = mem.dateText {
                        Text(date)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if let score = mem.ratingScore {
                        HStack(spacing: 3) {
                            if let sub = mem.ratingSubject {
                                Text(sub)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            HStack(spacing: 1) {
                                ForEach(1...5, id: \.self) { s in
                                    Image(systemName: s <= score ? "star.fill" : "star")
                                        .font(.system(size: 8))
                                        .foregroundColor(s <= score ? .yellow : .gray.opacity(0.3))
                                }
                            }
                        }
                    }
                }
                
                // Title and Location
                VStack(alignment: .leading, spacing: 2) {
                    Text(mem.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let loc = mem.locationName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                            Text(loc)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                }
                
                // Details Quote
                if !mem.details.isEmpty {
                    Text(mem.details)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                
                Spacer(minLength: 0)
                
                if entry.recentMemories.count > 1 {
                    HStack {
                        Text("+\(entry.recentMemories.count - 1) other saved places")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.purple)
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
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
                HStack(alignment: .center) {
                    HStack(spacing: 5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.purple)
                        Text("MEPO SHOWCASE")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .foregroundColor(.purple)
                    }
                    Spacer()
                    Text("\(entry.recentMemories.count) Places")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .clipShape(Capsule())
                }
                
                // Hero Memory Card
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(hero.category.uppercased())
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
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
                                        .font(.system(size: 8))
                                        .foregroundColor(s <= score ? .yellow : .gray.opacity(0.3))
                                }
                            }
                        }
                    }
                    
                    Text(hero.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let loc = hero.locationName {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10))
                            Text(loc)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                    
                    if !hero.details.isEmpty {
                        Text(hero.details)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                // Recent Highlights List
                if entry.recentMemories.count > 1 {
                    Text("RECENT HIGHLIGHTS")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 6) {
                        ForEach(Array(entry.recentMemories.dropFirst().prefix(3))) { item in
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.purple.opacity(0.14))
                                        .frame(width: 26, height: 26)
                                    Image(systemName: "mappin")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.purple)
                                }
                                
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    if let loc = item.locationName {
                                        Text(loc)
                                            .font(.system(size: 10))
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
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Spacer(minLength: 0)
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

// MARK: - Reusable Quick Add Tile for Medium Widget
private struct QuickAddActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tintColor: Color
    let destination: String
    
    var body: some View {
        Link(destination: URL(string: destination)!) {
            VStack(spacing: 6) {
                // Fixed-size circular icon badge for pixel-perfect vertical alignment across all cards
                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(tintColor)
                }
                
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 4)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - Reusable Quick Add Row for Small Widget
private struct QuickAddActionRow: View {
    let title: String
    let icon: String
    let tintColor: Color
    let destination: String
    
    var body: some View {
        Link(destination: URL(string: destination)!) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(tintColor)
                }
                
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(tintColor)
                    .frame(width: 20, height: 20)
                    .background(tintColor.opacity(0.12))
                    .clipShape(Circle())
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
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
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.purple)
                    Text("QUICK ADD")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.purple)
                }
                Spacer()
            }
            
            Spacer(minLength: 2)

            VStack(spacing: 6) {
                QuickAddActionRow(
                    title: "New Memory",
                    icon: "sparkles",
                    tintColor: .purple,
                    destination: "mepo://new-memory"
                )
                
                QuickAddActionRow(
                    title: "New Reminder",
                    icon: "checklist",
                    tintColor: .blue,
                    destination: "mepo://new-reminder"
                )
            }
            
            Spacer(minLength: 2)
        }
    }

    // MARK: - Medium Family View
    @ViewBuilder private var mediumQuickAddView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.purple)
                    Text("QUICK ACTIONS")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.purple)
                }
                Spacer()
                Text("One-Tap Capture")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }

            // Cards Row
            HStack(spacing: 8) {
                QuickAddActionCard(
                    title: "Memory",
                    subtitle: "Places & notes",
                    icon: "sparkles",
                    tintColor: .purple,
                    destination: "mepo://new-memory"
                )

                QuickAddActionCard(
                    title: "Reminder",
                    subtitle: "Tasks & alerts",
                    icon: "checklist",
                    tintColor: .blue,
                    destination: "mepo://new-reminder"
                )

                QuickAddActionCard(
                    title: "Dictate",
                    subtitle: "Voice capture",
                    icon: "mic.fill",
                    tintColor: .orange,
                    destination: "mepo://voice-reminder"
                )
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
                        .font(.system(size: 13, weight: .bold))
                    Image(systemName: "sparkles")
                        .font(.system(size: 11))
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
