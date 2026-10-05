import SwiftUI
import SwiftData
import FoundationModels
import MapKit
import PhotosUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - App ContentView
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryItem.createdAt, order: .reverse) private var memories: [MemoryItem]
    
    @State private var showingAddSheet = false
    @State private var showingSettingsSheet = false
    @State private var searchText = ""
    
    var filteredMemories: [MemoryItem] {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return memories
        }
        return memories.filter { memory in
            memory.title.localizedCaseInsensitiveContains(searchText) ||
            memory.details.localizedCaseInsensitiveContains(searchText) ||
            memory.category.localizedCaseInsensitiveContains(searchText) ||
            (memory.locationName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty && searchText.isEmpty {
                    ContentUnavailableView(
                        "No Memories Yet",
                        systemImage: "tray.fill",
                        description: Text("Tap the + button to add one.")
                    )
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
                    .padding()
                } else if filteredMemories.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredMemories) { memory in
                                MemoryCard(memory: memory)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background {
                LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
            }
            .navigationTitle("Mepo")
            .searchable(text: $searchText, prompt: "Search memories...")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gear")
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingSettingsSheet = true }) {
                        Image(systemName: "gear")
                    }
                }
                #endif
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddMemoryView()
            }
            .sheet(isPresented: $showingSettingsSheet) {
                SettingsView()
            }
        }
    }
}

// MARK: - SettingsView
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appTheme") private var appTheme = AppTheme.system
    
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
        }
    }
}

// MARK: - MemoryCard
struct MemoryCard: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var memory: MemoryItem
    @State private var showingEditSheet = false
    
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
                .cornerRadius(12)
                .allowsHitTesting(false)
                .onTapGesture {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lot)
                    let placemark = MKPlacemark(coordinate: coordinate)
                    let mapItem = MKMapItem(placemark: placemark)
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
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                #elseif canImport(AppKit)
                if let nsImage = NSImage(data: photoData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
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
                .cornerRadius(10)
            }
            
            Text(memory.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contextMenu {
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
        .sheet(isPresented: $showingEditSheet) {
            EditMemoryView(memory: memory)
        }
    }
}

// MARK: - EditMemoryView
struct EditMemoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var memory: MemoryItem
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Title", text: $memory.title)
                    TextField("Category", text: $memory.category)
                    TextEditor(text: $memory.details)
                        .frame(minHeight: 100)
                }
                
                Section("Location") {
                    TextField("Location Name", text: Binding(
                        get: { memory.locationName ?? "" },
                        set: { memory.locationName = $0.isEmpty ? nil : $0 }
                    ))
                }
            }
            .navigationTitle("Edit Memory")
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
        }
    }
}

// MARK: - AddMemoryView
struct AddMemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var freeformText: String = ""
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var photoData: Data? = nil
    
    @State private var isProcessing: Bool = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("What do you want to remember?")
                        .font(.title2.bold())
                        .padding(.top)
                    
                    TextField("Enter your thought here...", text: $freeformText, axis: .vertical)
                        .lineLimit(5...15)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                    
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(photoData == nil ? "Attach a Photo" : "Photo Attached!")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    photoData = data
                                }
                            }
                        }
                    }
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    Button(action: processMemory) {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        } else {
                            Text("Save Smartly")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 10)
                    .disabled(freeformText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    
                }
                .padding()
            }
            .navigationTitle("New Memory")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    func processMemory() {
        guard !freeformText.isEmpty else { return }
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let session = LanguageModelSession(model: .default)
                let prompt = "Extract the key information from this thought, including the exact name of the place if mentioned: '\(freeformText)'"
                
                let response = try await session.respond(to: prompt, generating: ExtractedMemory.self)
                let content = response.content
                
                var lat: Double? = nil
                var lng: Double? = nil
                
                if let locName = content.locationName, !locName.isEmpty {
                    let request = MKLocalSearch.Request()
                    request.naturalLanguageQuery = locName
                    let search = MKLocalSearch(request: request)
                    if let searchResponse = try? await search.start(),
                       let firstItem = searchResponse.mapItems.first {
                        let coord = firstItem.location.coordinate
                        lat = coord.latitude
                        lng = coord.longitude
                    }
                }
                
                let memoryRatings = content.ratings.map { MemoryRating(subject: $0.subject, score: $0.score) }
                
                let newMemory = MemoryItem(
                    title: content.title,
                    details: content.details,
                    category: content.category,
                    locationName: content.locationName,
                    latitude: lat,
                    longitude: lng,
                    photoData: photoData,
                    ratings: memoryRatings
                )
                
                await MainActor.run {
                    modelContext.insert(newMemory)
                    try? modelContext.save() // Force save
                    isProcessing = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    let newMemory = MemoryItem(
                        title: "Memory (Fallback)",
                        details: freeformText,
                        category: "Note",
                        photoData: photoData
                    )
                    modelContext.insert(newMemory)
                    try? modelContext.save() // Force save
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
        let container = try ModelContainer(for: MemoryItem.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return container
    } catch {
        fatalError("Failed to create container")
    }
}()

#Preview {
    ContentView()
        .modelContainer(previewContainer)
}
