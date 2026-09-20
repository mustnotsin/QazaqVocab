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
}
