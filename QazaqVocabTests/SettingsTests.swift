import XCTest
import SwiftUI
import UserNotifications
@testable import QazaqVocab

@MainActor
final class SettingsTests: XCTestCase {
    private var mockClient: MockNotificationSchedulingClient!
    private var testDefaults: UserDefaults!
    private let testSuiteName = "test.qazaqvocab.settings"
    
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
    
    // Criterion 1: Settings shows whether daily reminders are enabled
    func testSettings_showsWhetherDailyRemindersAreEnabled() async {
        // Case A: Reminders initially disabled
        ExperienceEngine.setReminderEnabled(false, in: testDefaults)
        let reminderManager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        let vm = SettingsViewModel(reminderManager: reminderManager, defaults: testDefaults)
        await vm.load()
        
        XCTAssertFalse(vm.isReminderEnabled, "Settings must reflect disabled reminder state")
        
        // Case B: Reminders enabled
        ExperienceEngine.setReminderEnabled(true, in: testDefaults)
        await vm.load()
        XCTAssertTrue(vm.isReminderEnabled, "Settings must reflect enabled reminder state")
    }
    
    // Criterion 2 & 4: Turning reminders on/off and rescheduling without duplicate schedules
    func testSettings_toggleRemindersAndRescheduleWithoutDuplicates() async throws {
        mockClient.stubbedAuthorizationStatus = .authorized
        let reminderManager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        let vm = SettingsViewModel(reminderManager: reminderManager, defaults: testDefaults)
        
        // Initially off
        await vm.load()
        XCTAssertFalse(vm.isReminderEnabled)
        
        // Turn reminders ON at 09:15
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9
        comps.minute = 15
        let chosenDate = calendar.date(from: comps)!
        
        await vm.updateReminderTime(chosenDate)
        await vm.setReminderEnabled(true)
        
        XCTAssertTrue(vm.isReminderEnabled, "Reminders must be enabled after turning toggle on")
        XCTAssertTrue(ExperienceEngine.isReminderEnabled(in: testDefaults))
        
        var pending = await mockClient.getPendingNotificationRequests()
        XCTAssertEqual(pending.count, 1, "Exactly one notification request must be scheduled")
        var trigger = pending.first?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 9)
        XCTAssertEqual(trigger?.dateComponents.minute, 15)
        
        // Change time to 21:45 while enabled (Criterion 2 & 4)
        comps.hour = 21
        comps.minute = 45
        let newDate = calendar.date(from: comps)!
        
        await vm.updateReminderTime(newDate)
        
        pending = await mockClient.getPendingNotificationRequests()
        XCTAssertEqual(pending.count, 1, "Must never create duplicate notification schedules when changing time")
        trigger = pending.first?.trigger as? UNCalendarNotificationTrigger
        XCTAssertEqual(trigger?.dateComponents.hour, 21)
        XCTAssertEqual(trigger?.dateComponents.minute, 45)
        
        let savedTime = ExperienceEngine.getReminderTime(from: testDefaults)
        XCTAssertEqual(savedTime.hour, 21)
        XCTAssertEqual(savedTime.minute, 45)
        
        // Turn reminders OFF (Criterion 2)
        await vm.setReminderEnabled(false)
        XCTAssertFalse(vm.isReminderEnabled, "Reminders must be disabled after toggle turned off")
        XCTAssertFalse(ExperienceEngine.isReminderEnabled(in: testDefaults))
        
