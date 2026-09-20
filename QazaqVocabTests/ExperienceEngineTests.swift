import XCTest
import Foundation
@testable import QazaqVocab

final class ExperienceEngineTests: XCTestCase {
    private let sampleWords: [WordItem] = [
        WordItem(id: 1, kazakh: "сәуле", partOfSpeech: "зат есім", translation: "Луч / Луч света", example: "Күн сәулесі бөлмеге түсті.", phonetic: "säwle", details: nil, additionalExamples: nil),
        WordItem(id: 2, kazakh: "қалам", partOfSpeech: "зат есім", translation: "Ручка", example: "Ол жаңа қалам сатып алды.", phonetic: "qalam", details: nil, additionalExamples: nil),
        WordItem(id: 3, kazakh: "терезе", partOfSpeech: "зат есім", translation: "Окно", example: "Терезені ашыңызшы.", phonetic: "tereze", details: nil, additionalExamples: nil)
    ]
    
    // Criterion 1: Deterministic selection for same calendar date
    func testFeaturedEntry_isDeterministicForSameCalendarDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Almaty")!
        
        var morningComponents = DateComponents()
        morningComponents.year = 2026
        morningComponents.month = 9
        morningComponents.day = 20
        morningComponents.hour = 8
        morningComponents.minute = 15
        let morningDate = calendar.date(from: morningComponents)!
        
        var eveningComponents = DateComponents()
        eveningComponents.year = 2026
        eveningComponents.month = 9
        eveningComponents.day = 20
        eveningComponents.hour = 23
        eveningComponents.minute = 45
        let eveningDate = calendar.date(from: eveningComponents)!
        
        let morningEntry = ExperienceEngine.featuredEntry(from: sampleWords, for: morningDate, in: calendar)
        let eveningEntry = ExperienceEngine.featuredEntry(from: sampleWords, for: eveningDate, in: calendar)
        
