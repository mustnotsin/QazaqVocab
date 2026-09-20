import XCTest
import Foundation
import UserNotifications
@testable import QazaqVocab

/// Mock implementation of NotificationSchedulingClient to verify all scheduling decisions deterministically.
final class MockNotificationSchedulingClient: NotificationSchedulingClient {
    var stubbedAuthorizationStatus: UNAuthorizationStatus = .notDetermined
    var stubbedRequestAuthorizationResult: Bool = true
    var stubbedRequestAuthorizationError: Error? = nil
    
    var authorizationRequestsCount = 0
    var requestedOptions: UNAuthorizationOptions? = nil
    
    var pendingRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [[String]] = []
    
    func authorizationStatus() async -> UNAuthorizationStatus {
        return stubbedAuthorizationStatus
    }
    
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        authorizationRequestsCount += 1
        requestedOptions = options
        if let error = stubbedRequestAuthorizationError {
            throw error
        }
        if stubbedRequestAuthorizationResult {
            stubbedAuthorizationStatus = .authorized
        } else {
            stubbedAuthorizationStatus = .denied
        }
        return stubbedRequestAuthorizationResult
    }
    
    func add(_ request: UNNotificationRequest) async throws {
        // UNUserNotificationCenter replaces existing request with same identifier
        pendingRequests.removeAll { $0.identifier == request.identifier }
        pendingRequests.append(request)
    }
    
    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(identifiers)
        let set = Set(identifiers)
        pendingRequests.removeAll { set.contains($0.identifier) }
    }
    
    func getPendingNotificationRequests() async -> [UNNotificationRequest] {
        return pendingRequests
    }
}

final class DailyReminderTests: XCTestCase {
    private var mockClient: MockNotificationSchedulingClient!
    private var testDefaults: UserDefaults!
    private let testSuiteName = "test.qazaqvocab.daily.reminders"
    
    override func setUp() {
        super.setUp()
        mockClient = MockNotificationSchedulingClient()
        testDefaults = UserDefaults(suiteName: testSuiteName)!
        clearTestDefaults()
    }
    
    override func tearDown() {
        clearTestDefaults()
        mockClient = nil
        testDefaults = nil
        super.tearDown()
    }
    
    private func clearTestDefaults() {
        testDefaults.removeObject(forKey: ExperienceEngine.hasCompletedFirstTimeSetupKey)
        testDefaults.removeObject(forKey: ExperienceEngine.dailyReminderHourKey)
        testDefaults.removeObject(forKey: ExperienceEngine.dailyReminderMinuteKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isReminderEnabledKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isReminderEligibleKey)
    }
    
    // Criterion 1 & 2: First-time setup state and default reminder time
    func testFirstTimeSetup_initialStateAndDefaults() {
        XCTAssertFalse(
            ExperienceEngine.hasCompletedFirstTimeSetup(in: testDefaults),
            "First-time setup must initially be uncompleted"
        )
        
        let (hour, minute) = ExperienceEngine.getReminderTime(from: testDefaults)
        XCTAssertEqual(hour, ExperienceEngine.defaultReminderHour, "Default reminder hour should be 10")
        XCTAssertEqual(minute, ExperienceEngine.defaultReminderMinute, "Default reminder minute should be 0")
        
        ExperienceEngine.saveReminderTime(hour: 8, minute: 30, in: testDefaults)
        let savedTime = ExperienceEngine.getReminderTime(from: testDefaults)
        XCTAssertEqual(savedTime.hour, 8)
        XCTAssertEqual(savedTime.minute, 30)
        
        ExperienceEngine.setFirstTimeSetupCompleted(true, in: testDefaults)
        XCTAssertTrue(ExperienceEngine.hasCompletedFirstTimeSetup(in: testDefaults))
    }
    
