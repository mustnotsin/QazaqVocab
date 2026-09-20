import Foundation
import UserNotifications

/// Thin abstraction interface over system notifications to allow testable scheduling decisions.
protocol NotificationSchedulingClient: AnyObject {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func getPendingNotificationRequests() async -> [UNNotificationRequest]
}

/// Production implementation of NotificationSchedulingClient backed by UNUserNotificationCenter.
final class UserNotificationCenterClient: NotificationSchedulingClient {
    private let center: UNUserNotificationCenter
    
    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }
    
    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }
    
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }
    
    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
    
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }
}

/// Coordinates daily reminder scheduling, permission handling, time updates, and completion cancellation.
final class DailyReminderManager {
    static let shared = DailyReminderManager()
    
    let client: NotificationSchedulingClient
    let defaults: UserDefaults
    let calendar: Calendar
    
    /// Russian notification text inviting learner to view today's featured daily word.
    static let reminderNotificationTitle = "QazaqVocab"
    static let reminderNotificationBody = "Откройте главное казахское слово сегодняшнего дня."
    
    init(
        client: NotificationSchedulingClient = UserNotificationCenterClient(),
        defaults: UserDefaults = UserDefaults(suiteName: ExperienceEngine.appGroupID) ?? .standard,
        calendar: Calendar = .current
    ) {
        self.client = client
        self.defaults = defaults
        self.calendar = calendar
    }
    
    /// Schedules a recurring daily local reminder at the specified local hour and minute.
    /// Returns true if permission was granted and notification scheduled; false otherwise.
    @discardableResult
    func scheduleReminder(hour: Int, minute: Int) async throws -> Bool {
        // Criterion 8: If collection is completed or not reminder-eligible, cancel and do not schedule.
        guard ExperienceEngine.isReminderEligible(in: defaults) else {
            cancelReminders()
            return false
        }
        
        let status = await client.authorizationStatus()
        let isAuthorized: Bool
        
        switch status {
        case .authorized, .provisional:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = try await client.requestAuthorization(options: [.alert, .sound])
        case .denied, .ephemeral:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
        
        // Always persist chosen time regardless of permission outcome (Criterion 3 & 4)
        ExperienceEngine.saveReminderTime(hour: hour, minute: minute, in: defaults)
        
        guard isAuthorized else {
            ExperienceEngine.setReminderEnabled(false, in: defaults)
            client.removePendingNotificationRequests(withIdentifiers: [ExperienceEngine.dailyReminderIdentifier])
            return false
        }
        
        // Criterion 7: Remove any existing reminder to reschedule without duplicates
        client.removePendingNotificationRequests(withIdentifiers: [ExperienceEngine.dailyReminderIdentifier])
        
        // Build notification content with metadata for deep linking (Criterion 6)
        let content = UNMutableNotificationContent()
        content.title = Self.reminderNotificationTitle
        content.body = Self.reminderNotificationBody
        content.sound = .default
        content.userInfo = [
            ExperienceEngine.notificationDestinationKey: ExperienceEngine.featuredWordDestination
        ]
        
        // Build repeating calendar trigger for the chosen local time (Criterion 5)
        var triggerComponents = DateComponents()
        triggerComponents.hour = hour
        triggerComponents.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: ExperienceEngine.dailyReminderIdentifier,
            content: content,
            trigger: trigger
        )
        
        try await client.add(request)
        ExperienceEngine.setReminderEnabled(true, in: defaults)
        return true
    }
    
    /// Reschedules the daily reminder with the currently stored time preferences without creating duplicates.
    @discardableResult
    func rescheduleIfNeeded() async throws -> Bool {
        guard ExperienceEngine.isReminderEligible(in: defaults) else {
            cancelReminders()
            return false
        }
        
        guard ExperienceEngine.isReminderEnabled(in: defaults) else {
            return false
        }
        
        let (hour, minute) = ExperienceEngine.getReminderTime(from: defaults)
        return try await scheduleReminder(hour: hour, minute: minute)
    }
    
    /// Cancels scheduled daily reminders and marks reminders disabled in learner state (Criterion 8).
    func cancelReminders() {
        client.removePendingNotificationRequests(withIdentifiers: [ExperienceEngine.dailyReminderIdentifier])
        ExperienceEngine.setReminderEnabled(false, in: defaults)
    }
    
    /// Synchronizes reminders with collection state. Called when collection is completed or app launches.
    func syncWithLearnerState() {
        if !ExperienceEngine.isReminderEligible(in: defaults) {
            cancelReminders()
        }
    }
    
    /// Queries the current notification authorization status through the scheduling client.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await client.authorizationStatus()
    }
}
