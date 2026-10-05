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

@main
struct MyApp: App {
    
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                
        }
        .modelContainer(for: MemoryItem.self)
    }
}