    // Criterion 3 & 5: Granting permission schedules repeating local reminder at chosen local time
    func testScheduleReminder_whenPermissionGranted_schedulesDailyLocalNotification() async throws {
        mockClient.stubbedAuthorizationStatus = .notDetermined
        mockClient.stubbedRequestAuthorizationResult = true
        
        let manager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        
        let scheduled = try await manager.scheduleReminder(hour: 9, minute: 15)
        
        XCTAssertTrue(scheduled, "Scheduling should succeed when authorization is granted")
        XCTAssertEqual(mockClient.authorizationRequestsCount, 1, "Authorization should be requested once")
        XCTAssertEqual(mockClient.requestedOptions, [.alert, .sound], "Should request alert and sound permissions")
        
        let pending = await mockClient.getPendingNotificationRequests()
        XCTAssertEqual(pending.count, 1, "Exactly one reminder request must be pending")
        
        let request = pending.first!
        XCTAssertEqual(request.identifier, ExperienceEngine.dailyReminderIdentifier)
        
        // Check destination metadata (Criterion 6)
        XCTAssertEqual(
            request.content.userInfo[ExperienceEngine.notificationDestinationKey] as? String,
            ExperienceEngine.featuredWordDestination,
            "Notification metadata must point to the featured daily word"
        )
        XCTAssertEqual(request.content.title, DailyReminderManager.reminderNotificationTitle)
        XCTAssertEqual(request.content.body, DailyReminderManager.reminderNotificationBody)
        XCTAssertNotNil(request.content.sound)
        
        // Check repeating calendar trigger
        guard let trigger = request.trigger as? UNCalendarNotificationTrigger else {
            XCTFail("Trigger must be a UNCalendarNotificationTrigger")
            return
        }
        XCTAssertTrue(trigger.repeats, "Daily reminder must repeat")
        XCTAssertEqual(trigger.dateComponents.hour, 9)
        XCTAssertEqual(trigger.dateComponents.minute, 15)
        
        XCTAssertTrue(ExperienceEngine.isReminderEnabled(in: testDefaults))
        let savedTime = ExperienceEngine.getReminderTime(from: testDefaults)
        XCTAssertEqual(savedTime.hour, 9)
        XCTAssertEqual(savedTime.minute, 15)
    }
    
    // Criterion 4: Denying permission leaves the app usable and records preferences
    func testScheduleReminder_whenPermissionDenied_doesNotThrowAndRecordsTime() async throws {
        mockClient.stubbedAuthorizationStatus = .notDetermined
        mockClient.stubbedRequestAuthorizationResult = false
        
        let manager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        
        let scheduled = try await manager.scheduleReminder(hour: 11, minute: 45)
        
        XCTAssertFalse(scheduled, "Scheduling must return false when authorization is denied")
        let pending = await mockClient.getPendingNotificationRequests()
        XCTAssertTrue(pending.isEmpty, "No pending notification requests should exist when denied")
        
        // Learner's chosen time is still remembered
        let savedTime = ExperienceEngine.getReminderTime(from: testDefaults)
        XCTAssertEqual(savedTime.hour, 11)
        XCTAssertEqual(savedTime.minute, 45)
        XCTAssertFalse(ExperienceEngine.isReminderEnabled(in: testDefaults))
    }
    
    // Criterion 4: Previously denied or revoked permission does not prompt and remains safe
    func testScheduleReminder_whenPermissionAlreadyDenied_doesNotPrompt() async throws {
        mockClient.stubbedAuthorizationStatus = .denied
        
        let manager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        
        let scheduled = try await manager.scheduleReminder(hour: 12, minute: 0)
        
        XCTAssertFalse(scheduled)
        XCTAssertEqual(mockClient.authorizationRequestsCount, 0, "Must not prompt when already denied")
        XCTAssertFalse(ExperienceEngine.isReminderEnabled(in: testDefaults))
    }
    
    // Criterion 7: Changing the chosen time reschedules without duplicate reminders
    func testChangingTime_reschedulesWithoutDuplicateReminders() async throws {
        mockClient.stubbedAuthorizationStatus = .authorized
        
        let manager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        
        // Initial schedule at 08:00
        let firstScheduled = try await manager.scheduleReminder(hour: 8, minute: 0)
        XCTAssertTrue(firstScheduled)
        
        var pending = await mockClient.getPendingNotificationRequests()
        XCTAssertEqual(pending.count, 1)
        var trigger = pending.first?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 8)
        XCTAssertEqual(trigger?.dateComponents.minute, 0)
        