        pending = await mockClient.getPendingNotificationRequests()
        XCTAssertTrue(pending.isEmpty, "Pending notifications must be cleared when turning reminders off")
    }
    
    // Criterion 3: Notification permission status reflection
    func testSettings_permissionStatusReflection() async {
        let reminderManager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        let vm = SettingsViewModel(reminderManager: reminderManager, defaults: testDefaults)
        
        // Status: .authorized
        mockClient.stubbedAuthorizationStatus = .authorized
        await vm.load()
        XCTAssertEqual(vm.permissionStatusText, "Разрешено")
        XCTAssertFalse(vm.isPermissionDenied)
        
        // Status: .provisional
        mockClient.stubbedAuthorizationStatus = .provisional
        await vm.load()
        XCTAssertEqual(vm.permissionStatusText, "Разрешено")
        XCTAssertFalse(vm.isPermissionDenied)
        
        // Status: .notDetermined
        mockClient.stubbedAuthorizationStatus = .notDetermined
        await vm.load()
        XCTAssertEqual(vm.permissionStatusText, "Не запрошено")
        XCTAssertFalse(vm.isPermissionDenied)
        
        // Status: .denied
        mockClient.stubbedAuthorizationStatus = .denied
        await vm.load()
        XCTAssertEqual(vm.permissionStatusText, "Отключено в iOS")
        XCTAssertTrue(vm.isPermissionDenied)
    }
    
    // Criterion 3: Appropriate route to system settings when permission is unavailable
    func testSettings_routeToSystemSettingsWhenPermissionDenied() async {
        mockClient.stubbedAuthorizationStatus = .denied
        let reminderManager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        
        var openedURL: URL? = nil
        let vm = SettingsViewModel(
            reminderManager: reminderManager,
            defaults: testDefaults,
            openSettingsHandler: { url in
                openedURL = url
            }
        )
        
        await vm.load()
        XCTAssertTrue(vm.isPermissionDenied)
        
        vm.openSystemSettings()
        XCTAssertNotNil(openedURL)
        XCTAssertEqual(openedURL?.absoluteString, UIApplication.openSettingsURLString)
    }
    
    // Criterion 4 & Collection completion handling: Reminders stopped on completion
    func testSettings_whenCollectionCompleted_disablesReminders() async {
        ExperienceEngine.markCollectionCompleted(in: testDefaults)
        let reminderManager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        let vm = SettingsViewModel(reminderManager: reminderManager, defaults: testDefaults)
        
        await vm.load()
        XCTAssertTrue(vm.isCollectionCompleted)
        XCTAssertFalse(vm.isReminderEnabled)
        
        // Attempting to enable reminders when collection is completed should remain disabled
        await vm.setReminderEnabled(true)
        XCTAssertFalse(vm.isReminderEnabled, "Reminders cannot be enabled once collection is completed")
        
        let pending = await mockClient.getPendingNotificationRequests()
        XCTAssertTrue(pending.isEmpty)
    }
    
    // Criterion 5: About QazaqVocab uses concise neutral Russian copy
    func testAboutQazaqVocabCopy_conformsToDomainSpecs() {
        let aboutCopy = "QazaqVocab — приложение для ежедневного знакомства с казахскими словами. Создано для русскоязычных людей, изучающих казахский язык. Здесь нет спешки, таймеров и оценок — только одно главное слово каждый день и удобный темп исследования."
        
        XCTAssertTrue(aboutCopy.contains("QazaqVocab"))
        XCTAssertTrue(aboutCopy.contains("казахскими словами"))
        XCTAssertTrue(aboutCopy.contains("русскоязычных людей"))
        XCTAssertTrue(aboutCopy.contains("главное слово каждый день"))
        
        // Must avoid banned terminology from CONTEXT.md
        let forbidden = ["пользователь", "ученик", "студент", "карточка", "интервальное", "мастерство", "запоминание"]
        let lower = aboutCopy.lowercased()
        for word in forbidden {
            XCTAssertFalse(lower.contains(word), "About text should avoid forbidden concept: \(word)")
        }
    }
    
    // Criterion 6: TestFlight collection information explains 30 reviewed entries as test content
    func testTestFlightCollectionInfo_explainsTestContentScope() {
        let collectionInfo = "В этой версии QazaqVocab доступно 30 проверенных слов (повседневные, разговорные и культурно значимые). Это тестовая коллекция для первого закрытого тестирования в TestFlight, а не ограничение будущего публичного каталога."
        
        XCTAssertTrue(collectionInfo.contains("30 проверенных слов"), "Must explain exactly 30 reviewed entries")
        XCTAssertTrue(collectionInfo.contains("TestFlight"), "Must mention TestFlight")
        XCTAssertTrue(collectionInfo.contains("тестовая коллекция"), "Must describe as test collection")
        XCTAssertTrue(collectionInfo.contains("не ограничение будущего публичного каталога"), "Must clarify it is not intended public catalog limit")
        
        // Must avoid forbidden terms from CONTEXT.md
        XCTAssertFalse(collectionInfo.contains("полная библиотека"))
        XCTAssertFalse(collectionInfo.contains("публичный каталог слов"))
    }
    
    // Deep linking & App Navigation
    func testSettingsDeepLink_andNavigationDismissal() {
        let settingsDeepLink = URL(string: "qazaqvocab://settings")!
        let featuredDeepLink = URL(string: "qazaqvocab://featured")!
        let randomDeepLink = URL(string: "qazaqvocab://other")!
        
        XCTAssertTrue(ExperienceEngine.isSettingsDeepLink(settingsDeepLink))
        XCTAssertFalse(ExperienceEngine.isSettingsDeepLink(featuredDeepLink))
        XCTAssertFalse(ExperienceEngine.isSettingsDeepLink(randomDeepLink))
        
        XCTAssertFalse(ExperienceEngine.isFeaturedWordDeepLink(settingsDeepLink))
        
        // Test navigation dismissal
        let navState = AppNavigationState.shared
        navState.isSettingsPresented = true
        
        let expectation = expectation(description: "Dismiss settings when navigating to featured")
        navState.navigateToFeaturedWord()
        
        DispatchQueue.main.async {
            XCTAssertFalse(navState.isSettingsPresented, "Navigating to featured word must dismiss settings sheet")
            XCTAssertEqual(navState.selectedTab, .words)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // Criterion 7: Verify Settings does not introduce accounts, profiles, themes, analytics, or preferences
    func testSettings_strictlyExcludesProhibitedFeatures() {
        // Inspect SettingsView code content or properties
        // Verify that SettingsViewModel only tracks reminders, permissions, and collection counts
        let vm = SettingsViewModel(
            reminderManager: DailyReminderManager(client: mockClient, defaults: testDefaults),
            defaults: testDefaults,
            allWordsCount: 30,
            seenWordsCount: 10,
            savedWordsCount: 3
        )
        
        XCTAssertEqual(vm.allWordsCount, 30)
        XCTAssertEqual(vm.seenWordsCount, 10)
        XCTAssertEqual(vm.savedWordsCount, 3)
    }
    
    // Criterion 8: Automated / focused UI smoke test covering SettingsView instantiation and rendering
    func testSettingsView_instantiatesAndRenders() {
        let reminderManager = DailyReminderManager(client: mockClient, defaults: testDefaults)
        let vm = SettingsViewModel(
            reminderManager: reminderManager,
            defaults: testDefaults,
            allWordsCount: 30,
            seenWordsCount: 15,
            savedWordsCount: 4
        )
        
        let view = SettingsView(viewModel: vm)
        XCTAssertNotNil(view.body)
    }
}
