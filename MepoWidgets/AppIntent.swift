import WidgetKit
import SwiftUI
import AppIntents

// MARK: - iOS 18 Control Center & Lock Screen Quick Controls

struct MepoNewMemoryControl: ControlWidget {
    static let kind = "com.jordanhudsonpersonalteam.Mepo.control.newMemory"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "mepo://new-memory")!)) {
                Label("New Memory", systemImage: "sparkles")
            }
        }
        .displayName("New Memory")
        .description("Instantly log a place, photo, or note in Mepo.")
    }
}

struct MepoVoiceReminderControl: ControlWidget {
    static let kind = "com.jordanhudsonpersonalteam.Mepo.control.voiceReminder"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "mepo://voice-reminder")!)) {
                Label("Voice Dictation", systemImage: "mic.fill")
            }
        }
        .displayName("Voice Dictation")
        .description("Dictate a quick task or note using speech recognition.")
    }
}

struct MepoNewReminderControl: ControlWidget {
    static let kind = "com.jordanhudsonpersonalteam.Mepo.control.newReminder"
    
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(URL(string: "mepo://new-reminder")!)) {
                Label("New Reminder", systemImage: "checklist")
            }
        }
        .displayName("New Reminder")
        .description("Quickly create a reminder or geofenced task.")
    }
}