        // Reschedule to 20:30
        let secondScheduled = try await manager.scheduleReminder(hour: 20, minute: 30)
        XCTAssertTrue(secondScheduled)
        
        pending = await mockClient.getPendingNotificationRequests()
        XCTAssertEqual(pending.count, 1, "Must never have duplicate pending reminders")
        trigger = pending.first?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 20)
        XCTAssertEqual(trigger?.dateComponents.minute, 30)
        
        let savedTime = ExperienceEngine.getReminderTime(from: testDefaults)
        XCTAssertEqual(savedTime.hour, 20)
        XCTAssertEqual(savedTime.minute, 30)
    }
    
    // Criterion 7: RescheduleIfNeeded uses persisted time accurately
    func testRescheduleIfNeeded_preservesSingleScheduledReminder() async throws {
        mockClient.stubbedAuthorizationStatus = .authorized
        
        let manager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        
        // Enable reminders and save time 07:45
        ExperienceEngine.saveReminderTime(hour: 7, minute: 45, in: testDefaults)
        ExperienceEngine.setReminderEnabled(true, in: testDefaults)
        
        let rescheduled = try await manager.rescheduleIfNeeded()
        XCTAssertTrue(rescheduled)
        
        let pending = await mockClient.getPendingNotificationRequests()
        XCTAssertEqual(pending.count, 1)
        let trigger = pending.first?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 7)
        XCTAssertEqual(trigger?.dateComponents.minute, 45)
    }
    
    // Criterion 8: Completing the finite feed cancels reminders and prevents rescheduling
    func testCollectionCompletion_cancelsRemindersAndPreventsRescheduling() async throws {
        mockClient.stubbedAuthorizationStatus = .authorized
        
        let manager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        
        // Schedule active reminder
        _ = try await manager.scheduleReminder(hour: 10, minute: 0)
        var pending = await mockClient.getPendingNotificationRequests()
        XCTAssertEqual(pending.count, 1)
        
        // Learner completes collection
        ExperienceEngine.markCollectionCompleted(in: testDefaults)
        XCTAssertTrue(ExperienceEngine.isCollectionCompleted(in: testDefaults))
        XCTAssertFalse(ExperienceEngine.isReminderEligible(in: testDefaults))
        
        // Cancels reminders
        manager.cancelReminders()
        pending = await mockClient.getPendingNotificationRequests()
        XCTAssertTrue(pending.isEmpty, "Reminders must be cancelled upon collection completion")
        XCTAssertFalse(ExperienceEngine.isReminderEnabled(in: testDefaults))
        
        // Attempting to reschedule or schedule while completed is blocked
        let rescheduleResult = try await manager.rescheduleIfNeeded()
        XCTAssertFalse(rescheduleResult, "Rescheduling must fail when collection is completed")
        
        let scheduleResult = try await manager.scheduleReminder(hour: 14, minute: 0)
        XCTAssertFalse(scheduleResult, "Scheduling must fail when collection is completed")
        
        pending = await mockClient.getPendingNotificationRequests()
        XCTAssertTrue(pending.isEmpty, "No reminders can be scheduled after collection completion")
    }
    
    // Criterion 6: Tapping reminder triggers navigation to featured word
    func testAppNavigationState_navigateToFeaturedWord() {
        let navState = AppNavigationState.shared
        navState.selectedTab = .saved
        
        let initialTrigger = navState.scrollToFeaturedTrigger
        
        let expectation = expectation(description: "Navigation dispatched to main queue")
        navState.navigateToFeaturedWord()
        
        DispatchQueue.main.async {
            XCTAssertEqual(navState.selectedTab, .words, "Tapping reminder must switch to Words tab")
            XCTAssertNotEqual(navState.scrollToFeaturedTrigger, initialTrigger, "Tapping reminder must trigger scroll to top")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
}
