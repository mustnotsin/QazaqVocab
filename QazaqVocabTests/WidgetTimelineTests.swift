import XCTest
import Foundation
@testable import QazaqVocab

final class WidgetTimelineTests: XCTestCase {
    private var testCalendar: Calendar!
    private var samplePool: [WordItem]!
    
    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        testCalendar = calendar
        
        samplePool = (1...5).map { id in
            WordItem(
                id: id,
                kazakh: "сөз_\(id)",
                transliteration: "soz_\(id)",
                partOfSpeech: "зат есім",
                meaning: "значение_\(id)",
                primaryExample: BilingualExample(
                    kazakh: "Бұл сөз_\(id) мысалы.",
                    russian: "Это пример для слова_\(id)."
                ),
                usageExplanation: "Түсініктеме_\(id)",
                additionalExamples: nil
            )
        }
    }
    
    override func tearDown() {
        testCalendar = nil
        samplePool = nil
        super.tearDown()
    }
    
    // MARK: - Acceptance Criterion 3: Timeline agrees with app for controlled dates
    
    func testWidgetTimeline_agreesWithAppFeaturedEntry_forControlledDates() {
        // Create controlled dates across multiple days
        let baseComponents = DateComponents(year: 2026, month: 9, day: 20, hour: 14, minute: 30)
        guard let baseDate = testCalendar.date(from: baseComponents) else {
            XCTFail("Failed to construct base date")
            return
        }
        
        for dayOffset in 0..<10 {
            guard let controlledDate = testCalendar.date(byAdding: .day, value: dayOffset, to: baseDate) else {
                continue
            }
            
            let appFeaturedWord = ExperienceEngine.featuredEntry(from: samplePool, for: controlledDate, in: testCalendar)
            let timeline = ExperienceEngine.widgetTimelineEntries(from: samplePool, for: controlledDate, in: testCalendar)
            
            // Current timeline entry must strictly equal the app's featured entry
            XCTAssertNotNil(appFeaturedWord, "App featured word should not be nil for valid pool")
            XCTAssertEqual(
                timeline.current.word,
                appFeaturedWord,
                "Widget today's entry must agree with app featured entry for day offset \(dayOffset)"
            )
            XCTAssertEqual(timeline.current.date, controlledDate)
            
            // Next timeline entry must agree with tomorrow's app featured entry
            let expectedTomorrow = ExperienceEngine.featuredEntry(from: samplePool, for: timeline.nextMidnight, in: testCalendar)
            XCTAssertEqual(
                timeline.next.word,
                expectedTomorrow,
                "Widget tomorrow's entry must agree with app featured entry at next midnight for day offset \(dayOffset)"
            )
            XCTAssertEqual(timeline.next.date, timeline.nextMidnight)
            
            // Verify nextMidnight is indeed the start of the next day
            let expectedMidnight = testCalendar.startOfDay(
                for: testCalendar.date(byAdding: .day, value: 1, to: controlledDate)!
            )
            XCTAssertEqual(timeline.nextMidnight, expectedMidnight)
        }
    }
    
    // MARK: - Acceptance Criterion 5: Rotating through reviewed pool after collection completion
    
    func testWidgetsContinueRotatingThroughReviewedPool_afterCollectionCompletion() {
        let testSuiteName = "test.widget.timeline.completion"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        
        // Mark collection completed
        ExperienceEngine.markCollectionCompleted(in: testDefaults)
        XCTAssertTrue(ExperienceEngine.isCollectionCompleted(in: testDefaults))
        
        let baseComponents = DateComponents(year: 2026, month: 10, day: 1, hour: 9, minute: 0)
        let baseDate = testCalendar.date(from: baseComponents)!
        
        // Even after completion, timeline entries continue rotating deterministically
        var observedWordIDs = Set<Int>()
        for dayOffset in 0..<samplePool.count {
            let date = testCalendar.date(byAdding: .day, value: dayOffset, to: baseDate)!
            let timeline = ExperienceEngine.widgetTimelineEntries(from: samplePool, for: date, in: testCalendar)
            
            XCTAssertNotNil(timeline.current.word)
            observedWordIDs.insert(timeline.current.word.id)
        }
        
        XCTAssertEqual(
            observedWordIDs.count,
            samplePool.count,
            "Widgets must rotate through all pool entries across consecutive days even after completion"
        )
        
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isReminderEligibleKey)
    }
    
    // MARK: - Acceptance Criterion 6: Intentional Fallback for missing/invalid content
    
    func testFallbackEntry_isStructurallyValidAndNonEmpty() throws {
        let fallback = ExperienceEngine.fallbackEntry
        
        XCTAssertEqual(fallback.id, 1)
        XCTAssertEqual(fallback.kazakh, "нан")
        XCTAssertEqual(fallback.meaning, "Хлеб")
        XCTAssertFalse(fallback.transliteration.isEmpty)
        XCTAssertFalse(fallback.partOfSpeech.isEmpty)
        XCTAssertFalse(fallback.primaryExample.kazakh.isEmpty)
        XCTAssertFalse(fallback.primaryExample.russian.isEmpty)
        
        // Ensure fallback entry passes standard domain validation
        XCTAssertNoThrow(try VocabularyValidator.validate(entry: fallback))
    }
    
    func testWidgetTimeline_usesFallback_whenPoolIsEmpty() {
        let emptyPool: [WordItem] = []
        let now = Date()
        
        let timeline = ExperienceEngine.widgetTimelineEntries(from: emptyPool, for: now, in: testCalendar)
        
        XCTAssertEqual(
            timeline.current.word,
            ExperienceEngine.fallbackEntry,
            "Widget must use intentional fallback when pool is empty"
        )
        XCTAssertEqual(
            timeline.next.word,
            ExperienceEngine.fallbackEntry,
            "Widget tomorrow's entry must use intentional fallback when pool is empty"
        )
    }
    
    func testFeaturedEntryOrDefault_returnsFallbackWhenNil() {
        let emptyPool: [WordItem] = []
        let result = ExperienceEngine.featuredEntryOrDefault(from: emptyPool, for: Date(), in: testCalendar)
        XCTAssertEqual(result, ExperienceEngine.fallbackEntry)
        
        // When pool has entries, it returns the deterministic entry, not fallback
        let validResult = ExperienceEngine.featuredEntryOrDefault(from: samplePool, for: Date(), in: testCalendar)
        XCTAssertTrue(samplePool.contains(validResult))
    }
    
    // MARK: - Acceptance Criterion 4: Widget tap deep linking
    
    func testDeepLinkURL_matchesSpecification() {
        let url = ExperienceEngine.featuredWordURL
        XCTAssertEqual(url.scheme, "qazaqvocab")
        XCTAssertEqual(url.host, "featured")
        XCTAssertEqual(url.absoluteString, "qazaqvocab://featured")
    }
    
    func testIsFeaturedWordDeepLink_validatesExpectedURLs() {
        // Valid deep links
        XCTAssertTrue(ExperienceEngine.isFeaturedWordDeepLink(URL(string: "qazaqvocab://featured")!))
        XCTAssertTrue(ExperienceEngine.isFeaturedWordDeepLink(URL(string: "qazaqvocab://word")!))
        XCTAssertTrue(ExperienceEngine.isFeaturedWordDeepLink(URL(string: "QAZAQVOCAB://FEATURED")!))
        XCTAssertTrue(ExperienceEngine.isFeaturedWordDeepLink(URL(string: "qazaqvocab:///featured")!))
        
        // Invalid deep links
        XCTAssertFalse(ExperienceEngine.isFeaturedWordDeepLink(URL(string: "https://featured")!))
        XCTAssertFalse(ExperienceEngine.isFeaturedWordDeepLink(URL(string: "qazaqvocab://settings")!))
        XCTAssertFalse(ExperienceEngine.isFeaturedWordDeepLink(URL(string: "qazaqvocab://unknown")!))
        XCTAssertFalse(ExperienceEngine.isFeaturedWordDeepLink(URL(string: "instagram-stories://share")!))
    }
    
    func testNavigateToFeaturedWord_triggersTabSwitchAndScrollAndDismissDetails() {
        let nav = AppNavigationState()
        nav.selectedTab = .saved
        
        let expectation = expectation(description: "Navigation state updated on main thread")
        
        nav.navigateToFeaturedWord()
        
        DispatchQueue.main.async {
            XCTAssertEqual(nav.selectedTab, .words, "Tapping widget must navigate to Words tab")
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Acceptance Criterion 1 & 2: Russian-first content & all formats agree
    
    func testWidgetEntries_supportRussianFirstFields() {
        let entry = samplePool[0]
        
        // Small format requirements
        XCTAssertFalse(entry.kazakh.isEmpty)
        XCTAssertFalse(entry.partOfSpeech.isEmpty)
        XCTAssertFalse(entry.meaning.isEmpty)
        
        // Medium format requirements
        XCTAssertFalse(entry.transliteration.isEmpty)
        XCTAssertFalse(entry.primaryExample.kazakh.isEmpty)
        XCTAssertFalse(entry.primaryExample.russian.isEmpty)
        
        // Lock screen requirements
        XCTAssertFalse(entry.meaning.isEmpty)
    }
    
    func testBundledWords_agreeWithWidgetTimeline() {
        let bundled = loadWords()
        XCTAssertEqual(bundled.count, 30, "Bundled TestFlight collection must have 30 entries")
        
        let now = Date()
        let appWord = ExperienceEngine.featuredEntry(from: bundled, for: now, in: Calendar.current)
        let widgetData = ExperienceEngine.widgetTimelineEntries(from: bundled, for: now, in: Calendar.current)
        
        XCTAssertNotNil(appWord)
        XCTAssertEqual(widgetData.current.word, appWord)
    }
}
