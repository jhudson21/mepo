import SwiftUI
import SwiftData

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
    var id: String { self.rawValue }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        MemoryItem.self,
        ReminderItem.self,
    ])
    
    // Primary: CloudKit-backed private database for automatic cross-device sync
    let cloudConfig = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .private("iCloud.com.jordanhudsonpersonalteam.Mepo")
    )
    
    if let container = try? ModelContainer(for: schema, configurations: [cloudConfig]) {
        return container
    }
    
    // Fallback: Local persistent store if CloudKit is unreachable during development
    let fallbackConfig = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none
    )
    
    do {
        return try ModelContainer(for: schema, configurations: [fallbackConfig])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
