import SwiftUI
#if canImport(UIKit)
import UIKit

// MARK: - Mepo Quick Action Types
enum MepoQuickAction: String, Identifiable {
    case newMemory = "new-memory"
    case newReminder = "new-reminder"
    case voiceReminder = "voice-reminder"
    
    var id: String { rawValue }
    
    init?(shortcutType: String) {
        if shortcutType.hasSuffix("newMemory") {
            self = .newMemory
        } else if shortcutType.hasSuffix("newReminder") {
            self = .newReminder
        } else if shortcutType.hasSuffix("voiceReminder") {
            self = .voiceReminder
        } else {
            return nil
        }
    }
}

// MARK: - Quick Action Manager
@Observable
final class QuickActionManager {
    static let shared = QuickActionManager()
    
    var activeAction: MepoQuickAction? = nil
    
    @discardableResult
    func handle(shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = MepoQuickAction(shortcutType: shortcutItem.type) else { return false }
        activeAction = action
        return true
    }
    
    @discardableResult
    func handle(url: URL) -> Bool {
        guard url.scheme == "mepo" else { return false }
        let targetHost = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let action = MepoQuickAction(rawValue: targetHost) else { return false }
        activeAction = action
        return true
    }
}

// MARK: - App & Scene Delegates for Shortcut Items
final class MepoAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if let shortcut = options.shortcutItem {
            _ = QuickActionManager.shared.handle(shortcutItem: shortcut)
        }
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = MepoSceneDelegate.self
        return configuration
    }
}

final class MepoSceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        let handled = QuickActionManager.shared.handle(shortcutItem: shortcutItem)
        completionHandler(handled)
    }
}
#endif
