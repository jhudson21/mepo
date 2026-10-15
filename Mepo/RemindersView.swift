import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - Reminder Filter Options
enum ReminderFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case today = "Today"
    case upcoming = "Upcoming"
    case important = "Important"
    case completed = "Completed"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .all: return "tray.full"
        case .today: return "calendar"
        case .upcoming: return "calendar.badge.clock"
        case .important: return "exclamationmark.circle.fill"
        case .completed: return "checkmark.circle.fill"
        }
    }
}

// MARK: - Reminders View
struct RemindersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \ReminderItem.createdAt, order: .reverse) private var allReminders: [ReminderItem]
    
    @State private var selectedFilter: ReminderFilter = .all
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var reminderToEdit: ReminderItem?
    @State private var selectedReminderID: UUID? = nil
    
    var filteredReminders: [ReminderItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return allReminders.filter { reminder in
            // Search text check
            if !searchText.isEmpty {
                let matchesTitle = reminder.title.localizedCaseInsensitiveContains(searchText)
                let matchesNotes = reminder.notes.localizedCaseInsensitiveContains(searchText)
                let matchesLocation = reminder.locationName?.localizedCaseInsensitiveContains(searchText) ?? false
                guard matchesTitle || matchesNotes || matchesLocation else { return false }
            }
            
            // Filter categories
            switch selectedFilter {
            case .all:
                return !reminder.isCompleted
            case .today:
                guard !reminder.isCompleted, let dueDate = reminder.dueDate else { return false }
                return calendar.isDateInToday(dueDate) || dueDate < now
            case .upcoming:
                guard !reminder.isCompleted, let dueDate = reminder.dueDate else { return false }
                return dueDate > now && !calendar.isDateInToday(dueDate)
            case .important:
                return !reminder.isCompleted && reminder.isImportant
            case .completed:
                return reminder.isCompleted
            }
        }
    }
    
    var activeReminder: ReminderItem? {
        if let id = selectedReminderID, let match = allReminders.first(where: { $0.id == id }) {
            return match
        }
        return filteredReminders.first
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    duoSplitView
                } else {
                    compactView
                }
            }
            .background {
                LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .navigationTitle("Day to Day")
            .searchable(text: $searchText, prompt: "Search reminders...")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
                #else
                ToolbarItem(placement: .navigation) {
                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
                #endif
            }
            .sheet(isPresented: $showingAddSheet) {
                AddReminderSheet()
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .sheet(item: $reminderToEdit) { reminder in
                EditReminderSheet(reminder: reminder)
            }
        }
    }
    
    private var isPad: Bool {
        #if os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
    
    // MARK: - iPhone Duo & iPad Unfolded Dual Pane View
    private var duoSplitView: some View {
        GeometryReader { geometry in
            let isPortrait = geometry.size.height >= geometry.size.width
            if isPortrait {
                // Portrait Pose (Duo & iPad): Card showcase (Detail) above, Card list at bottom (Equal 50/50 vertical split)
                let halfHeight = max(200, (geometry.size.height - 12 - 8) / 2)
                VStack(spacing: 12) {
                    detailPaneView
                        .frame(height: halfHeight)
                    
                    remindersListView
                        .frame(height: halfHeight)
                }
                .padding(.top, 4)
            } else {
                // Landscape Pose: Side by Side (Equal 50/50 horizontal split)
                HStack(alignment: .top, spacing: isPad ? 20 : 24) {
                    remindersListView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    detailPaneView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 8)
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // Left / Bottom Pane (Filters & Reminders List)
    private var remindersListView: some View {
        VStack(spacing: 0) {
            filterCapsulePicker
            
            Group {
                if filteredReminders.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredReminders) { reminder in
                                ReminderRowView(
                                    reminder: reminder,
                                    onEdit: { reminderToEdit = reminder },
                                    onToggle: { toggleReminder(reminder) },
                                    onDelete: { deleteReminder(reminder) },
                                    onSelect: {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                            selectedReminderID = reminder.id
                                        }
                                    }
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(activeReminder?.id == reminder.id ? Color.accentColor : Color.clear, lineWidth: 2.5)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }
    
    // Right / Top Pane (Interactive Canvas & Full Detail)
    private var detailPaneView: some View {
        VStack(spacing: 0) {
            if let reminder = activeReminder {
                ReminderDetailPane(
                    reminder: reminder,
                    onEdit: { reminderToEdit = reminder },
                    onToggle: { toggleReminder(reminder) },
                    onDelete: { deleteReminder(reminder) }
                )
            } else {
                ContentUnavailableView(
                    "No Reminder Selected",
                    systemImage: "checklist",
                    description: Text("Select a reminder from the list to view details, due dates, and locations.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }
    
    // MARK: - Compact Cover Screen View
    private var compactView: some View {
        VStack(spacing: 0) {
            filterCapsulePicker
            
            Group {
                if filteredReminders.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredReminders) { reminder in
                                ReminderRowView(
                                    reminder: reminder,
                                    onEdit: { reminderToEdit = reminder },
                                    onToggle: { toggleReminder(reminder) },
                                    onDelete: { deleteReminder(reminder) }
                                )
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }
    
    // MARK: - Filter Picker
    private var filterCapsulePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReminderFilter.allCases) { filter in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedFilter = filter
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: filter.iconName)
                            Text(filter.rawValue)
                            
                            let count = countForFilter(filter)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(selectedFilter == filter ? Color.white.opacity(0.3) : Color.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedFilter == filter ? Color.accentColor : Color.primary.opacity(0.08))
                        .foregroundColor(selectedFilter == filter ? .white : .primary)
                        .clipShape(Capsule())
                        .hoverEffect(.lift)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.04),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipped()
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(emptyStateTitle, systemImage: emptyStateIcon)
        } description: {
            Text(emptyStateDescription)
        } actions: {
            if selectedFilter != .completed {
                Button("Add Reminder") {
                    showingAddSheet = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "All Clear!"
        case .today: return "Nothing for Today"
        case .upcoming: return "No Upcoming Reminders"
        case .important: return "No Important Reminders"
        case .completed: return "No Completed Reminders"
        }
    }
    
    private var emptyStateIcon: String {
        switch selectedFilter {
        case .all: return "checkmark.seal.fill"
        case .today: return "sun.max.fill"
        case .upcoming: return "calendar.badge.clock"
        case .important: return "star.fill"
        case .completed: return "tray.fill"
        }
    }
    
    private var emptyStateDescription: String {
        switch selectedFilter {
        case .all: return "You have no active day-to-day reminders. Tap + to add one."
        case .today: return "You're all caught up for today."
        case .upcoming: return "No scheduled future tasks."
        case .important: return "Items marked as important will show up here."
        case .completed: return "Completed tasks will be saved here."
        }
    }
    
    private func countForFilter(_ filter: ReminderFilter) -> Int {
        let calendar = Calendar.current
        let now = Date()
        
        switch filter {
        case .all:
            return allReminders.filter { !$0.isCompleted }.count
        case .today:
            return allReminders.filter { !$0.isCompleted && ($0.dueDate.map { calendar.isDateInToday($0) || $0 < now } ?? false) }.count
        case .upcoming:
            return allReminders.filter { !$0.isCompleted && ($0.dueDate.map { $0 > now && !calendar.isDateInToday($0) } ?? false) }.count
        case .important:
            return allReminders.filter { !$0.isCompleted && $0.isImportant }.count
        case .completed:
            return allReminders.filter { $0.isCompleted }.count
        }
    }
    
    private func toggleReminder(_ reminder: ReminderItem) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            reminder.toggleCompletion()
            try? modelContext.save()
            
            Task {
                if reminder.isCompleted {
                    NotificationManager.shared.cancelNotification(for: reminder)
                } else {
                    await NotificationManager.shared.scheduleNotification(for: reminder)
                }
            }
        }
    }
    
    private func deleteReminder(_ reminder: ReminderItem) {
        NotificationManager.shared.cancelNotification(for: reminder)
        withAnimation {
            modelContext.delete(reminder)
            try? modelContext.save()
        }
    }
    
}

// MARK: - ReminderDetailPane (iPhone Duo Large Screen Canvas)
struct ReminderDetailPane: View {
    @Bindable var reminder: ReminderItem
    var onEdit: () -> Void
    var onToggle: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header with Checkbox and Title
                HStack(alignment: .top, spacing: 14) {
                    Button(action: onToggle) {
                        Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title)
                            .foregroundColor(reminder.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(reminder.title)
                            .font(.title2.bold())
                            .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                            .strikethrough(reminder.isCompleted)
                        
                        if reminder.isImportant {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.orange)
                                Text("Important")
                                    .font(.caption.bold())
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    
                    Spacer()
                }
                
                // Timing & Recurrence Badges
                VStack(alignment: .leading, spacing: 12) {
                    if let due = reminder.dueDate {
                        let isOverdue = !reminder.isCompleted && due < Date()
                        HStack(spacing: 8) {
                            Image(systemName: isOverdue ? "exclamationmark.calendar" : "calendar.badge.clock")
                                .foregroundColor(isOverdue ? .red : .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(isOverdue ? "Overdue" : "Due Date")
                                    .font(.caption2.bold())
                                    .foregroundColor(isOverdue ? .red : .secondary)
                                    .textCase(.uppercase)
                                Text(due, format: Date.FormatStyle(date: .complete, time: .shortened))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(isOverdue ? .red : .primary)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isOverdue ? Color.red.opacity(0.1) : Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    
                    if reminder.recurrence != .none {
                        HStack(spacing: 8) {
                            Image(systemName: "repeat")
                                .foregroundColor(.purple)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Repeats")
                                    .font(.caption2.bold())
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                Text(reminder.recurrence.rawValue)
                                    .font(.subheadline.weight(.medium))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.purple.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
                
                // Location Trigger Card
                if let locName = reminder.locationName, let lat = reminder.latitude, let lon = reminder.longitude {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.purple)
                            Text(locName)
                                .font(.subheadline.bold())
                            Spacer()
                        }
                        
                        let position = MapCameraPosition.region(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        ))
                        Map(position: .constant(position)) {
                            Marker(locName, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        Button {
                            let loc = CLLocation(latitude: lat, longitude: lon)
                            let mapItem = MKMapItem(location: loc, address: nil)
                            mapItem.name = locName
                            mapItem.openInMaps()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                                Text("Open in Maps")
                            }
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Linked Memory
                if let mem = reminder.linkedMemoryTitle {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Linked Memory")
                                .font(.caption2.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Text(mem)
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Notes
                if !reminder.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(reminder.notes)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Action Buttons
                HStack(spacing: 12) {
                    Button(action: onEdit) {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit Reminder")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.08))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(role: .destructive, action: onDelete) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Delete")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.12))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }
}

// MARK: - Reminder Row View
struct ReminderRowView: View {
    @Bindable var reminder: ReminderItem
    var onEdit: () -> Void
    var onToggle: () -> Void
    var onDelete: () -> Void
    var onSelect: (() -> Void)? = nil
    
    private var isOverdue: Bool {
        guard let due = reminder.dueDate, !reminder.isCompleted else { return false }
        return due < Date()
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkmark button
            Button(action: onToggle) {
                Image(systemName: reminder.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(reminder.isCompleted ? .green : (reminder.isImportant ? .orange : .secondary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(reminder.title)
                        .font(.body.weight(.medium))
                        .strikethrough(reminder.isCompleted, color: .secondary)
                        .foregroundColor(reminder.isCompleted ? .secondary : .primary)
                    
                    Spacer()
                    
                    if reminder.isImportant {
                        Image(systemName: "exclamationmark.3")
                            .font(.caption.bold())
                            .foregroundColor(.orange)
                    }
                }
                
                if !reminder.notes.isEmpty {
                    Text(reminder.notes)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Badges row
                if reminder.dueDate != nil || reminder.recurrence != .none || reminder.hasLocation {
                    HStack(spacing: 8) {
                        if let dueDate = reminder.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                Text(dueDateText(for: dueDate))
                            }
                            .font(.caption2.bold())
                            .foregroundColor(isOverdue ? .red : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background((isOverdue ? Color.red : Color.secondary).opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        if reminder.recurrence != .none {
                            HStack(spacing: 4) {
                                Image(systemName: reminder.recurrence.iconName)
                                Text(reminder.recurrence.rawValue)
                            }
                            .font(.caption2.bold())
                            .foregroundColor(.blue)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        
                        if reminder.hasLocation, let loc = reminder.locationName {
                            let locIcon: String = {
                                if reminder.linkedMemoryTitle != nil { return "sparkles" }
                                if reminder.notifyOnDeparture && !reminder.notifyOnArrival { return "arrow.up.left.circle.fill" }
                                return "location.fill"
                            }()
                            let locPrefix: String = {
                                if reminder.notifyOnDeparture && !reminder.notifyOnArrival { return "Leaving " }
                                if reminder.notifyOnArrival && reminder.notifyOnDeparture { return "Near " }
                                return ""
                            }()
                            HStack(spacing: 4) {
                                Image(systemName: locIcon)
                                Text("\(locPrefix)\(loc)")
                            }
                            .font(.caption2.bold())
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
        .onTapGesture {
            if let onSelect = onSelect {
                onSelect()
            } else {
                onEdit()
            }
        }
        .contextMenu {
            Button(action: onToggle) {
                Label(reminder.isCompleted ? "Mark Incomplete" : "Mark Complete", systemImage: reminder.isCompleted ? "circle" : "checkmark.circle")
            }
            
            Button {
                reminder.isImportant.toggle()
                try? reminder.modelContext?.save()
            } label: {
                Label(reminder.isImportant ? "Remove Important" : "Mark as Important", systemImage: reminder.isImportant ? "exclamationmark.circle" : "exclamationmark.3")
            }
            
            Button(action: onEdit) {
                Label("Edit Reminder", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
        .swipeActions(edge: .leading) {
            Button {
                onToggle()
            } label: {
                Label("Done", systemImage: reminder.isCompleted ? "arrow.uturn.backward" : "checkmark")
            }
            .tint(reminder.isCompleted ? .gray : .green)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            Button {
                reminder.isImportant.toggle()
                try? reminder.modelContext?.save()
            } label: {
                Label("Important", systemImage: "exclamationmark.3")
            }
            .tint(.orange)
        }
    }
    
    private func dueDateText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Today, " + formatter.string(from: date)
        } else if calendar.isDateInTomorrow(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return "Tomorrow, " + formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday (Overdue)"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "d MMM, h:mm a"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Reminder Location Picker Section
struct ReminderLocationPickerSection: View {
    @Binding var hasLocation: Bool
    @Binding var locationName: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    @Binding var notifyOnArrival: Bool
    @Binding var notifyOnDeparture: Bool
    @Binding var radius: Double
    @Binding var linkedMemoryTitle: String?
    
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var memories: [MemoryItem]
    @State private var searchQuery: String = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching: Bool = false
    
    var memoriesWithLocation: [MemoryItem] {
        memories.filter { $0.latitude != nil && $0.longitude != nil }
    }
    
    var body: some View {
        Section("Location & Geofence Alert") {
            Toggle(isOn: $hasLocation.animation()) {
                Label("Location Alert", systemImage: "location.fill")
            }
            
            if hasLocation {
                // Currently selected location preview
                if let _ = latitude, let _ = longitude {
                    HStack(spacing: 12) {
                        Image(systemName: linkedMemoryTitle != nil ? "sparkles" : "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(locationName.isEmpty ? "Selected Location" : locationName)
                                .font(.body.weight(.medium))
                            
                            if let memTitle = linkedMemoryTitle {
                                Text("Linked to Memory: \(memTitle)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button {
                            latitude = nil
                            longitude = nil
                            locationName = ""
                            linkedMemoryTitle = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    
                    // Geofence Trigger Condition
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Trigger Notification")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Toggle(isOn: $notifyOnArrival) {
                            Label("When Arriving", systemImage: "arrow.down.right.circle")
                        }
                        
                        Toggle(isOn: $notifyOnDeparture) {
                            Label("When Leaving", systemImage: "arrow.up.left.circle")
                        }
                    }
                    .padding(.vertical, 2)
                    
                    // Geofence Radius
                    Picker("Geofence Radius", selection: $radius) {
                        Text("100 m (Immediate)").tag(100.0)
                        Text("150 m (Standard)").tag(150.0)
                        Text("300 m (Neighborhood)").tag(300.0)
                        Text("500 m (Wide)").tag(500.0)
                    }
                }
                
                // Choose from Saved Memories
                if !memoriesWithLocation.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("From Your Saved Memories")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(memoriesWithLocation) { memory in
                                    Button {
                                        latitude = memory.latitude
                                        longitude = memory.longitude
                                        locationName = memory.locationName ?? memory.title
                                        linkedMemoryTitle = memory.title
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: "sparkles")
                                            Text(memory.locationName ?? memory.title)
                                        }
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background((latitude == memory.latitude && longitude == memory.longitude) ? Color.purple : Color.secondary.opacity(0.15))
                                        .foregroundColor((latitude == memory.latitude && longitude == memory.longitude) ? .white : .primary)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                
                // Search for any location / address
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search place or address...", text: $searchQuery)
                            .onSubmit {
                                performSearch()
                            }
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                searchResults = []
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if isSearching {
                        ProgressView()
                            .padding(.vertical, 4)
                    } else if !searchResults.isEmpty {
                        ForEach(searchResults.prefix(4), id: \.self) { item in
                            Button {
                                latitude = item.location.coordinate.latitude
                                longitude = item.location.coordinate.longitude
                                locationName = item.name ?? searchQuery
                                linkedMemoryTitle = nil
                                searchResults = []
                                searchQuery = ""
                            } label: {
                                HStack {
                                    Image(systemName: "mappin")
                                        .foregroundColor(.red)
                                    VStack(alignment: .leading) {
                                        Text(item.name ?? "Place")
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true
        Task {
            let items = await LocationManager.searchPlaces(query: searchQuery)
            await MainActor.run {
                searchResults = items
                isSearching = false
            }
        }
    }
}

// MARK: - Add Reminder Sheet
struct AddReminderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var savedMemories: [MemoryItem]
    
    @State private var aiInputText: String = ""
    @State private var isAIFilling: Bool = false
    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    @State private var recurrence: ReminderRecurrence
    @State private var isImportant: Bool
    
    // Location Trigger
    @State private var hasLocation: Bool
    @State private var locationName: String
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var notifyOnArrival: Bool = true
    @State private var notifyOnDeparture: Bool = false
    @State private var radius: Double = 150.0
    @State private var linkedMemoryTitle: String?
    
    // Quick suggestion presets for common day-to-day reminders
    private let quickSuggestions = [
        "Take the bins out",
        "Pay this bill",
        "Pick up groceries",
        "Water the plants",
        "Medication / Vitamins",
        "Call parents"
    ]
    
    init(
        initialTitle: String = "",
        initialNotes: String = "",
        initialLocationName: String? = nil,
        initialLatitude: Double? = nil,
        initialLongitude: Double? = nil,
        initialLinkedMemoryTitle: String? = nil
    ) {
        _title = State(initialValue: initialTitle)
        _notes = State(initialValue: initialNotes)
        _hasDueDate = State(initialValue: initialLatitude == nil)
        _dueDate = State(initialValue: Date().addingTimeInterval(3600))
        _recurrence = State(initialValue: .none)
        _isImportant = State(initialValue: false)
        
        let hasLoc = initialLatitude != nil && initialLongitude != nil
        _hasLocation = State(initialValue: hasLoc)
        _locationName = State(initialValue: initialLocationName ?? "")
        _latitude = State(initialValue: initialLatitude)
        _longitude = State(initialValue: initialLongitude)
        _linkedMemoryTitle = State(initialValue: initialLinkedMemoryTitle)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.purple)
                        TextField("e.g. Water plants every Monday 8am", text: $aiInputText)
                            .onSubmit {
                                applyAIToSheet()
                            }
                        
                        DictationButton(text: $aiInputText)
                        
                        if isAIFilling {
                            ProgressView()
                        } else if !aiInputText.isEmpty {
                            Button("Fill") {
                                applyAIToSheet()
                            }
                            .font(.caption.bold())
                        }
                    }
                } header: {
                    Text("Smart AI Auto-Fill")
                } footer: {
                    Text("Type or dictate naturally with dates, recurrence, or place names to auto-populate.")
                }
                
                Section("What do you need to do?") {
                    HStack {
                        TextField("Reminder title (e.g. Take the bins out)", text: $title)
                        DictationButton(text: $title)
                    }
                    
                    HStack(alignment: .top) {
                        TextField("Notes (optional)", text: $notes, axis: .vertical)
                            .lineLimit(2...4)
                        DictationButton(text: $notes)
                    }
                }
                
                Section("Suggestions") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(quickSuggestions, id: \.self) { suggestion in
                                Button {
                                    title = suggestion
                                } label: {
                                    Text(suggestion)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.15))
                                        .foregroundColor(.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section("Schedule & Recurrence") {
                    Toggle("Set Due Date & Time", isOn: $hasDueDate)
                    
                    if hasDueDate {
                        DatePicker("When", selection: $dueDate)
                            .datePickerStyle(.graphical)
                        
                        Picker("Repeat", selection: $recurrence) {
                            ForEach(ReminderRecurrence.allCases) { rec in
                                Text(rec.rawValue).tag(rec)
                            }
                        }
                    }
                }
                
                ReminderLocationPickerSection(
                    hasLocation: $hasLocation,
                    locationName: $locationName,
                    latitude: $latitude,
                    longitude: $longitude,
                    notifyOnArrival: $notifyOnArrival,
                    notifyOnDeparture: $notifyOnDeparture,
                    radius: $radius,
                    linkedMemoryTitle: $linkedMemoryTitle
                )
                
                Section("Priority") {
                    Toggle(isOn: $isImportant) {
                        HStack {
                            Image(systemName: "exclamationmark.3")
                                .foregroundColor(.orange)
                            Text("Mark as Important")
                        }
                    }
                }
            }
            .navigationTitle("New Reminder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveReminder()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func applyAIToSheet() {
        let text = aiInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isAIFilling = true
        
        Task {
            let parsed = await ReminderAIParser.parse(text: text, existingMemories: savedMemories)
            await MainActor.run {
                if !parsed.title.isEmpty {
                    title = parsed.title
                }
                if !parsed.notes.isEmpty {
                    notes = parsed.notes
                }
                if let due = parsed.dueDate {
                    hasDueDate = true
                    dueDate = due
                }
                if parsed.isImportant {
                    isImportant = true
                }
                if parsed.recurrence != .none {
                    recurrence = parsed.recurrence
                }
                if let lat = parsed.latitude, let lon = parsed.longitude {
                    hasLocation = true
                    latitude = lat
                    longitude = lon
                    locationName = parsed.locationName ?? ""
                    notifyOnArrival = parsed.notifyOnArrival
                    notifyOnDeparture = parsed.notifyOnDeparture
                    linkedMemoryTitle = parsed.linkedMemoryTitle
                }
                isAIFilling = false
            }
        }
    }
    
    private func saveReminder() {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }
        
        let newReminder = ReminderItem(
            title: cleanedTitle,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            dueDate: hasDueDate ? dueDate : nil,
            hasTime: hasDueDate,
            isCompleted: false,
            isImportant: isImportant,
            recurrence: hasDueDate ? recurrence : .none,
            locationName: hasLocation ? (locationName.isEmpty ? nil : locationName) : nil,
            latitude: hasLocation ? latitude : nil,
            longitude: hasLocation ? longitude : nil,
            radius: radius,
            notifyOnArrival: hasLocation && notifyOnArrival,
            notifyOnDeparture: hasLocation && notifyOnDeparture,
            linkedMemoryTitle: hasLocation ? linkedMemoryTitle : nil
        )
        
        modelContext.insert(newReminder)
        try? modelContext.save()
        
        Task {
            await NotificationManager.shared.scheduleNotification(for: newReminder)
        }
        
        dismiss()
    }
}

// MARK: - Edit Reminder Sheet
struct EditReminderSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var reminder: ReminderItem
    
    @State private var hasDueDate: Bool = false
    @State private var hasLocation: Bool = false
    @State private var locationName: String = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var notifyOnArrival: Bool = true
    @State private var notifyOnDeparture: Bool = false
    @State private var radius: Double = 150.0
    @State private var linkedMemoryTitle: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    HStack {
                        TextField("Title", text: $reminder.title)
                        DictationButton(text: $reminder.title)
                    }
                    HStack(alignment: .top) {
                        TextField("Notes", text: $reminder.notes, axis: .vertical)
                            .lineLimit(2...4)
                        DictationButton(text: $reminder.notes)
                    }
                }
                
                Section("Schedule & Recurrence") {
                    Toggle("Set Due Date & Time", isOn: $hasDueDate)
                        .onChange(of: hasDueDate) { _, newValue in
                            if newValue && reminder.dueDate == nil {
                                reminder.dueDate = Date().addingTimeInterval(3600)
                            } else if !newValue {
                                reminder.dueDate = nil
                            }
                        }
                    
                    if hasDueDate {
                        DatePicker("When", selection: Binding(
                            get: { reminder.dueDate ?? Date() },
                            set: { reminder.dueDate = $0 }
                        ))
                        .datePickerStyle(.compact)
                        
                        Picker("Repeat", selection: $reminder.recurrence) {
                            ForEach(ReminderRecurrence.allCases) { rec in
                                Text(rec.rawValue).tag(rec)
                            }
                        }
                    }
                }
                
                ReminderLocationPickerSection(
                    hasLocation: $hasLocation,
                    locationName: $locationName,
                    latitude: $latitude,
                    longitude: $longitude,
                    notifyOnArrival: $notifyOnArrival,
                    notifyOnDeparture: $notifyOnDeparture,
                    radius: $radius,
                    linkedMemoryTitle: $linkedMemoryTitle
                )
                
                Section("Priority") {
                    Toggle(isOn: $reminder.isImportant) {
                        HStack {
                            Image(systemName: "exclamationmark.3")
                                .foregroundColor(.orange)
                            Text("Mark as Important")
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive) {
                        NotificationManager.shared.cancelNotification(for: reminder)
                        modelContext.delete(reminder)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Reminder", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Reminder")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        reminder.locationName = hasLocation ? (locationName.isEmpty ? nil : locationName) : nil
                        reminder.latitude = hasLocation ? latitude : nil
                        reminder.longitude = hasLocation ? longitude : nil
                        reminder.radius = radius
                        reminder.notifyOnArrival = hasLocation && notifyOnArrival
                        reminder.notifyOnDeparture = hasLocation && notifyOnDeparture
                        reminder.linkedMemoryTitle = hasLocation ? linkedMemoryTitle : nil
                        
                        try? modelContext.save()
                        Task {
                            await NotificationManager.shared.scheduleNotification(for: reminder)
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                hasDueDate = reminder.dueDate != nil
                hasLocation = reminder.hasLocation
                locationName = reminder.locationName ?? ""
                latitude = reminder.latitude
                longitude = reminder.longitude
                notifyOnArrival = reminder.notifyOnArrival
                notifyOnDeparture = reminder.notifyOnDeparture
                radius = reminder.radius
                linkedMemoryTitle = reminder.linkedMemoryTitle
            }
        }
    }
}
