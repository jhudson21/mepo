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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                LinearGradient(colors: [.blue.opacity(0.4), .purple.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()
                
                if memories.isEmpty {
                    VStack {
                        Spacer()
                        Image(systemName: "tray.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.7))
                            .glassEffect(.regular, in: Circle())
                            .padding()
                        Text("No Memories Yet")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                        Text("Tap the + button to add one.")
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(memories) { memory in
                                MemoryCard(memory: memory)
                            }
                            Color.clear.frame(height: 100)
                        }
                        .padding()
                    }
                }
                
                Button(action: { showingAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.title.bold())
                        .foregroundColor(.white)
                        .padding(24)
                        .glassEffect(.regular, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, 24)
            }
            .navigationTitle("Mepo")
            .sheet(isPresented: $showingAddSheet) {
                AddMemoryView()
            }
        }
    }
}

// MARK: - MemoryCard
struct MemoryCard: View {
    let memory: MemoryItem
    
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