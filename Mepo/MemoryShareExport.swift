import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Memory Export Card View
/// A high-fidelity, standalone card view styled specifically for image export and social sharing.
struct MemoryShareCardView: View {
    let memory: MemoryItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header: Mepo wordmark badge and category
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.purple)
                    Text("MEPO")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.purple)
                }
                Spacer()
                Text(memory.category)
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .foregroundColor(.purple)
                    .clipShape(Capsule())
            }
            
            // Photo if attached
            if let photoData = memory.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            
            // Title & Location
            VStack(alignment: .leading, spacing: 4) {
                Text(memory.title)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                
                if let loc = memory.locationName {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(loc)
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
            }
            
            // Memory Notes / Details
            if !memory.details.isEmpty {
                Text(memory.details)
                    .font(.body)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Ratings (e.g. food, drinks, vibe)
            if !memory.ratings.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(memory.ratings, id: \.self) { r in
                        HStack {
                            Text(r.subject)
                                .font(.subheadline)
                            Spacer()
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { s in
                                    Image(systemName: s <= r.score ? "star.fill" : "star")
                                        .font(.caption)
                                        .foregroundColor(s <= r.score ? .yellow : .gray.opacity(0.3))
                                }
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color.primary.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            
            Divider()
            
            // Footer with creation date & watermark
            HStack {
                Text(memory.createdAt, format: Date.FormatStyle(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Saved with Mepo")
                    .font(.caption2.weight(.medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 340)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
        )
    }
}

// MARK: - Memory Share Sheet
struct MemoryShareSheet: View {
    @Environment(\.dismiss) private var dismiss
    let memory: MemoryItem
    
    @State private var renderedUIImage: UIImage? = nil
    @State private var showCopiedAlert: Bool = false
    @State private var showSavedAlert: Bool = false
    
    var formattedText: String {
        memory.shareFormattedText
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Visual Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PREVIEW")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                        
                        MemoryShareCardView(memory: memory)
                            .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .padding(.top, 16)
                    
                    // Share Actions
                    VStack(spacing: 12) {
                        // Standard System Share Sheet (Image + Text)
                        if let img = renderedUIImage {
                            ShareLink(
                                item: Image(uiImage: img),
                                subject: Text(memory.title),
                                message: Text(formattedText),
                                preview: SharePreview(memory.title, image: Image(uiImage: img))
                            ) {
                                Label("Share Image & Details", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        } else {
                            ShareLink(
                                item: formattedText,
                                subject: Text(memory.title),
                                message: Text(formattedText)
                            ) {
                                Label("Share Memory Summary", systemImage: "square.and.arrow.up")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.purple)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button {
                                if let img = renderedUIImage {
                                    UIPasteboard.general.image = img
                                    showCopiedAlert = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "doc.on.doc")
                                    Text("Copy Image")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            
                            Button {
                                if let img = renderedUIImage {
                                    UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil)
                                    showSavedAlert = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.down.to.line.compact")
                                    Text("Save to Photos")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.secondary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Share Memory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Image Copied", isPresented: $showCopiedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Memory card image copied to your clipboard.")
            }
            .alert("Saved to Photos", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Memory card graphic has been saved to your Photo Library.")
            }
            .task {
                renderCard()
            }
        }
    }
    
    @MainActor
    private func renderCard() {
        let exportCard = MemoryShareCardView(memory: memory)
        let renderer = ImageRenderer(content: exportCard)
        renderer.scale = 3.0
        if let uiImg = renderer.uiImage {
            self.renderedUIImage = uiImg
        }
    }
}

// MARK: - Full Data Backup & Export Models
struct MepoBackupPayload: Codable, Sendable {
    var exportDate: Date
    var version: String
    var memories: [MepoBackupMemory]
    var reminders: [MepoBackupReminder]
}

struct MepoBackupMemory: Codable, Sendable {
    var id: String
    var title: String
    var details: String
    var category: String
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date
    var ratings: [MepoBackupRating]
    var hasPhoto: Bool
    var photoBase64: String?
}

struct MepoBackupRating: Codable, Sendable {
    var subject: String
    var score: Int
}

struct MepoBackupReminder: Codable, Sendable {
    var id: String
    var title: String
    var notes: String
    var dueDate: Date?
    var isCompleted: Bool
    var isImportant: Bool
    var recurrence: String
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
}

// MARK: - Full Data Backup Exporter
@MainActor
enum FullDataBackupExporter {
    static func createJSONExport(memories: [MemoryItem], reminders: [ReminderItem]) throws -> URL {
        let payload = MepoBackupPayload(
            exportDate: Date(),
            version: "1.0",
            memories: memories.map { m in
                MepoBackupMemory(
                    id: m.id.uuidString,
                    title: m.title,
                    details: m.details,
                    category: m.category,
                    locationName: m.locationName,
                    latitude: m.latitude,
                    longitude: m.longitude,
                    createdAt: m.createdAt,
                    ratings: m.ratings.map { MepoBackupRating(subject: $0.subject, score: $0.score) },
                    hasPhoto: m.photoData != nil,
                    photoBase64: m.photoData?.base64EncodedString()
                )
            },
            reminders: reminders.map { r in
                MepoBackupReminder(
                    id: r.id.uuidString,
                    title: r.title,
                    notes: r.notes,
                    dueDate: r.dueDate,
                    isCompleted: r.isCompleted,
                    isImportant: r.isImportant,
                    recurrence: r.recurrenceRaw,
                    locationName: r.locationName,
                    latitude: r.latitude,
                    longitude: r.longitude
                )
            }
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(payload)
        
        let filename = "Mepo_Backup_\(Date().formatted(Date.ISO8601FormatStyle().year().month().day())).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tempURL, options: .atomic)
        return tempURL
    }
    
    static func createMarkdownExport(memories: [MemoryItem], reminders: [ReminderItem]) throws -> URL {
        var md = "# Mepo Data Export\n\n"
        md += "*Exported on \(Date().formatted(date: .complete, time: .shortened))*\n\n"
        
        md += "## 📍 Memories (\(memories.count))\n\n"
        for m in memories {
            md += "### \(m.title)\n"
            md += "- **Category:** \(m.category)\n"
            md += "- **Date:** \(m.createdAt.formatted(date: .abbreviated, time: .shortened))\n"
            if let loc = m.locationName {
                md += "- **Location:** \(loc)\n"
            }
            if !m.details.isEmpty {
                md += "\n\(m.details)\n"
            }
            if !m.ratings.isEmpty {
                md += "\n**Ratings:**\n"
                for r in m.ratings {
                    let stars = String(repeating: "★", count: r.score) + String(repeating: "☆", count: max(0, 5 - r.score))
                    md += "- \(r.subject): \(stars) (\(r.score)/5)\n"
                }
            }
            md += "\n---\n\n"
        }
        
        md += "## 📝 Reminders (\(reminders.count))\n\n"
        let pending = reminders.filter { !$0.isCompleted }
        let completed = reminders.filter { $0.isCompleted }
        
        if !pending.isEmpty {
            md += "### Active Tasks\n"
            for r in pending {
                let priority = r.isImportant ? " ❗" : ""
                let due = r.dueDate != nil ? " (Due: \(r.dueDate!.formatted(date: .abbreviated, time: .shortened)))" : ""
                let loc = r.locationName != nil ? " [📍 \(r.locationName!)]" : ""
                md += "- [ ] **\(r.title)**\(priority)\(due)\(loc)\n"
                if !r.notes.isEmpty {
                    md += "  - \(r.notes)\n"
                }
            }
            md += "\n"
        }
        
        if !completed.isEmpty {
            md += "### Completed Tasks\n"
            for r in completed {
                md += "- [x] ~~\(r.title)~~\n"
            }
            md += "\n"
        }
        
        let filename = "Mepo_Notes_\(Date().formatted(Date.ISO8601FormatStyle().year().month().day())).md"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try md.data(using: .utf8)?.write(to: tempURL, options: .atomic)
        return tempURL
    }
}

// MARK: - Full Data Export Sheet
struct FullDataExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    let memories: [MemoryItem]
    let reminders: [ReminderItem]
    
    @State private var jsonURL: URL? = nil
    @State private var markdownURL: URL? = nil
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Summary Card
                VStack(spacing: 16) {
                    Image(systemName: "externaldrive.badge.icloud")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                        .padding(.top, 8)
                    
                    VStack(spacing: 4) {
                        Text("Export All Data")
                            .font(.title2.bold())
                        Text("Create a safe offline backup of all your personal memories and reminders.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(memories.count)")
                                .font(.title.bold())
                                .foregroundColor(.purple)
                            Text("Memories")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        VStack {
                            Text("\(reminders.count)")
                                .font(.title.bold())
                                .foregroundColor(.blue)
                            Text("Reminders")
                                .font(.caption.bold())
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .padding(.horizontal, 8)
                }
                .padding(20)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.horizontal, 20)
                
                // Export Buttons
                VStack(spacing: 12) {
                    if let mdURL = markdownURL {
                        ShareLink(item: mdURL) {
                            HStack {
                                Image(systemName: "doc.text")
                                Text("Share Markdown Notes (.md)")
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.indigo)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                    
                    if let jURL = jsonURL {
                        ShareLink(item: jURL) {
                            HStack {
                                Image(systemName: "arrow.down.doc")
                                Text("Share Full JSON Backup (.json)")
                                Spacer()
                                Image(systemName: "square.and.arrow.up")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                if let err = errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .navigationTitle("Data Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                do {
                    jsonURL = try FullDataBackupExporter.createJSONExport(memories: memories, reminders: reminders)
                    markdownURL = try FullDataBackupExporter.createMarkdownExport(memories: memories, reminders: reminders)
                } catch {
                    errorMessage = "Failed to prepare export: \(error.localizedDescription)"
                }
            }
        }
    }
}


// MARK: - Full Data Backup Importer
struct ImportSummary: Sendable, Equatable {
    var importedMemories: Int
    var updatedMemories: Int
    var importedReminders: Int
    var updatedReminders: Int
    
    var totalProcessed: Int {
        importedMemories + updatedMemories + importedReminders + updatedReminders
    }
}

@MainActor
enum FullDataBackupImporter {
    static func importJSON(from fileURL: URL, modelContext: ModelContext) throws -> ImportSummary {
        let didStartAccessing = fileURL.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }
        
        let data = try Data(contentsOf: fileURL)
        return try importJSONData(data, modelContext: modelContext)
    }
    
    static func importJSONData(_ data: Data, modelContext: ModelContext) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(MepoBackupPayload.self, from: data)
        
        let existingMemories = (try? modelContext.fetch(FetchDescriptor<MemoryItem>())) ?? []
        let existingReminders = (try? modelContext.fetch(FetchDescriptor<ReminderItem>())) ?? []
        
        var existingMemMap = [UUID: MemoryItem]()
        for m in existingMemories {
            existingMemMap[m.id] = m
        }
        
        var existingRemMap = [UUID: ReminderItem]()
        for r in existingReminders {
            existingRemMap[r.id] = r
        }
        
        var importedMem = 0
        var updatedMem = 0
        var importedRem = 0
        var updatedRem = 0
        
        for backupMem in payload.memories {
            guard let memUUID = UUID(uuidString: backupMem.id) else { continue }
            let photoData: Data? = backupMem.photoBase64.flatMap { Data(base64Encoded: $0) }
            let ratings = backupMem.ratings.map { MemoryRating(subject: $0.subject, score: $0.score) }
            
            if let existing = existingMemMap[memUUID] {
                existing.title = backupMem.title
                existing.details = backupMem.details
                existing.category = backupMem.category
                existing.locationName = backupMem.locationName
                existing.latitude = backupMem.latitude
                existing.longitude = backupMem.longitude
                if let photoData {
                    existing.photoData = photoData
                }
                existing.ratings = ratings
                existing.createdAt = backupMem.createdAt
                updatedMem += 1
            } else {
                let newMemory = MemoryItem(
                    id: memUUID,
                    title: backupMem.title,
                    details: backupMem.details,
                    category: backupMem.category,
                    locationName: backupMem.locationName,
                    latitude: backupMem.latitude,
                    longitude: backupMem.longitude,
                    photoData: photoData,
                    ratings: ratings,
                    createdAt: backupMem.createdAt
                )
                modelContext.insert(newMemory)
                existingMemMap[memUUID] = newMemory
                importedMem += 1
            }
        }
        
        for backupRem in payload.reminders {
            guard let remUUID = UUID(uuidString: backupRem.id) else { continue }
            let recurrence = ReminderRecurrence(rawValue: backupRem.recurrence) ?? .none
            
            if let existing = existingRemMap[remUUID] {
                existing.title = backupRem.title
                existing.notes = backupRem.notes
                existing.dueDate = backupRem.dueDate
                existing.isCompleted = backupRem.isCompleted
                existing.isImportant = backupRem.isImportant
                existing.recurrence = recurrence
                existing.locationName = backupRem.locationName
                existing.latitude = backupRem.latitude
                existing.longitude = backupRem.longitude
                updatedRem += 1
            } else {
                let newReminder = ReminderItem(
                    id: remUUID,
                    title: backupRem.title,
                    notes: backupRem.notes,
                    dueDate: backupRem.dueDate,
                    hasTime: backupRem.dueDate != nil,
                    isCompleted: backupRem.isCompleted,
                    isImportant: backupRem.isImportant,
                    recurrence: recurrence,
                    locationName: backupRem.locationName,
                    latitude: backupRem.latitude,
                    longitude: backupRem.longitude
                )
                modelContext.insert(newReminder)
                existingRemMap[remUUID] = newReminder
                importedRem += 1
            }
        }
        
        try modelContext.save()
        
        return ImportSummary(
            importedMemories: importedMem,
            updatedMemories: updatedMem,
            importedReminders: importedRem,
            updatedReminders: updatedRem
        )
    }
}
