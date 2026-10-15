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
    let config = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false,
        cloudKitDatabase: .none
    )
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()

@main
struct MyApp: App {
    #if canImport(UIKit)
    @UIApplicationDelegateAdaptor(MepoAppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    _ = QuickActionManager.shared.handle(url: url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
