import Foundation
import SwiftData
import MapKit
import FoundationModels

@Generable(description: "A parsed task or reminder from user natural language")
struct ExtractedReminder {
    @Guide(description: "The core task description without date, recurrence or priority flags")
    var title: String
    
    @Guide(description: "Any optional additional notes or context")
    var notes: String?
    
    @Guide(description: "Whether the task is marked as urgent or important")
    var isImportant: Bool
    
    @Guide(description: "Recurrence: None, Daily, Weekly, or Monthly")
    var recurrence: String
    
    @Guide(description: "A location or place name mentioned in the task, if any")
    var locationName: String?
    
    @Guide(description: "Whether the reminder is triggered on arrival or departure: 'arrival', 'departure', or 'none'")
    var locationTrigger: String?
}

struct ParsedReminderResult {
    var title: String
    var notes: String
    var dueDate: Date?
    var isImportant: Bool
    var recurrence: ReminderRecurrence
    var locationName: String?
    var latitude: Double?
    var longitude: Double?
    var notifyOnArrival: Bool
    var notifyOnDeparture: Bool
    var linkedMemoryTitle: String?
}

enum ReminderAIParser {
    static func parse(text: String, existingMemories: [MemoryItem] = []) async -> ParsedReminderResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ParsedReminderResult(
                title: "",
                notes: "",
                dueDate: nil,
                isImportant: false,
                recurrence: .none,
                locationName: nil,
                latitude: nil,
                longitude: nil,
                notifyOnArrival: true,
                notifyOnDeparture: false,
                linkedMemoryTitle: nil
            )
        }
        
        // 1. Detect Date using NSDataDetector
        var detectedDate: Date? = nil
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let matches = detector.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
            if let firstDate = matches.first?.date {
                // If detected date is in past (e.g. "9am" earlier today), advance by 1 day if appropriate
                if firstDate < Date() && Calendar.current.isDateInToday(firstDate) {
                    detectedDate = Calendar.current.date(byAdding: .day, value: 1, to: firstDate)
                } else {
                    detectedDate = firstDate
                }
            }
        }
        
        // 2. Try FoundationModels for intelligent breakdown
        do {
            let session = LanguageModelSession(model: .default)
            let prompt = "Extract reminder fields from: '\(trimmed)'"
            let response = try await session.respond(to: prompt, generating: ExtractedReminder.self)
            let c = response.content
            
            let rec = ReminderRecurrence(rawValue: c.recurrence.capitalized) ?? .none
            var lat: Double? = nil
            var lon: Double? = nil
            var linkedTitle: String? = nil
            var locName = c.locationName
            
            if let loc = locName, !loc.isEmpty {
                // Check if it matches any of the user's saved memories
                if let match = existingMemories.first(where: {
                    $0.locationName?.localizedCaseInsensitiveContains(loc) == true ||
                    $0.title.localizedCaseInsensitiveContains(loc) == true
                }), let mLat = match.latitude, let mLon = match.longitude {
                    lat = mLat
                    lon = mLon
                    locName = match.locationName ?? match.title
                    linkedTitle = match.title
                } else {
                    let places = await LocationManager.searchPlaces(query: loc)
                    if let first = places.first {
                        lat = first.location.coordinate.latitude
                        lon = first.location.coordinate.longitude
                        locName = first.name ?? loc
                    }
                }
            }
            
            let isDeparture = c.locationTrigger?.lowercased().contains("depart") == true || c.locationTrigger?.lowercased().contains("leave") == true
            let hasLoc = lat != nil && lon != nil
            let notifyArrival = hasLoc ? !isDeparture : true
            let notifyDeparture = hasLoc ? isDeparture : false
            
            return ParsedReminderResult(
                title: c.title.isEmpty ? trimmed : c.title,
                notes: c.notes ?? "",
                dueDate: detectedDate,
                isImportant: c.isImportant,
                recurrence: rec,
                locationName: locName,
                latitude: lat,
                longitude: lon,
                notifyOnArrival: notifyArrival,
                notifyOnDeparture: notifyDeparture,
                linkedMemoryTitle: linkedTitle
            )
        } catch {
            // Heuristic Fallback
            var title = trimmed
            var isImportant = false
            var recurrence: ReminderRecurrence = .none
            let lower = trimmed.lowercased()
            
            if lower.contains("!urgent") || lower.contains("!important") || lower.contains("urgent") || lower.contains("important") || lower.contains("asap") {
                isImportant = true
                title = title.replacingOccurrences(of: "!urgent", with: "", options: .caseInsensitive)
                             .replacingOccurrences(of: "!important", with: "", options: .caseInsensitive)
            }
            
            if lower.contains("every day") || lower.contains("daily") {
                recurrence = .daily
            } else if lower.contains("every week") || lower.contains("weekly") {
                recurrence = .weekly
            } else if lower.contains("every month") || lower.contains("monthly") {
                recurrence = .monthly
            }
            
            let isDeparture = lower.contains("when i leave") || lower.contains("leaving") || lower.contains("departing")
            
            // Check if place is mentioned after "at" or "leave" (e.g. "at Gail's Bakery" or "leave Gail's Bakery")
            var locName: String? = nil
            var lat: Double? = nil
            var lon: Double? = nil
            var linkedTitle: String? = nil
            
            let searchMarker = isDeparture ? (lower.range(of: " leave ") ?? lower.range(of: " leaving ")) : lower.range(of: " at ")
            if let markerRange = searchMarker {
                let candidate = String(trimmed[markerRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty {
                    if let match = existingMemories.first(where: {
                        $0.locationName?.localizedCaseInsensitiveContains(candidate) == true ||
                        $0.title.localizedCaseInsensitiveContains(candidate) == true
                    }), let mLat = match.latitude, let mLon = match.longitude {
                        lat = mLat
                        lon = mLon
                        locName = match.locationName ?? match.title
                        linkedTitle = match.title
                    }
                }
            }
            
            let hasLoc = lat != nil && lon != nil
            return ParsedReminderResult(
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                notes: "",
                dueDate: detectedDate,
                isImportant: isImportant,
                recurrence: recurrence,
                locationName: locName,
                latitude: lat,
                longitude: lon,
                notifyOnArrival: hasLoc ? !isDeparture : true,
                notifyOnDeparture: hasLoc ? isDeparture : false,
                linkedMemoryTitle: linkedTitle
            )
        }
    }
}
