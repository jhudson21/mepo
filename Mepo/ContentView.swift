import SwiftUI
import SwiftData
import FoundationModels
import MapKit
import CoreLocation
import PhotosUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - Root ContentView (Tab Navigation)
struct ContentView: View {
    @AppStorage("appTheme") private var appTheme = AppTheme.system
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var selectedTab: Int = 0
    @State private var quickActionManager = QuickActionManager.shared
    @State private var showingQuickAddMemory = false
    @State private var showingQuickAddReminder = false
    @State private var showingOnboardingSheet = false
    
    @Query(sort: \ReminderItem.createdAt, order: .reverse) private var allReminders: [ReminderItem]
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var allMemories: [MemoryItem]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Memories", systemImage: "sparkles", value: 0) {
                MemoriesView()
            }
            
            Tab("Day to Day", systemImage: "checklist", value: 1) {
                RemindersView()
            }
        }
        .tabViewStyle(.tabBarOnly)
        .preferredColorScheme(appTheme.colorScheme)
        .onAppear {
            syncWidgets()
            if !hasCompletedOnboarding {
                showingOnboardingSheet = true
            }
            if let action = quickActionManager.activeAction {
                handleQuickAction(action)
            }
        }
        .onChange(of: quickActionManager.activeAction) { _, newAction in
            if let newAction {
                handleQuickAction(newAction)
            }
        }
        .sheet(isPresented: $showingQuickAddMemory) {
            AddMemoryView()
        }
        .sheet(isPresented: $showingQuickAddReminder) {
            AddReminderSheet()
        }
        .sheet(isPresented: $showingOnboardingSheet) {
            WelcomeOnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                .interactiveDismissDisabled(!hasCompletedOnboarding)
        }
        .onChange(of: allReminders) {
            syncWidgets()
        }
        .onChange(of: allMemories) {
            syncWidgets()
        }
    }
    
    private func handleQuickAction(_ action: MepoQuickAction) {
        switch action {
        case .newMemory:
            selectedTab = 0
            showingQuickAddMemory = true
        case .newReminder, .voiceReminder:
            selectedTab = 1
            showingQuickAddReminder = true
        }
        quickActionManager.activeAction = nil
    }
    
    private func syncWidgets() {
        let calendar = Calendar.current
        let widgetReminders = allReminders.map { r in
            var dueText: String? = nil
            if let due = r.dueDate {
                if calendar.isDateInToday(due) {
                    dueText = r.hasTime ? due.formatted(date: .omitted, time: .shortened) : "Today"
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
        
        let widgetMemories = allMemories.prefix(5).map { m in
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
        let latestMem = widgetMemories.first
        
        MepoWidgetStore.shared.save(
            reminders: widgetReminders,
            latestMemory: latestMem,
            recentMemories: Array(widgetMemories)
        )
    }
}


// MARK: - Memories Display Mode
enum MemoriesDisplayMode: String, CaseIterable, Identifiable {
    case list = "List"
    case map = "Map"
    var id: String { rawValue }
}

func categoryIcon(for category: String) -> String {
    let lower = category.lowercased()
    if lower == "all" {
        return "sparkles"
    } else if lower.contains("food") || lower.contains("restaurant") || lower.contains("eat") || lower.contains("dinner") {
        return "fork.knife"
    } else if lower.contains("coffee") || lower.contains("cafe") || lower.contains("tea") {
        return "cup.and.saucer.fill"
    } else if lower.contains("drink") || lower.contains("bar") || lower.contains("cocktail") {
        return "wineglass.fill"
    } else if lower.contains("travel") || lower.contains("hotel") || lower.contains("flight") {
        return "airplane"
    } else if lower.contains("book") || lower.contains("art") || lower.contains("read") {
        return "books.vertical.fill"
    } else if lower.contains("place") {
        return "mappin.and.ellipse"
    } else if lower.contains("note") {
        return "note.text"
    } else if lower.contains("shop") || lower.contains("store") || lower.contains("market") {
        return "bag.fill"
    } else if lower.contains("nature") || lower.contains("park") || lower.contains("outdoor") {
        return "leaf.fill"
    } else {
        return "tag.fill"
    }
}

// MARK: - App MemoriesView
struct MemoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var memories: [MemoryItem]
    
    @State private var displayMode: MemoriesDisplayMode = .list
    @State private var selectedMapMemory: MemoryItem? = nil
    @State private var selectedMemoryID: UUID? = nil
    @State private var mapCameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var reminderForMemory: MemoryItem? = nil
    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var locationManager = LocationManager()
    @AppStorage("appTheme") private var appTheme = AppTheme.system
    
    var availableCategories: [String] {
        let memoryCategories = Array(Set(memories.map { $0.category })).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if memoryCategories.isEmpty {
            return ["All", "Food & Drink", "Cafe", "Travel", "Places", "Notes"]
        }
        return ["All"] + memoryCategories.sorted()
    }
    
    func countForCategory(_ cat: String) -> Int {
        if cat == "All" {
            return memories.count
        }
        return memories.filter { $0.category.localizedCaseInsensitiveCompare(cat) == .orderedSame }.count
    }
    
    var nearbyMemory: MemoryItem? {
        guard let currentLoc = locationManager.location else { return nil }
        // Find the first memory within ~200 meters
        return memories.first { memory in
            guard let lat = memory.latitude, let lot = memory.longitude else { return false }
            let memLoc = CLLocation(latitude: lat, longitude: lot)
            let distance = currentLoc.distance(from: memLoc)
            return distance < 200
        }
    }
    
    var filteredMemories: [MemoryItem] {
        memories.filter { memory in
            if selectedCategory != "All" {
                guard memory.category.localizedCaseInsensitiveCompare(selectedCategory) == .orderedSame else {
                    return false
                }
            }
            let query = searchText.trimmingCharacters(in: .whitespaces)
            if !query.isEmpty {
                let matchesTitle = memory.title.localizedCaseInsensitiveContains(query)
                let matchesDetails = memory.details.localizedCaseInsensitiveContains(query)
                let matchesCategory = memory.category.localizedCaseInsensitiveContains(query)
                let matchesLocation = memory.locationName?.localizedCaseInsensitiveContains(query) ?? false
                guard matchesTitle || matchesDetails || matchesCategory || matchesLocation else {
                    return false
                }
            }
            return true
        }
    }
    
    var activeMemory: MemoryItem? {
        if let id = selectedMemoryID, let match = memories.first(where: { $0.id == id }) {
            return match
        }
        return nearbyMemory ?? filteredMemories.first ?? memories.first
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
            .navigationTitle("Memories")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search memories...")
            #else
            .searchable(text: $searchText, prompt: "Search memories...")
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gear")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if horizontalSizeClass != .regular {
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    displayMode = .list
                                }
                            } label: {
                                Image(systemName: "rectangle.grid.1x2")
                                    .font(.caption.bold())
                                    .foregroundColor(displayMode == .list ? .white : .primary)
                                    .frame(width: 32, height: 28)
                                    .background(displayMode == .list ? Color.accentColor : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    displayMode = .map
                                }
                            } label: {
                                Image(systemName: "map")
                                    .font(.caption.bold())
                                    .foregroundColor(displayMode == .map ? .white : .primary)
                                    .frame(width: 32, height: 28)
                                    .background(displayMode == .map ? Color.accentColor : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(2)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    
                    Button(action: { showingAddSheet = true }) {
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
                ToolbarItemGroup(placement: .primaryAction) {
                    if horizontalSizeClass != .regular {
                        HStack(spacing: 0) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    displayMode = .list
                                }
                            } label: {
                                Image(systemName: "rectangle.grid.1x2")
                                    .font(.caption.bold())
                                    .foregroundColor(displayMode == .list ? .white : .primary)
                                    .frame(width: 32, height: 28)
                                    .background(displayMode == .list ? Color.accentColor : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    displayMode = .map
                                }
                            } label: {
                                Image(systemName: "map")
                                    .font(.caption.bold())
                                    .foregroundColor(displayMode == .map ? .white : .primary)
                                    .frame(width: 32, height: 28)
                                    .background(displayMode == .map ? Color.accentColor : Color.clear)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(2)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                }
                #endif
            }
            .sheet(isPresented: $showingAddSheet) {
                AddMemoryView()
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
            .sheet(item: $reminderForMemory) { memory in
                AddReminderSheet(
                    initialTitle: memory.latitude != nil ? "Visit \(memory.title)" : "Follow up on \(memory.title)",
                    initialLocationName: memory.locationName ?? memory.title,
                    initialLatitude: memory.latitude,
                    initialLongitude: memory.longitude,
                    initialLinkedMemoryTitle: memory.title
                )
            }
        }
    }
    
    // MARK: - Compact Phone / Cover Screen View
    @ViewBuilder
    private var compactView: some View {
        if displayMode == .map {
            VStack(spacing: 0) {
                filterCapsulePicker
                mapContentView
            }
        } else if memories.isEmpty && searchText.isEmpty {
            emptyStateView
        } else {
            VStack(spacing: 0) {
                filterCapsulePicker
                
                if filteredMemories.isEmpty {
                    ContentUnavailableView.search(text: searchText.isEmpty ? selectedCategory : searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            if let hero = nearbyMemory,
                               searchText.trimmingCharacters(in: .whitespaces).isEmpty &&
                               (selectedCategory == "All" || hero.category.localizedCaseInsensitiveCompare(selectedCategory) == .orderedSame) {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                        Text("Nearby Memory")
                                    }
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal)
                                    
                                    MemoryCard(memory: hero)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.white.opacity(0.8), lineWidth: 3)
                                        )
                                }
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                            }
                            
                            ForEach(filteredMemories) { memory in
                                if memory.id != nearbyMemory?.id ||
                                   !searchText.trimmingCharacters(in: .whitespaces).isEmpty ||
                                   (selectedCategory != "All" && nearbyMemory?.category.localizedCaseInsensitiveCompare(selectedCategory) != .orderedSame) {
                                    MemoryCard(memory: memory)
                                }
                            }
                        }
                        .padding()
                    }
                }
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
                // Portrait Pose (Duo & iPad): Map at top, Cards list at bottom (Equal 50/50 vertical split)
                let halfHeight = max(200, (geometry.size.height - 12 - 8) / 2)
                VStack(spacing: 12) {
                    mapContentView
                        .frame(height: halfHeight)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .padding(.horizontal, 16)
                    
                    cardsListView
                        .frame(height: halfHeight)
                }
                .padding(.top, 4)
            } else {
                // Landscape Pose: Side by Side (Equal 50/50 horizontal split)
                HStack(alignment: .top, spacing: isPad ? 20 : 24) {
                    cardsListView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    VStack(spacing: 0) {
                        mapContentView
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .padding(.vertical, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    // Left / Bottom Pane (Memory Cards Feed)
    private var cardsListView: some View {
        VStack(spacing: 0) {
            filterCapsulePicker
            
            if memories.isEmpty && searchText.isEmpty {
                emptyStateView
                    .padding(.horizontal, 16)
            } else if filteredMemories.isEmpty {
                ContentUnavailableView.search(text: searchText.isEmpty ? selectedCategory : searchText)
                    .padding(.horizontal, 16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if let hero = nearbyMemory,
                           searchText.trimmingCharacters(in: .whitespaces).isEmpty &&
                           (selectedCategory == "All" || hero.category.localizedCaseInsensitiveCompare(selectedCategory) == .orderedSame) {
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Image(systemName: "location.fill")
                                    Text("Nearby Memory")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 4)
                                
                                MemoryCard(memory: hero)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(activeMemory?.id == hero.id ? Color.accentColor : Color.white.opacity(0.8), lineWidth: 3)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectMemory(hero)
                                    }
                            }
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                        }
                        
                        ForEach(filteredMemories) { memory in
                            if memory.id != nearbyMemory?.id ||
                               !searchText.trimmingCharacters(in: .whitespaces).isEmpty ||
                               (selectedCategory != "All" && nearbyMemory?.category.localizedCaseInsensitiveCompare(selectedCategory) != .orderedSame) {
                                MemoryCard(memory: memory)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(activeMemory?.id == memory.id ? Color.accentColor : Color.clear, lineWidth: 2.5)
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectMemory(memory)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
    }
    
    // MARK: - Category Filter Picker
    private var filterCapsulePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories, id: \.self) { category in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: categoryIcon(for: category))
                            Text(category)
                            
                            let count = countForCategory(category)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(selectedCategory == category ? Color.white.opacity(0.3) : Color.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .font(.subheadline.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedCategory == category ? Color.accentColor : Color.primary.opacity(0.08))
                        .foregroundColor(selectedCategory == category ? .white : .primary)
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
                    .init(color: .black, location: 0.96),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    private func selectMemory(_ memory: MemoryItem) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            selectedMemoryID = memory.id
            selectedMapMemory = memory
            if let lat = memory.latitude, let lon = memory.longitude {
                mapCameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                    span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                ))
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Memories Yet", systemImage: "sparkles")
        } description: {
            Text("Save places you love, great meals, and personal notes.")
        } actions: {
            Button("Add Memory") {
                showingAddSheet = true
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(20)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
    }
    
    private var mapContentView: some View {
        ZStack(alignment: .bottom) {
            Map(position: $mapCameraPosition) {
                UserAnnotation()
                
                ForEach(filteredMemories.filter { $0.latitude != nil && $0.longitude != nil }) { memory in
                    Annotation(memory.title, coordinate: CLLocationCoordinate2D(latitude: memory.latitude!, longitude: memory.longitude!)) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                selectedMapMemory = memory
                                selectedMemoryID = memory.id
                            }
                        } label: {
                            VStack(spacing: 0) {
                                Image(systemName: categoryIcon(for: memory.category))
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(selectedMapMemory?.id == memory.id ? Color.accentColor : Color.purple)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                    .shadow(radius: 4)
                                
                                Image(systemName: "triangle.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(selectedMapMemory?.id == memory.id ? Color.accentColor : Color.purple)
                                    .rotationEffect(.degrees(180))
                                    .offset(y: -2)
                            }
                        }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            
            if filteredMemories.filter({ $0.latitude != nil && $0.longitude != nil }).isEmpty {
                ContentUnavailableView(
                    "No Locations on Map",
                    systemImage: "map",
                    description: Text("Memories with saved places or restaurants will appear as pins here.")
                )
                .padding(20)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(16)
                .padding(.bottom, 34)
            } else if let selected = selectedMapMemory {
                MemoryMapCard(
                    memory: selected,
                    onDismiss: {
                        withAnimation { selectedMapMemory = nil }
                    },
                    onAddReminder: {
                        reminderForMemory = selected
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(16)
            }
        }
    }
}


// MARK: - MemoryDetailPane (iPhone Duo / Large Screen Canvas)
struct MemoryDetailPane: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var memory: MemoryItem
    var onAddReminder: () -> Void
    @State private var showingEditSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(memory.title)
                            .font(.title2.bold())
                            .foregroundColor(.primary)
                        
                        Text(memory.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Image(systemName: categoryIcon(for: memory.category))
                        Text(memory.category)
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.18))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())
                }
                
                // Photo
                if let photoData = memory.photoData {
                    #if canImport(UIKit)
                    if let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    #elseif canImport(AppKit)
                    if let nsImage = NSImage(data: photoData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    #endif
                }
                
                // Map preview
                if let lat = memory.latitude, let lot = memory.longitude, let locName = memory.locationName {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.purple)
                            Text(locName)
                                .font(.subheadline.bold())
                            Spacer()
                        }
                        
                        let position = MapCameraPosition.region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lot), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                        Map(position: .constant(position)) {
                            Marker(locName, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lot))
                        }
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        HStack(spacing: 12) {
                            Button {
                                let location = CLLocation(latitude: lat, longitude: lot)
                                let mapItem = MKMapItem(location: location, address: nil)
                                mapItem.name = locName
                                mapItem.openInMaps()
                            } label: {
                                HStack(spacing: 5) {
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
                            
                            Button(action: onAddReminder) {
                                HStack(spacing: 5) {
                                    Image(systemName: "bell.badge")
                                    Text("Remind Here")
                                }
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.accentColor.opacity(0.15))
                                .foregroundColor(.accentColor)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                } else if let locName = memory.locationName {
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                        Text(locName)
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.secondary)
                }
                
                // Details / Notes
                if !memory.details.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notes")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        Text(memory.details)
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Ratings
                if !memory.ratings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ratings")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        ForEach(memory.ratings, id: \.self) { rating in
                            HStack {
                                Text(rating.subject)
                                    .font(.subheadline)
                                Spacer()
                                HStack(spacing: 3) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating.score ? "star.fill" : "star")
                                            .foregroundColor(star <= rating.score ? .yellow : .gray.opacity(0.3))
                                            .font(.caption)
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding()
                    .background(Color.primary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                
                // Actions (Edit / Delete)
                HStack(spacing: 12) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "pencil")
                            Text("Edit Memory")
                        }
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.primary.opacity(0.08))
                        .foregroundColor(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    
                    Button(role: .destructive) {
                        let context = memory.modelContext
                        context?.delete(memory)
                        try? context?.save()
                    } label: {
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
        .sheet(isPresented: $showingEditSheet) {
            EditMemoryView(memory: memory)
        }
    }
}


// MARK: - MemoryMapCard
struct MemoryMapCard: View {
    @Bindable var memory: MemoryItem
    var onDismiss: () -> Void
    var onAddReminder: () -> Void
    @State private var showingEditSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .font(.headline)
                    if let locName = memory.locationName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                            Text(locName)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Text(memory.category)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(Capsule())
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            
            if !memory.details.isEmpty {
                Text(memory.details)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.primary)
            }
            
            HStack(spacing: 12) {
                if let lat = memory.latitude, let lon = memory.longitude {
                    Button {
                        let location = CLLocation(latitude: lat, longitude: lon)
                        let mapItem = MKMapItem(location: location, address: nil)
                        mapItem.name = memory.locationName ?? memory.title
                        mapItem.openInMaps()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                            Text("Directions")
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: onAddReminder) {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge")
                        Text("Remind Here")
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.15))
                    .foregroundColor(.accentColor)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption.bold())
                        .padding(6)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 8)
        .sheet(isPresented: $showingEditSheet) {
            EditMemoryView(memory: memory)
        }
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme = AppTheme.system
    @Query private var allMemories: [MemoryItem]
    @Query private var allReminders: [ReminderItem]
    
    @State private var showingExportSheet = false
    @State private var showingFileImporter = false
    @State private var importSummary: ImportSummary? = nil
    @State private var showingImportSuccessAlert = false
    @State private var importErrorMessage: String? = nil
    @State private var showingImportErrorAlert = false
    @State private var showingSampleDataAlert = false
    @State private var sampleDataAlertMessage = ""
    @State private var showingClearSampleDataAlert = false
    @State private var showingWelcomeTourSheet = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $appTheme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section(header: Text("Data & Backup")) {
                    Button {
                        showingExportSheet = true
                    } label: {
                        HStack {
                            Label("Export & Backup All Data", systemImage: "arrow.down.doc")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        showingFileImporter = true
                    } label: {
                        HStack {
                            Label("Import & Restore Backup", systemImage: "square.and.arrow.down")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        let result = SampleDataLoader.loadSampleData(into: modelContext)
                        if result.memoriesAdded == 0 && result.remindersAdded == 0 {
                            sampleDataAlertMessage = "Sample data is already present. No duplicate cards were added."
                        } else {
                            sampleDataAlertMessage = "Added \(result.memoriesAdded) sample memories and \(result.remindersAdded) sample reminders. Widgets and search have been updated."
                        }
                        showingSampleDataAlert = true
                    } label: {
                        HStack {
                            Label("Load Curated Sample Data", systemImage: "sparkles")
                                .foregroundColor(.purple)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        showingClearSampleDataAlert = true
                    } label: {
                        HStack {
                            Label("Start Fresh (Remove Sample Data)", systemImage: "trash")
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        showingWelcomeTourSheet = true
                    } label: {
                        HStack {
                            Label("Welcome & Feature Tour", systemImage: "hand.wave")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section(header: Text("Features")) {
                    HStack {
                        Label("Memories & Places", systemImage: "sparkles")
                        Spacer()
                        Text("Location Aware")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Label("Day to Day Reminders", systemImage: "checklist")
                        Spacer()
                        Text("Smart Alerts")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("About Mepo")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("App Icon")
                        Spacer()
                        Text("Liquid Glass")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #else
            .padding(.top)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                FullDataExportSheet(memories: allMemories, reminders: allReminders)
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
            .alert("Backup Restored", isPresented: $showingImportSuccessAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let s = importSummary {
                    Text("Successfully imported \(s.importedMemories) memories and \(s.importedReminders) reminders.\(s.updatedMemories + s.updatedReminders > 0 ? " Updated \(s.updatedMemories + s.updatedReminders) existing items." : "")")
                } else {
                    Text("Your backup data has been successfully restored.")
                }
            }
            .alert("Import Failed", isPresented: $showingImportErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importErrorMessage ?? "Unable to read or parse the selected backup file.")
            }
            .sheet(isPresented: $showingWelcomeTourSheet) {
                WelcomeOnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
            .alert("Sample Data", isPresented: $showingSampleDataAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(sampleDataAlertMessage)
            }
            .alert("Start Fresh?", isPresented: $showingClearSampleDataAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove Sample Data", role: .destructive) {
                    let result = SampleDataLoader.clearSampleData(from: modelContext)
                    sampleDataAlertMessage = "Removed \(result.memoriesRemoved) sample memories and \(result.remindersRemoved) sample reminders. Your custom items were kept untouched."
                    showingSampleDataAlert = true
                }
            } message: {
                Text("This will remove all curated sample memories and reminders, leaving any personal items you created completely safe.")
            }
        }
    }
    
    private func handleFileImport(result: Result<[URL], Error>) {
        do {
            guard let selectedURL = try result.get().first else { return }
            let summary = try FullDataBackupImporter.importJSON(from: selectedURL, modelContext: modelContext)
            
            let freshMemories = (try? modelContext.fetch(FetchDescriptor<MemoryItem>())) ?? []
            let freshReminders = (try? modelContext.fetch(FetchDescriptor<ReminderItem>())) ?? []
            SpotlightManager.shared.indexMemories(freshMemories)
            for r in freshReminders {
                SpotlightManager.shared.indexReminder(r)
                if !r.isCompleted, let due = r.dueDate, due > Date() {
                    Task {
                        await NotificationManager.shared.scheduleNotification(for: r)
                    }
                }
            }
            
            self.importSummary = summary
            self.showingImportSuccessAlert = true
        } catch {
            self.importErrorMessage = error.localizedDescription
            self.showingImportErrorAlert = true
        }
    }
}

// MARK: - MemoryCard
struct MemoryCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var memory: MemoryItem
    @State private var showingEditSheet = false
    @State private var showingAddReminderSheet = false
    @State private var showingShareSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            HStack {
                Text(memory.title)
                    .font(.headline)
                    .layoutPriority(1)
                Spacer()
                Text(memory.category)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.2))
                    .clipShape(Capsule())
            }
            
            if let lat = memory.latitude, let lot = memory.longitude, let locName = memory.locationName {
                let position = MapCameraPosition.region(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lot), span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)))
                Map(position: .constant(position)) {
                    Marker(locName, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lot))
                }
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .allowsHitTesting(false)
                .onTapGesture {
                    let location = CLLocation(latitude: lat, longitude: lot)
                    let mapItem = MKMapItem(location: location, address: nil)
                    mapItem.name = locName
                    mapItem.openInMaps()
                }
            } else if let locName = memory.locationName {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    Text(locName)
                }
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
            }
            
            if let photoData = memory.photoData {
                #if canImport(UIKit)
                if let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: photoData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                #endif
            }
            
            Text(memory.details)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            if !memory.ratings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(memory.ratings, id: \.self) { rating in
                        HStack {
                            Text(rating.subject)
                                .font(.callout)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: star <= rating.score ? "star.fill" : "star")
                                        .foregroundColor(star <= rating.score ? .yellow : .gray.opacity(0.4))
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color.primary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            
            HStack {
                Text(memory.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    showingShareSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                Button {
                    showingAddReminderSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bell.badge")
                        Text(memory.latitude != nil ? "Remind Here" : "Remind")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .hoverEffect(.highlight)
        .contextMenu {
            Button {
                showingShareSheet = true
            } label: {
                Label("Share & Export Memory", systemImage: "square.and.arrow.up")
            }
            
            Button {
                showingAddReminderSheet = true
            } label: {
                Label(memory.latitude != nil ? "Remind Me When I'm Here" : "Add Related Reminder", systemImage: "bell.badge")
            }
            
            Button {
                showingEditSheet = true
            } label: {
                Label("Edit Memory", systemImage: "pencil")
            }
            
            Button(role: .destructive) {
                let context = memory.modelContext
                context?.delete(memory)
                try? context?.save()
            } label: {
                Label("Delete Memory", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            MemoryShareSheet(memory: memory)
        }
        .sheet(isPresented: $showingEditSheet) {
            EditMemoryView(memory: memory)
        }
        .sheet(isPresented: $showingAddReminderSheet) {
            AddReminderSheet(
                initialTitle: memory.latitude != nil ? "Visit \(memory.title)" : "Follow up on \(memory.title)",
                initialLocationName: memory.locationName ?? memory.title,
                initialLatitude: memory.latitude,
                initialLongitude: memory.longitude,
                initialLinkedMemoryTitle: memory.title
            )
        }
    }
}

// MARK: - EditMemoryView
struct EditMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var memory: MemoryItem
    
    @State private var title: String = ""
    @State private var details: String = ""
    @State private var selectedCategory: String = "Notes"
    
    // Photo
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    
    // Location
    @State private var locationManager = LocationManager()
    @State private var attachedLocationName: String? = nil
    @State private var attachedLatitude: Double? = nil
    @State private var attachedLongitude: Double? = nil
    @State private var isTaggingLocation: Bool = false
    @State private var showingPlaceSearch: Bool = false
    @State private var placeSearchQuery: String = ""
    @State private var placeSearchResults: [MKMapItem] = []
    
    // Ratings
    @State private var ratings: [MemoryRating] = []
    @State private var newRatingScore: Int = 0
    @State private var newRatingSubject: String = ""
    
    private let categoryOptions = [
        "Food & Drink",
        "Cafe",
        "Travel",
        "Places",
        "Notes"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title Input
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Title")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                            DictationButton(text: $title)
                        }
                        
                        TextField("Title", text: $title)
                            .font(.headline)
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Category Chips
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Category")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(categoryOptions, id: \.self) { cat in
                                    Button {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            selectedCategory = cat
                                        }
                                    } label: {
                                        Text(cat)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(selectedCategory == cat ? Color.accentColor : Color.primary.opacity(0.06))
                                            .foregroundColor(selectedCategory == cat ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // Details Editor
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Details & Memories")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                            DictationButton(text: $details)
                        }
                        
                        TextEditor(text: $details)
                            .font(.body)
                            .frame(minHeight: 110)
                            .padding(10)
                            .scrollContentBackground(.hidden)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    
                    // Photo Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Photo")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        if let photoData, let uiImage = UIImage(data: photoData) {
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 180)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                Button {
                                    self.photoData = nil
                                    self.selectedPhoto = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                        .shadow(radius: 4)
                                        .padding(8)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                HStack(spacing: 8) {
                                    Image(systemName: "camera.badge.ellipsis")
                                        .font(.title3)
                                        .foregroundColor(.accentColor)
                                    Text("Add Photo to Memory")
                                        .font(.subheadline.weight(.medium))
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Location Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        if let locName = attachedLocationName {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(locName)
                                        .font(.subheadline.bold())
                                    Text("Tagged to this memory")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button {
                                    attachedLocationName = nil
                                    attachedLatitude = nil
                                    attachedLongitude = nil
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        } else {
                            HStack(spacing: 10) {
                                Button {
                                    tagCurrentLocation()
                                } label: {
                                    HStack(spacing: 6) {
                                        if isTaggingLocation {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                        } else {
                                            Image(systemName: "location.fill")
                                                .foregroundColor(.purple)
                                        }
                                        Text("Current Location")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .disabled(isTaggingLocation)
                                
                                Button {
                                    withAnimation { showingPlaceSearch.toggle() }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.blue)
                                        Text("Search Place")
                                            .font(.subheadline.weight(.medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(.ultraThinMaterial)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            if showingPlaceSearch {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                            .foregroundColor(.secondary)
                                        TextField("Type place or restaurant name...", text: $placeSearchQuery)
                                            .textFieldStyle(.plain)
                                            .onSubmit { searchPlace() }
                                        if !placeSearchQuery.isEmpty {
                                            Button {
                                                placeSearchQuery = ""
                                                placeSearchResults = []
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundColor(.secondary)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(10)
                                    .background(Color.primary.opacity(0.05))
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    
                                    ForEach(placeSearchResults.prefix(3), id: \.self) { item in
                                        Button {
                                            attachedLocationName = item.name ?? placeSearchQuery
                                            attachedLatitude = item.location.coordinate.latitude
                                            attachedLongitude = item.location.coordinate.longitude
                                            showingPlaceSearch = false
                                            placeSearchResults = []
                                            placeSearchQuery = ""
                                        } label: {
                                            HStack {
                                                Image(systemName: "mappin")
                                                    .foregroundColor(.purple)
                                                Text(item.name ?? "Place")
                                                    .font(.subheadline)
                                                    .foregroundColor(.primary)
                                                Spacer()
                                            }
                                            .padding(.vertical, 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                        }
                    }
                    
                    // Ratings Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Ratings")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                        
                        VStack(spacing: 8) {
                            ForEach(ratings.indices, id: \.self) { idx in
                                HStack {
                                    Text(ratings[idx].subject)
                                        .font(.subheadline)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        ForEach(1...5, id: \.self) { star in
                                            Image(systemName: star <= ratings[idx].score ? "star.fill" : "star")
                                                .font(.caption)
                                                .foregroundColor(star <= ratings[idx].score ? .yellow : .gray.opacity(0.4))
                                        }
                                    }
                                    Button {
                                        ratings.remove(at: idx)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.caption)
                                            .foregroundColor(.red.opacity(0.8))
                                            .padding(.leading, 6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 2)
                            }
                            
                            Divider()
                            
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Button {
                                        newRatingScore = (newRatingScore == star) ? 0 : star
                                    } label: {
                                        Image(systemName: star <= newRatingScore ? "star.fill" : "star")
                                            .font(.title3)
                                            .foregroundColor(star <= newRatingScore ? .yellow : .gray.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Spacer()
                                
                                if newRatingScore > 0 {
                                    TextField("Item name", text: $newRatingSubject)
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color.primary.opacity(0.05))
                                        .cornerRadius(6)
                                        .frame(maxWidth: 120)
                                    
                                    Button("Add") {
                                        let subj = newRatingSubject.trimmingCharacters(in: .whitespacesAndNewlines)
                                        ratings.append(MemoryRating(subject: subj.isEmpty ? "Rating" : subj, score: newRatingScore))
                                        newRatingScore = 0
                                        newRatingSubject = ""
                                    }
                                    .font(.caption.bold())
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    
                    // Delete Button
                    Button(role: .destructive) {
                        modelContext.delete(memory)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Memory", systemImage: "trash")
                            Spacer()
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                }
                .padding()
            }
            .background {
                LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .navigationTitle("Edit Memory")
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
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                title = memory.title
                details = memory.details
                selectedCategory = memory.category
                photoData = memory.photoData
                attachedLocationName = memory.locationName
                attachedLatitude = memory.latitude
                attachedLongitude = memory.longitude
                ratings = memory.ratings
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                        }
                    }
                }
            }
        }
    }
    
    private func tagCurrentLocation() {
        guard let loc = locationManager.location else { return }
        isTaggingLocation = true
        Task {
            let placeName = await LocationManager.reverseGeocode(location: loc)
            await MainActor.run {
                attachedLocationName = placeName ?? "Current Location"
                attachedLatitude = loc.coordinate.latitude
                attachedLongitude = loc.coordinate.longitude
                isTaggingLocation = false
            }
        }
    }
    
    private func searchPlace() {
        guard !placeSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            let items = await LocationManager.searchPlaces(query: placeSearchQuery, near: locationManager.location)
            await MainActor.run {
                placeSearchResults = items
            }
        }
    }
    
    private func saveChanges() {
        memory.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        memory.category = selectedCategory
        memory.photoData = photoData
        memory.locationName = attachedLocationName
        memory.latitude = attachedLatitude
        memory.longitude = attachedLongitude
        memory.ratings = ratings
        try? modelContext.save()
        dismiss()
    }
}


// MARK: - AddMemoryView
struct AddMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var freeformText: String = ""
    @State private var selectedCategory: String = "Auto"
    
    // Photo
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    
    // Location
    @State private var locationManager = LocationManager()
    @State private var attachedLocationName: String? = nil
    @State private var attachedLatitude: Double? = nil
    @State private var attachedLongitude: Double? = nil
    @State private var isTaggingLocation: Bool = false
    @State private var showingPlaceSearch: Bool = false
    @State private var placeSearchQuery: String = ""
    @State private var placeSearchResults: [MKMapItem] = []
    
    // Star Rating (Optional)
    @State private var manualRatingScore: Int = 0
    @State private var manualRatingSubject: String = ""
    
    // Processing state
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    
    private let inspirationStarters = [
        ("🍽️ Dinner at", "Dinner at "),
        ("☕️ Great coffee at", "Great coffee at "),
        ("🍷 Cocktails at", "Cocktails at "),
        ("🥐 Pastry from", "Pastry from "),
        ("🗺️ Visited", "Visited "),
        ("💡 Note to self", "Remember to ")
    ]
    
    private let categoryOptions = [
        "Auto",
        "Food & Drink",
        "Cafe",
        "Travel",
        "Places",
        "Notes"
    ]
    
    var body: some View {
        NavigationStack {
            Group {
                if horizontalSizeClass == .regular {
                    HStack(alignment: .top, spacing: 28) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                photoSection
                                locationSection
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity)
                        
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                inspirationSection
                                thoughtInputSection
                                categorySection
                                ratingSection
                                saveButtonSection
                            }
                            .padding()
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 12)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            inspirationSection
                            thoughtInputSection
                            categorySection
                            photoSection
                            locationSection
                            ratingSection
                            saveButtonSection
                        }
                        .padding()
                    }
                }
            }
            .background {
                LinearGradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .navigationTitle("New Memory")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        await MainActor.run {
                            photoData = data
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Subviews for iPhone Duo Adaptability
    private var inspirationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inspiration")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(inspirationStarters, id: \.0) { starter in
                        Button {
                            if freeformText.isEmpty {
                                freeformText = starter.1
                            } else {
                                freeformText += " " + starter.1
                            }
                            if starter.1.contains("Dinner") || starter.1.contains("Pastry") {
                                selectedCategory = "Food & Drink"
                            } else if starter.1.contains("coffee") {
                                selectedCategory = "Cafe"
                            } else if starter.1.contains("Visited") {
                                selectedCategory = "Travel"
                            }
                        } label: {
                            Text(starter.0)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.primary.opacity(0.06))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var thoughtInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("What's on your mind?")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                DictationButton(text: $freeformText)
            }
            
            ZStack(alignment: .topLeading) {
                if freeformText.isEmpty {
                    Text("What did you eat, where did you go, or what do you want to remember? Mention ratings like 5/5 stars or dishes...")
                        .font(.body)
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                
                TextEditor(text: $freeformText)
                    .font(.body)
                    .frame(minHeight: 110)
                    .padding(10)
                    .scrollContentBackground(.hidden)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
            
            if !freeformText.isEmpty {
                HStack {
                    Spacer()
                    Button("Clear") {
                        freeformText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Category")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categoryOptions, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedCategory = cat
                            }
                        } label: {
                            Text(cat)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(selectedCategory == cat ? Color.accentColor : Color.primary.opacity(0.06))
                                .foregroundColor(selectedCategory == cat ? .white : .primary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
    
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Photo")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            if let photoData, let uiImage = UIImage(data: photoData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    
                    Button {
                        self.photoData = nil
                        self.selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack(spacing: 8) {
                        Image(systemName: "camera.badge.ellipsis")
                            .font(.title3)
                            .foregroundColor(.accentColor)
                        Text("Add Photo to Memory")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Location")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            if let locName = attachedLocationName {
                HStack {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundColor(.purple)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(locName)
                            .font(.subheadline.bold())
                        Text("Tagged to this memory")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        attachedLocationName = nil
                        attachedLatitude = nil
                        attachedLongitude = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.purple.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            } else {
                HStack(spacing: 10) {
                    Button {
                        tagCurrentLocation()
                    } label: {
                        HStack(spacing: 6) {
                            if isTaggingLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.purple)
                            }
                            Text("Current Location")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isTaggingLocation)
                    
                    Button {
                        withAnimation { showingPlaceSearch.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.blue)
                            Text("Search Place")
                                .font(.subheadline.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
                
                if showingPlaceSearch {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            TextField("Type place or restaurant name...", text: $placeSearchQuery)
                                .textFieldStyle(.plain)
                                .onSubmit { searchPlace() }
                            if !placeSearchQuery.isEmpty {
                                Button {
                                    placeSearchQuery = ""
                                    placeSearchResults = []
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(10)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        
                        ForEach(placeSearchResults.prefix(3), id: \.self) { item in
                            Button {
                                attachedLocationName = item.name ?? placeSearchQuery
                                attachedLatitude = item.location.coordinate.latitude
                                attachedLongitude = item.location.coordinate.longitude
                                showingPlaceSearch = false
                                placeSearchResults = []
                                placeSearchQuery = ""
                            } label: {
                                HStack {
                                    Image(systemName: "mappin")
                                        .foregroundColor(.purple)
                                    Text(item.name ?? "Place")
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
    }
    
    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating (Optional)")
                .font(.caption.bold())
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        if manualRatingScore == star {
                            manualRatingScore = 0
                        } else {
                            manualRatingScore = star
                        }
                    } label: {
                        Image(systemName: star <= manualRatingScore ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundColor(star <= manualRatingScore ? .yellow : .gray.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
                
                if manualRatingScore > 0 {
                    TextField("Item (e.g. Pasta)", text: $manualRatingSubject)
                        .font(.caption)
                        .padding(8)
                        .background(Color.primary.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .frame(maxWidth: 160)
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
    
    private var saveButtonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: processMemory) {
                HStack(spacing: 8) {
                    if isProcessing {
                        ProgressView()
                            .tint(.white)
                        Text("Analyzing & Saving...")
                    } else {
                        Image(systemName: "sparkles")
                        Text("Save Memory")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(freeformText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
    }
    
    func tagCurrentLocation() {
        guard let loc = locationManager.location else { return }
        isTaggingLocation = true
        Task {
            let placeName = await LocationManager.reverseGeocode(location: loc)
            await MainActor.run {
                attachedLocationName = placeName ?? "Current Location"
                attachedLatitude = loc.coordinate.latitude
                attachedLongitude = loc.coordinate.longitude
                isTaggingLocation = false
            }
        }
    }
    
    func searchPlace() {
        guard !placeSearchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        Task {
            let items = await LocationManager.searchPlaces(query: placeSearchQuery, near: locationManager.location)
            await MainActor.run {
                placeSearchResults = items
            }
        }
    }
    
    func processMemory() {
        let cleaned = freeformText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let session = LanguageModelSession(model: .default)
                let prompt = "Extract the key information from this thought, including the exact name of the place if mentioned: '\(cleaned)'"
                
                let response = try await session.respond(to: prompt, generating: ExtractedMemory.self)
                let content = response.content
                
                var lat = attachedLatitude
                var lng = attachedLongitude
                var finalLocName = attachedLocationName ?? content.locationName
                
                if lat == nil, let loc = content.locationName, !loc.isEmpty {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = loc
                    let search = MKLocalSearch(request: request)
                    if let searchResponse = try? await search.start(),
                       let firstItem = searchResponse.mapItems.first {
                        let coord = firstItem.location.coordinate
                        lat = coord.latitude
                        lng = coord.longitude
                        if finalLocName == nil {
                            finalLocName = firstItem.name ?? loc
                        }
                    }
                }
                
                var memoryRatings = content.ratings.map { MemoryRating(subject: $0.subject, score: $0.score) }
                if manualRatingScore > 0 {
                    let subject = manualRatingSubject.trimmingCharacters(in: .whitespacesAndNewlines)
                    memoryRatings.insert(MemoryRating(subject: subject.isEmpty ? "Rating" : subject, score: manualRatingScore), at: 0)
                }
                
                let finalCategory = selectedCategory == "Auto" ? content.category : selectedCategory
                
                let newMemory = MemoryItem(
                    title: content.title.isEmpty ? cleaned : content.title,
                    details: content.details.isEmpty ? cleaned : content.details,
                    category: finalCategory,
                    locationName: finalLocName,
                    latitude: lat,
                    longitude: lng,
                    photoData: photoData,
                    ratings: memoryRatings
                )
                
                await MainActor.run {
                    modelContext.insert(newMemory)
                    try? modelContext.save()
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    var memoryRatings: [MemoryRating] = []
                    if manualRatingScore > 0 {
                        let subject = manualRatingSubject.trimmingCharacters(in: .whitespacesAndNewlines)
                        memoryRatings.append(MemoryRating(subject: subject.isEmpty ? "Rating" : subject, score: manualRatingScore))
                    }
                    
                    let finalCategory = selectedCategory == "Auto" ? "Note" : selectedCategory
                    
                    let newMemory = MemoryItem(
                        title: cleaned.components(separatedBy: "\n").first ?? cleaned,
                        details: cleaned,
                        category: finalCategory,
                        locationName: attachedLocationName,
                        latitude: attachedLatitude,
                        longitude: attachedLongitude,
                        photoData: photoData,
                        ratings: memoryRatings
                    )
                    modelContext.insert(newMemory)
                    try? modelContext.save()
                    isProcessing = false
                    dismiss()
                }
            }
        }
    }
}


// MARK: - Safe Preview State
@MainActor
let previewContainer: ModelContainer = {
    do {
        let container = try ModelContainer(for: MemoryItem.self, ReminderItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container
    } catch {
        fatalError("Failed to create container")
    }
}()

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
