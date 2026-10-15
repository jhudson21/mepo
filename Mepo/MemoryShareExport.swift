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
        var text = "\(memory.title) (\(memory.category))\n"
        if let loc = memory.locationName {
            text += "📍 \(loc)\n"
        }
        if !memory.details.isEmpty {
            text += "\n\(memory.details)\n"
        }
        if !memory.ratings.isEmpty {
            text += "\nRatings:\n"
            for r in memory.ratings {
                let stars = String(repeating: "★", count: r.score) + String(repeating: "☆", count: 5 - r.score)
                text += "• \(r.subject): \(stars) (\(r.score)/5)\n"
            }
        }
        text += "\n— Captured with Mepo"
        return text
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Visual Preview
                    MemoryShareCardView(memory: memory)
                        .padding(.vertical, 12)
                        .shadow(color: .black.opacity(0.12), radius: 14, x: 0, y: 6)
                    
                    // Action Buttons
                    VStack(spacing: 12) {
                        if let rendered = renderedUIImage {
                            ShareLink(
                                item: Image(uiImage: rendered),
                                preview: SharePreview(memory.title, image: Image(uiImage: rendered))
                            ) {
                                HStack {
                                    Image(systemName: "photo.badge.arrow.down")
                                    Text("Share Card Image")
                                }
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.purple)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            }
                        }
                        
                        ShareLink(
                            item: formattedText,
                            subject: Text(memory.title),
                            message: Text(formattedText)
                        ) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Text Summary")
                            }
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.secondary.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