        XCTAssertNotNil(morningEntry, "Featured entry should not be nil")
        XCTAssertEqual(morningEntry?.id, eveningEntry?.id, "Morning and evening on the same calendar day must produce the exact same featured entry")
    }
    
    // Criterion 2: Sequential rotation and wrap-around across days
    func testFeaturedEntry_rotatesSequentiallyAcrossDaysAndWrapsAround() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Almaty")!
        
        var baseComponents = DateComponents()
        baseComponents.year = 2026
        baseComponents.month = 9
        baseComponents.day = 20
        baseComponents.hour = 10
        baseComponents.minute = 0
        let baseDate = calendar.date(from: baseComponents)!
        
        var selectedIDs: [Int] = []
        for dayOffset in 0..<sampleWords.count {
            let nextDate = calendar.date(byAdding: .day, value: dayOffset, to: baseDate)!
            let entry = ExperienceEngine.featuredEntry(from: sampleWords, for: nextDate, in: calendar)
            XCTAssertNotNil(entry, "Featured entry for day \(dayOffset) should not be nil")
            selectedIDs.append(entry!.id)
        }
        
        let uniqueIDs = Set(selectedIDs)
        XCTAssertEqual(uniqueIDs.count, sampleWords.count, "Each day in a cycle should select a distinct entry")
        
        let wrapDate = calendar.date(byAdding: .day, value: sampleWords.count, to: baseDate)!
        let wrapEntry = ExperienceEngine.featuredEntry(from: sampleWords, for: wrapDate, in: calendar)
        XCTAssertEqual(wrapEntry?.id, selectedIDs[0], "Day after cycle completion must wrap around to the first entry")
    }
    
    // Criterion 3: Safe handling of empty pool
    func testFeaturedEntry_returnsNilForEmptyPool() {
        let entry = ExperienceEngine.featuredEntry(from: [], for: Date())
        XCTAssertNil(entry, "Empty pool must safely return nil")
    }
    
    // Criterion 4: Words feed opens on featured entry even if previously seen
    func testPrepareWordsFeed_placesFeaturedEntryFirstEvenIfSeen() {
        let fiveWords: [WordItem] = (1...5).map { id in
            WordItem(id: id, kazakh: "сөз_\(id)", partOfSpeech: "зат есім", translation: "слово_\(id)", example: "мысал_\(id)", phonetic: nil, details: nil, additionalExamples: nil)
        }
        let featured = fiveWords[1] // id = 2
        
        let seenIDs: Set<Int> = [2, 3]
        let feed = ExperienceEngine.prepareWordsFeed(from: fiveWords, featuredEntry: featured, seenIDs: seenIDs)
        
        XCTAssertFalse(feed.isEmpty, "Feed should not be empty")
        XCTAssertEqual(feed.first?.id, 2, "Featured entry must be the first item in the Words feed even if previously seen")
        XCTAssertEqual(feed.count, 5, "Feed must include all entries without duplicating the featured entry")
        
        let allSeenIDs: Set<Int> = Set(1...5)
        let feedAllSeen = ExperienceEngine.prepareWordsFeed(from: fiveWords, featuredEntry: featured, seenIDs: allSeenIDs)
        XCTAssertEqual(feedAllSeen.first?.id, 2, "Featured entry must still be first when all words are seen")
        XCTAssertEqual(feedAllSeen.count, 5, "Feed must still contain all entries without duplicates")
    }
    
    // Criterion 5: App group identifier and shared persistence
    func testSharedPersistence_savesAndRetrievesActiveWordID() {
        XCTAssertEqual(ExperienceEngine.appGroupID, "group.com.beksultan.QazaqVocab", "App group ID must match the entitlements suite")
        
        let testDefaults = UserDefaults(suiteName: "test.experience.engine.suite")!
        testDefaults.removeObject(forKey: ExperienceEngine.activeWordIDKey)
        
        ExperienceEngine.saveActiveWordID(42, in: testDefaults)
        let retrievedID = ExperienceEngine.getActiveWordID(from: testDefaults)
        XCTAssertEqual(retrievedID, 42, "Retrieved active word ID must match saved ID")
        
        testDefaults.removeObject(forKey: ExperienceEngine.activeWordIDKey)
    }
    
    // Issue #3 - Criterion 1 & 8: Shuffle completeness and duplication prevention
    func testShuffleCompleteness_containsAllPoolEntriesWithoutDuplicates() {
        let testSuiteName = "test.discovery.feed.shuffle"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removeObject(forKey: ExperienceEngine.discoveryFeedOrderKey)
        
        let pool: [WordItem] = (1...10).map { id in
            WordItem(id: id, kazakh: "сөз_\(id)", partOfSpeech: "зат есім", translation: "слово_\(id)", example: "мысал_\(id)", phonetic: nil, details: nil, additionalExamples: nil)
        }
        
        let order = ExperienceEngine.getOrInitializeDiscoveryFeedOrder(from: pool, defaults: testDefaults)
        
        XCTAssertEqual(order.count, pool.count, "Feed order must contain all entries in the pool")
        XCTAssertEqual(Set(order).count, pool.count, "Feed order must contain zero duplicates")
        XCTAssertEqual(Set(order), Set(pool.map(\.id)), "Feed order must account for every entry ID in the pool")
        
        // Custom deterministic shuffler
        let customDefaults = UserDefaults(suiteName: "test.discovery.feed.custom")!
        customDefaults.removeObject(forKey: ExperienceEngine.discoveryFeedOrderKey)
        let reversedOrder = ExperienceEngine.getOrInitializeDiscoveryFeedOrder(from: pool, defaults: customDefaults, shuffler: { $0.reversed() })
        XCTAssertEqual(reversedOrder, pool.map(\.id).reversed(), "Custom shuffler must be respected when initialized")
        
        testDefaults.removeObject(forKey: ExperienceEngine.discoveryFeedOrderKey)
        customDefaults.removeObject(forKey: ExperienceEngine.discoveryFeedOrderKey)
    }
    
    // Issue #3 - Criterion 2 & 8: Featured entry does not re-enter or duplicate when already seen
    func testDuplicationPrevention_featuredEntryDoesNotReenterWhenAlreadySeen() {
        let pool: [WordItem] = (1...5).map { id in
            WordItem(id: id, kazakh: "сөз_\(id)", partOfSpeech: "зат есім", translation: "слово_\(id)", example: "мысал_\(id)", phonetic: nil, details: nil, additionalExamples: nil)
        }
        let feedOrder = [1, 2, 3, 4, 5]
        let featured = pool[1] // id = 2
        
        // Today's featured word (id 2) is marked as seen
        let seenIDs: Set<Int> = [2]
        let feed = ExperienceEngine.prepareDiscoveryFeed(from: pool, featuredEntry: featured, feedOrder: feedOrder, seenIDs: seenIDs)
        
        XCTAssertEqual(feed.first?.id, 2, "Featured entry must be the first item in the Words feed even if already seen")
        
        let remainingIDs = feed.dropFirst().map(\.id)
        XCTAssertFalse(remainingIDs.contains(2), "Featured entry must not re-enter the unseen discovery feed")
        XCTAssertEqual(remainingIDs, [1, 3, 4, 5], "Remaining feed contains all unseen items in order")
        XCTAssertEqual(Set(feed.map(\.id)).count, feed.count, "Feed must have zero duplicate IDs")
    }
    
    // Issue #3 - Criterion 3 & 8: Seen progress and remaining feed resume after relaunch
    func testPersistence_resumesRemainingFeedAndSeenProgressAfterRelaunch() {
        let pool: [WordItem] = (1...6).map { id in
            WordItem(id: id, kazakh: "сөз_\(id)", partOfSpeech: "зат есім", translation: "слово_\(id)", example: "мысал_\(id)", phonetic: nil, details: nil, additionalExamples: nil)
        }
        let persistedOrder = [3, 1, 6, 2, 5, 4]
        let featured = pool[0] // id = 1
        
        // Learner previously saw IDs 1, 3, and 6
        let seenIDs: Set<Int> = [1, 3, 6]
        
        let feedOnRelaunch = ExperienceEngine.prepareDiscoveryFeed(from: pool, featuredEntry: featured, feedOrder: persistedOrder, seenIDs: seenIDs)
        
        XCTAssertEqual(feedOnRelaunch.first?.id, 1, "Relaunched feed starts with featured word (id 1)")
        let remainingFeedIDs = feedOnRelaunch.dropFirst().map(\.id)
        XCTAssertEqual(remainingFeedIDs, [2, 5, 4], "Remaining feed resumes precisely with the remaining unseen items in their preserved relative order")
    }
    
    // Issue #3 - Criterion 4 & 8: Viewing the final entry alone does NOT complete the collection
    func testViewingFinalEntryAlone_doesNotCompleteCollection() {
        let testSuiteName = "test.discovery.feed.completion.check"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isReminderEligibleKey)
        
        let pool: [WordItem] = (1...3).map { id in
            WordItem(id: id, kazakh: "сөз_\(id)", partOfSpeech: "зат есім", translation: "слово_\(id)", example: "мысал_\(id)", phonetic: nil, details: nil, additionalExamples: nil)
        }
        let allSeenIDs: Set<Int> = [1, 2, 3]
        
        // All words are in seenIDs, but the completion transition has not been triggered
        let feed = ExperienceEngine.prepareDiscoveryFeed(from: pool, featuredEntry: pool[0], feedOrder: [1, 2, 3], seenIDs: allSeenIDs)
        XCTAssertEqual(feed.count, 1, "Only featured entry remains when all words are seen")
        XCTAssertFalse(ExperienceEngine.isCollectionCompleted(in: testDefaults), "Viewing all entries alone must NOT complete the collection")
        XCTAssertTrue(ExperienceEngine.isReminderEligible(in: testDefaults), "Learner remains reminder-eligible until collection completion is triggered")
        
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isReminderEligibleKey)
    }
    
    // Issue #3 - Criterion 5, 6 & 8: Completion transition persists and makes reminder eligibility false
    func testCompletionTransition_advancingBeyondFinalEntryCompletesAndDisablesReminders() {
        let testSuiteName = "test.discovery.feed.completion.transition"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isReminderEligibleKey)
        
        XCTAssertFalse(ExperienceEngine.isCollectionCompleted(in: testDefaults))
        XCTAssertTrue(ExperienceEngine.isReminderEligible(in: testDefaults))
        
        // Advancing beyond final entry triggers completion
        ExperienceEngine.markCollectionCompleted(in: testDefaults)
        
        XCTAssertTrue(ExperienceEngine.isCollectionCompleted(in: testDefaults), "Completion state must be persisted as true")
        XCTAssertFalse(ExperienceEngine.isReminderEligible(in: testDefaults), "Reminder eligibility must become false upon completion")
        
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isReminderEligibleKey)
    }
    
    // Issue #3 - Criterion 7: Widgets continue receiving featured entries after feed completion
    func testWidgetsContinueReceivingFeaturedEntries_afterFeedCompletion() {
        let testSuiteName = "test.discovery.feed.widgets"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        ExperienceEngine.markCollectionCompleted(in: testDefaults)
        
        XCTAssertTrue(ExperienceEngine.isCollectionCompleted(in: testDefaults))
        
        let samplePool: [WordItem] = (1...3).map { id in
            WordItem(id: id, kazakh: "сөз_\(id)", partOfSpeech: "зат есім", translation: "слово_\(id)", example: "мысал_\(id)", phonetic: nil, details: nil, additionalExamples: nil)
        }
        
        let widgetEntry = ExperienceEngine.featuredEntry(from: samplePool, for: Date())
        XCTAssertNotNil(widgetEntry, "Widgets must continue receiving featured entries after feed completion")
        
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isReminderEligibleKey)
    }
    
    // Issue #3 - Canonical Russian completion message matches specification
    func testAgreedRussianCompletionMessage_matchesSpecificationVerbatim() {
        let expected = "Упс, похоже, слова закончились! Поздравляем, вы протестировали первую версию моего приложения!"
        XCTAssertEqual(ExperienceEngine.completionMessage, expected, "Agreed Russian completion message must match verbatim")
    }
}
