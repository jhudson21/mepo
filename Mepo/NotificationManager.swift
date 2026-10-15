import Foundation
import UserNotifications
import CoreLocation
import SwiftData

// MARK: - Notification Manager
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    static let categoryReminder = "MEPO_REMINDER_CATEGORY"
    static let actionMarkDone = "MEPO_ACTION_MARK_DONE"
    static let actionSnooze15 = "MEPO_ACTION_SNOOZE_15"
    
    private override init() {
        super.init()
    }
    
    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        registerCategories()
    }
    
    private func registerCategories() {
        let markDoneAction = UNNotificationAction(
            identifier: Self.actionMarkDone,
            title: "Mark as Done",
            options: []
        )
        
        let snoozeAction = UNNotificationAction(
            identifier: Self.actionSnooze15,
            title: "Snooze 15 Min",
            options: []
        )
        
        let reminderCategory = UNNotificationCategory(
            identifier: Self.categoryReminder,
            actions: [markDoneAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([reminderCategory])
    }
    
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            if settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional {
                registerCategories()
                return true
            }
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                registerCategories()
            }
            return granted
        } catch {
            return false
        }
    }
    
    func scheduleNotification(for reminder: ReminderItem) async {
        guard !reminder.isCompleted else {
            cancelNotification(for: reminder)
            return
        }
        
        let granted = await requestAuthorization()
        guard granted else { return }
        
        let center = UNUserNotificationCenter.current()
        let baseId = reminder.id.uuidString
        center.removePendingNotificationRequests(withIdentifiers: [
            baseId,
            "\(baseId)_time",
            "\(baseId)_location",
            "\(baseId)_location_arrival",
            "\(baseId)_location_departure"
        ])
        
        // 1. Time / Calendar Trigger
        if let dueDate = reminder.dueDate {
            let content = UNMutableNotificationContent()
            content.title = reminder.isImportant ? "❗ \(reminder.title)" : reminder.title
            var bodyParts: [String] = []
            if !reminder.notes.isEmpty { bodyParts.append(reminder.notes) }
            if let loc = reminder.locationName { bodyParts.append("📍 \(loc)") }
            content.body = bodyParts.joined(separator: " • ")
            content.sound = .default
            content.categoryIdentifier = Self.categoryReminder
            content.userInfo = ["reminderId": baseId]
            
            let calendar = Calendar.current
            var trigger: UNNotificationTrigger?
            
            switch reminder.recurrence {
            case .none:
                if dueDate > Date() {
                    let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                    trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                }
            case .daily:
                let components = calendar.dateComponents([.hour, .minute], from: dueDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            case .weekly:
                let components = calendar.dateComponents([.weekday, .hour, .minute], from: dueDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            case .monthly:
                let components = calendar.dateComponents([.day, .hour, .minute], from: dueDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            }
            
            if let trigger {
                let request = UNNotificationRequest(identifier: "\(baseId)_time", content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
        
        // 2. Location Geofence Triggers (Arrival & Departure)
        if let lat = reminder.latitude, let lon = reminder.longitude {
            let centerCoord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let radius = max(reminder.radius, 100.0) // iOS requires at least 100m for reliable geofencing
            let locName = reminder.locationName ?? "reminder location"
            
            // Arrival Trigger
            if reminder.notifyOnArrival {
                let arrivalRegion = CLCircularRegion(center: centerCoord, radius: radius, identifier: "\(baseId)_region_arrival")
                arrivalRegion.notifyOnEntry = true
                arrivalRegion.notifyOnExit = false
                
                let arrivalTrigger = UNLocationNotificationTrigger(region: arrivalRegion, repeats: reminder.recurrence != .none)
                let arrivalContent = UNMutableNotificationContent()
                arrivalContent.title = reminder.isImportant ? "📍 ❗ \(reminder.title)" : "📍 \(reminder.title)"
                arrivalContent.body = reminder.notes.isEmpty ? "Arrived near \(locName)" : "\(locName): \(reminder.notes)"
                arrivalContent.sound = .default
                arrivalContent.categoryIdentifier = Self.categoryReminder
                arrivalContent.userInfo = ["reminderId": baseId]
                
                let arrivalRequest = UNNotificationRequest(identifier: "\(baseId)_location_arrival", content: arrivalContent, trigger: arrivalTrigger)
                try? await center.add(arrivalRequest)
            }
            
            // Departure Trigger
            if reminder.notifyOnDeparture {
                let departureRegion = CLCircularRegion(center: centerCoord, radius: radius, identifier: "\(baseId)_region_departure")
                departureRegion.notifyOnEntry = false
                departureRegion.notifyOnExit = true
                
                let departureTrigger = UNLocationNotificationTrigger(region: departureRegion, repeats: reminder.recurrence != .none)
                let departureContent = UNMutableNotificationContent()
                departureContent.title = reminder.isImportant ? "🚶 ❗ \(reminder.title)" : "🚶 \(reminder.title)"
                departureContent.body = reminder.notes.isEmpty ? "Leaving \(locName)" : "\(locName): \(reminder.notes)"
                departureContent.sound = .default
                departureContent.categoryIdentifier = Self.categoryReminder
                departureContent.userInfo = ["reminderId": baseId]
                
                let departureRequest = UNNotificationRequest(identifier: "\(baseId)_location_departure", content: departureContent, trigger: departureTrigger)
                try? await center.add(departureRequest)
            }
        }
    }
    
    func cancelNotification(for reminder: ReminderItem) {
        let baseId = reminder.id.uuidString
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            baseId,
            "\(baseId)_time",
            "\(baseId)_location",
            "\(baseId)_location_arrival",
            "\(baseId)_location_departure"
        ])
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let reminderIdString = response.notification.request.content.userInfo["reminderId"] as? String
        let actionIdentifier = response.actionIdentifier
        
        Task { @MainActor in
            if let reminderIdString,
               let uuid = UUID(uuidString: reminderIdString) {
                handleNotificationAction(actionIdentifier: actionIdentifier, reminderId: uuid)
            }
            completionHandler()
        }
    }
    
    private func handleNotificationAction(actionIdentifier: String, reminderId: UUID) {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<ReminderItem>(predicate: #Predicate { $0.id == reminderId })
        
        guard let reminder = try? context.fetch(descriptor).first else { return }
        
        switch actionIdentifier {
        case Self.actionMarkDone:
            reminder.isCompleted = true
            try? context.save()
            cancelNotification(for: reminder)
            MepoWidgetStore.shared.toggleReminder(id: reminder.id.uuidString)
            
        case Self.actionSnooze15:
            let snoozedDate = Date().addingTimeInterval(15 * 60)
            reminder.dueDate = snoozedDate
            try? context.save()
            Task {
                await scheduleNotification(for: reminder)
            }
            
        default:
            break
        }
    }
}
