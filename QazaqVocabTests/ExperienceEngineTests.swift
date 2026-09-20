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
    
    // MARK: - Issue #4 Saved Words Tests
    
    // Issue #4 - Criterion 2 & 8: Migration combines legacy selections without duplicates
    func testMigration_combinesLegacyFavoritesAndWantToLearnWithoutDuplicates() {
        let testSuiteName = "test.saved.migration"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removeObject(forKey: ExperienceEngine.savedWordIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.legacyFavoriteWordIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.legacyWantToLearnIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.hasMigratedSavedWordsKey)
        
        // Populate legacy data
        let legacyFavorites = [1, 2, 3]
        let legacyWantToLearn = [2, 3, 4, 5]
        testDefaults.set("[1, 2, 3]", forKey: ExperienceEngine.legacyFavoriteWordIDsKey)
        testDefaults.set("[2, 3, 4, 5]", forKey: ExperienceEngine.legacyWantToLearnIDsKey)
        
        let migrated = ExperienceEngine.migrateLegacySavedSelectionsIfNeeded(defaults: testDefaults)
        
        XCTAssertEqual(migrated, Set([1, 2, 3, 4, 5]), "Migrated set must be the union of legacy selections")
        XCTAssertEqual(migrated.count, 5, "Migrated set must contain zero duplicate entries")
        
        let retrieved = ExperienceEngine.getSavedWordIDs(from: testDefaults)
        XCTAssertEqual(retrieved, Set([1, 2, 3, 4, 5]), "Saved word IDs in storage must match migrated set")
        
        testDefaults.removeObject(forKey: ExperienceEngine.savedWordIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.legacyFavoriteWordIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.legacyWantToLearnIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.hasMigratedSavedWordsKey)
    }
    
    // Issue #4 - Criterion 3, 4 & 8: Save/unsave toggle and persistence
    func testSavedToggleAndPersistence_addsAndRemovesWordID() {
        let testSuiteName = "test.saved.toggle"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removeObject(forKey: ExperienceEngine.savedWordIDsKey)
        
        XCTAssertTrue(ExperienceEngine.getSavedWordIDs(from: testDefaults).isEmpty)
        
        // Save word ID 42
        let afterSave = ExperienceEngine.toggleSavedWordID(42, in: testDefaults)
        XCTAssertTrue(afterSave.contains(42), "Word ID 42 must be saved")
        XCTAssertEqual(ExperienceEngine.getSavedWordIDs(from: testDefaults), Set([42]), "Saved word ID 42 must persist")
        
        // Unsave word ID 42
        let afterUnsave = ExperienceEngine.toggleSavedWordID(42, in: testDefaults)
        XCTAssertFalse(afterUnsave.contains(42), "Word ID 42 must be removed after toggling again")
        XCTAssertTrue(ExperienceEngine.getSavedWordIDs(from: testDefaults).isEmpty, "Saved word IDs must be empty after unsave")
        
        testDefaults.removeObject(forKey: ExperienceEngine.savedWordIDsKey)
    }
    
    // Issue #4 - Criterion 6 & 8: Saved words remain available after collection completion
    func testFilterSavedWords_preservesEntriesIndependentlyOfCompletion() {
        let testSuiteName = "test.saved.completion.independence"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removeObject(forKey: ExperienceEngine.savedWordIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
        
        // Mark collection as completed
        ExperienceEngine.markCollectionCompleted(in: testDefaults)
        XCTAssertTrue(ExperienceEngine.isCollectionCompleted(in: testDefaults))
        
        let pool: [WordItem] = (1...5).map { id in
            WordItem(id: id, kazakh: "сөз_\(id)", partOfSpeech: "зат есім", translation: "слово_\(id)", example: "мысал_\(id)", phonetic: nil, details: nil, additionalExamples: nil)
        }
        
        let savedIDs: Set<Int> = [2, 4]
        ExperienceEngine.saveSavedWordIDs(savedIDs, in: testDefaults)
        
        let savedWords = ExperienceEngine.filterSavedWords(from: pool, savedIDs: ExperienceEngine.getSavedWordIDs(from: testDefaults))
        
        XCTAssertEqual(savedWords.count, 2, "Saved words count must be preserved")
        XCTAssertEqual(Set(savedWords.map(\.id)), Set([2, 4]), "Saved words entries must remain completely accessible after collection completion")
        
        testDefaults.removeObject(forKey: ExperienceEngine.savedWordIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.isCollectionCompletedKey)
    }
    
    // MARK: - Issue #5 Russian-First Vocabulary Experience Tests
    
    // Issue #5 - Criterion 1: Vocabulary entry supports all agreed Kazakh/Russian fields
    func testVocabularyEntry_supportsAllAgreedKazakhAndRussianFields() {
        let entry = WordItem(
            id: 1,
            kazakh: "сәуле",
            transliteration: "säwle",
            partOfSpeech: "существительное",
            meaning: "Луч / луч света",
            primaryExample: BilingualExample(
                kazakh: "Күн сәулесі бөлмеге түсті.",
                russian: "Солнечный луч проник в комнату."
            ),
            usageExplanation: "Обозначает луч света, а в переносном смысле — тепло и надежду.",
            additionalExamples: [
                BilingualExample(
                    kazakh: "Үміт сәулесі жүрегімді жылытты.",
                    russian: "Луч надежды согрел моё сердце."
                ),
                BilingualExample(
                    kazakh: "Шам сәулесі қараңғыны сейілтті.",
                    russian: "Свет лампы рассеял темноту."
                )
            ]
        )
        
        XCTAssertEqual(entry.kazakh, "сәуле")
        XCTAssertEqual(entry.transliteration, "säwle")
        XCTAssertEqual(entry.partOfSpeech, "существительное")
        XCTAssertEqual(entry.meaning, "Луч / луч света")
        XCTAssertEqual(entry.primaryExample.kazakh, "Күн сәулесі бөлмеге түсті.")
        XCTAssertEqual(entry.primaryExample.russian, "Солнечный луч проник в комнату.")
        XCTAssertNotNil(entry.usageExplanation)
        XCTAssertEqual(entry.additionalExamples?.count, 2)
        XCTAssertEqual(entry.additionalExamples?[0].kazakh, "Үміт сәулесі жүрегімді жылытты.")
        XCTAssertEqual(entry.additionalExamples?[0].russian, "Луч надежды согрел моё сердце.")
    }
    
    // Issue #5 - Criterion 6: Structural validation passes for complete valid entries
    func testStructuralValidation_passesForValidEntry() {
        let validEntry = WordItem(
            id: 1,
            kazakh: "батыл",
            transliteration: "batyl",
            partOfSpeech: "прилагательное",
            meaning: "Смелый / решительный",
            primaryExample: BilingualExample(
                kazakh: "Ол өте батыл шешім қабылдады.",
                russian: "Он принял очень смелое решение."
            ),
            usageExplanation: "Описывает решительного человека.",
            additionalExamples: [
                BilingualExample(
                    kazakh: "Батыл қадам жасаудан қорықпа.",
                    russian: "Не бойся делать смелый шаг."
                )
            ]
        )
        
        XCTAssertNoThrow(try VocabularyValidator.validate(entry: validEntry))
    }
    
    // Issue #5 - Criterion 6: Validation rejects missing required fields
    func testStructuralValidation_rejectsMissingRequiredFields() {
        let missingKazakh = WordItem(
            id: 1,
            kazakh: "   ",
            transliteration: "batyl",
            partOfSpeech: "прилагательное",
            meaning: "Смелый",
            primaryExample: BilingualExample(kazakh: "Мысал", russian: "Пример")
        )
        XCTAssertThrowsError(try VocabularyValidator.validate(entry: missingKazakh)) { error in
            XCTAssertEqual(error as? VocabularyValidationError, .missingRequiredField(id: 1, field: "kazakh"))
        }
        
        let missingTranslit = WordItem(
            id: 2,
            kazakh: "батыл",
            transliteration: "",
            partOfSpeech: "прилагательное",
            meaning: "Смелый",
            primaryExample: BilingualExample(kazakh: "Мысал", russian: "Пример")
        )
        XCTAssertThrowsError(try VocabularyValidator.validate(entry: missingTranslit)) { error in
            XCTAssertEqual(error as? VocabularyValidationError, .missingRequiredField(id: 2, field: "transliteration"))
        }
        
        let missingPos = WordItem(
            id: 3,
            kazakh: "батыл",
            transliteration: "batyl",
            partOfSpeech: "\n",
            meaning: "Смелый",
            primaryExample: BilingualExample(kazakh: "Мысал", russian: "Пример")
        )
        XCTAssertThrowsError(try VocabularyValidator.validate(entry: missingPos)) { error in
            XCTAssertEqual(error as? VocabularyValidationError, .missingRequiredField(id: 3, field: "partOfSpeech"))
        }
        
        let missingMeaning = WordItem(
            id: 4,
            kazakh: "батыл",
            transliteration: "batyl",
            partOfSpeech: "прилагательное",
            meaning: "",
            primaryExample: BilingualExample(kazakh: "Мысал", russian: "Пример")
        )
        XCTAssertThrowsError(try VocabularyValidator.validate(entry: missingMeaning)) { error in
            XCTAssertEqual(error as? VocabularyValidationError, .missingRequiredField(id: 4, field: "meaning"))
        }
    }
    
    // Issue #5 - Criterion 6: Validation rejects malformed primary and additional bilingual examples
    func testStructuralValidation_rejectsMalformedBilingualExamples() {
        let emptyKazakhPrimary = WordItem(
            id: 1,
            kazakh: "батыл",
            transliteration: "batyl",
            partOfSpeech: "прилагательное",
            meaning: "Смелый",
            primaryExample: BilingualExample(kazakh: "", russian: "Он смелый.")
        )
        XCTAssertThrowsError(try VocabularyValidator.validate(entry: emptyKazakhPrimary)) { error in
            if case .malformedBilingualExample(let id, _) = error as? VocabularyValidationError {
                XCTAssertEqual(id, 1)
            } else {
                XCTFail("Expected malformedBilingualExample error")
            }
        }
        
        let emptyRussianPrimary = WordItem(
            id: 2,
            kazakh: "батыл",
            transliteration: "batyl",
            partOfSpeech: "прилагательное",
            meaning: "Смелый",
            primaryExample: BilingualExample(kazakh: "Ол батыл.", russian: "   ")
        )
        XCTAssertThrowsError(try VocabularyValidator.validate(entry: emptyRussianPrimary)) { error in
            if case .malformedBilingualExample(let id, _) = error as? VocabularyValidationError {
                XCTAssertEqual(id, 2)
            } else {
                XCTFail("Expected malformedBilingualExample error")
            }
        }
        
        let malformedAdditional = WordItem(
            id: 3,
            kazakh: "батыл",
            transliteration: "batyl",
            partOfSpeech: "прилагательное",
            meaning: "Смелый",
            primaryExample: BilingualExample(kazakh: "Ол батыл.", russian: "Он смелый."),
            additionalExamples: [
                BilingualExample(kazakh: "Жаңа мысал.", russian: "")
            ]
        )
        XCTAssertThrowsError(try VocabularyValidator.validate(entry: malformedAdditional)) { error in
            if case .malformedBilingualExample(let id, _) = error as? VocabularyValidationError {
                XCTAssertEqual(id, 3)
            } else {
                XCTFail("Expected malformedBilingualExample error for empty translation in additional example")
            }
        }
    }
    
    // Issue #5 - Criterion 6: Validation rejects more than two additional examples
    func testStructuralValidation_rejectsExcessiveAdditionalExamples() {
        let threeAdditionals = WordItem(
            id: 1,
            kazakh: "батыл",
            transliteration: "batyl",
            partOfSpeech: "прилагательное",
            meaning: "Смелый",
            primaryExample: BilingualExample(kazakh: "Ол батыл.", russian: "Он смелый."),
            additionalExamples: [
                BilingualExample(kazakh: "Мысал 1", russian: "Пример 1"),
                BilingualExample(kazakh: "Мысал 2", russian: "Пример 2"),
                BilingualExample(kazakh: "Мысал 3", russian: "Пример 3")
            ]
        )
        XCTAssertThrowsError(try VocabularyValidator.validate(entry: threeAdditionals)) { error in
            XCTAssertEqual(error as? VocabularyValidationError, .excessiveAdditionalExamples(id: 1, count: 3))
        }
    }
    
    // Issue #5 - Criterion 6: Validation rejects duplicate IDs and empty collections
    func testStructuralValidation_rejectsDuplicateIDsAndEmptyCollections() {
        XCTAssertThrowsError(try VocabularyValidator.validate(collection: [])) { error in
            XCTAssertEqual(error as? VocabularyValidationError, .emptyCollection)
        }
        
        let item1 = WordItem(
            id: 5,
            kazakh: "сөз",
            transliteration: "söz",
            partOfSpeech: "существительное",
            meaning: "Слово",
            primaryExample: BilingualExample(kazakh: "Жақсы сөз", russian: "Хорошее слово")
        )
        let item2 = WordItem(
            id: 5,
            kazakh: "басқа",
            transliteration: "basqa",
            partOfSpeech: "прилагательное",
            meaning: "Другой",
            primaryExample: BilingualExample(kazakh: "Басқа адам", russian: "Другой человек")
        )
        
        XCTAssertThrowsError(try VocabularyValidator.validate(collection: [item1, item2])) { error in
            XCTAssertEqual(error as? VocabularyValidationError, .duplicateID(id: 5))
        }
    }
    
    // Issue #5 - Criterion 5: VocabularyLoader reports recoverable error on corrupted data or missing resource
    func testVocabularyLoader_reportsRecoverableErrors() {
        // Missing resource
        let missingResult = VocabularyLoader.loadFromBundle(resource: "non_existent_file")
        switch missingResult {
        case .failure(let error):
            XCTAssertEqual(error, .fileNotFound)
            XCTAssertEqual(error.localizedDescription, "Файл словаря не найден.")
        case .success:
            XCTFail("Expected fileNotFound failure")
        }
        
        // Corrupted JSON data
        let corruptedData = "invalid json {".data(using: .utf8)!
        let corruptedResult = VocabularyLoader.load(fromData: corruptedData)
        switch corruptedResult {
        case .failure(let error):
            if case .dataCorrupted = error {
                XCTAssertTrue(error.localizedDescription.contains("Не удалось прочитать данные"))
            } else {
                XCTFail("Expected dataCorrupted error")
            }
        case .success:
            XCTFail("Expected corrupted data failure")
        }
        
        // Data with structural validation failure
        let invalidEntryJSON = """
        [
            {
                "id": 1,
                "kazakh": "",
                "transliteration": "test",
                "partOfSpeech": "существительное",
                "meaning": "тест",
                "primaryExample": {
                    "kazakh": "test",
                    "russian": "тест"
                }
            }
        ]
        """.data(using: .utf8)!
        
        let invalidResult = VocabularyLoader.load(fromData: invalidEntryJSON)
        switch invalidResult {
        case .failure(let error):
            if case .validationFailed(let valError) = error {
                XCTAssertEqual(valError, .missingRequiredField(id: 1, field: "kazakh"))
            } else {
                XCTFail("Expected validationFailed error")
            }
        case .success:
            XCTFail("Expected validation failure")
        }
    }
    
    // Issue #5 - Criterion 5 & 6: Bundled words.json loads and passes full validation
    func testBundledWords_loadsAndPassesFullStructuralValidation() {
        let words = loadWords()
        XCTAssertFalse(words.isEmpty, "Bundled words must not be empty")
        XCTAssertNoThrow(try VocabularyValidator.validate(collection: words), "Bundled words must pass full structural validation")
        
        for word in words {
            XCTAssertFalse(word.kazakh.isEmpty)
            XCTAssertFalse(word.transliteration.isEmpty)
            XCTAssertFalse(word.partOfSpeech.isEmpty)
            XCTAssertFalse(word.meaning.isEmpty)
            XCTAssertFalse(word.primaryExample.kazakh.isEmpty)
            XCTAssertFalse(word.primaryExample.russian.isEmpty)
            if let additionals = word.additionalExamples {
                XCTAssertLessThanOrEqual(additionals.count, 2)
                for ex in additionals {
                    XCTAssertFalse(ex.kazakh.isEmpty)
                    XCTAssertFalse(ex.russian.isEmpty)
                }
            }
        }
    }
    
    // Issue #5 - Criterion 7: Russian-first entries remain compatible with engine algorithms
    func testRussianFirstEntries_remainCompatibleWithFeaturedFeedAndSaved() {
        let testSuiteName = "test.russian.first.compatibility"
        let testDefaults = UserDefaults(suiteName: testSuiteName)!
        testDefaults.removeObject(forKey: ExperienceEngine.savedWordIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.discoveryFeedOrderKey)
        
        let pool = loadWords()
        XCTAssertFalse(pool.isEmpty)
        
        // 1. Featured daily word works with pool
        let featured = ExperienceEngine.featuredEntry(from: pool, for: Date())
        XCTAssertNotNil(featured)
        XCTAssertFalse(featured!.meaning.isEmpty)
        XCTAssertFalse(featured!.primaryExample.russian.isEmpty)
        
        // 2. Discovery feed preparation works with pool
        let feedOrder = ExperienceEngine.getOrInitializeDiscoveryFeedOrder(from: pool, defaults: testDefaults)
        let feed = ExperienceEngine.prepareDiscoveryFeed(from: pool, featuredEntry: featured, feedOrder: feedOrder, seenIDs: [])
        XCTAssertEqual(feed.count, pool.count)
        XCTAssertEqual(feed.first?.id, featured?.id)
        
        // 3. Saved filtering works with pool
        let savedIDs: Set<Int> = [pool[0].id, pool[1].id]
        ExperienceEngine.saveSavedWordIDs(savedIDs, in: testDefaults)
        let savedWords = ExperienceEngine.filterSavedWords(from: pool, savedIDs: ExperienceEngine.getSavedWordIDs(from: testDefaults))
        XCTAssertEqual(savedWords.count, 2)
        XCTAssertEqual(savedWords[0].meaning, pool[0].meaning)
        
        testDefaults.removeObject(forKey: ExperienceEngine.savedWordIDsKey)
        testDefaults.removeObject(forKey: ExperienceEngine.discoveryFeedOrderKey)
    }
    
    // Issue #6 - Acceptance Criteria: 10 basic everyday entries pass collection validation
    func testCuratedBasicEverydayEntries_passStructuralValidation() throws {
        let fileURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("QazaqVocab/CuratedContent/basic_everyday.json")
        
        let result = VocabularyLoader.load(from: fileURL)
        switch result {
        case .success(let items):
            XCTAssertEqual(items.count, 10, "Curated basic everyday collection must contain exactly 10 entries")
            XCTAssertNoThrow(try VocabularyValidator.validate(collection: items), "Basic everyday collection must pass validation")
            
            // Check that every entry has all required fields and Russian-first clarity
            for item in items {
                XCTAssertFalse(item.kazakh.isEmpty)
                XCTAssertFalse(item.transliteration.isEmpty)
                XCTAssertFalse(item.partOfSpeech.isEmpty)
                XCTAssertFalse(item.meaning.isEmpty)
                XCTAssertFalse(item.primaryExample.kazakh.isEmpty)
                XCTAssertFalse(item.primaryExample.russian.isEmpty)
                XCTAssertNotNil(item.usageExplanation)
                XCTAssertFalse(item.usageExplanation!.isEmpty)
                if let additionals = item.additionalExamples {
                    XCTAssertLessThanOrEqual(additionals.count, 2)
                    for ex in additionals {
                        XCTAssertFalse(ex.kazakh.isEmpty)
                        XCTAssertFalse(ex.russian.isEmpty)
                    }
                }
            }
        case .failure(let error):
            XCTFail("Failed to load basic everyday entries: \(error)")
        }
    }
    
    // Issue #7 - Acceptance Criteria: 10 conversational entries pass collection validation
    func testCuratedConversationalEntries_passStructuralValidation() throws {
        let fileURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("QazaqVocab/CuratedContent/conversational.json")
        
        let result = VocabularyLoader.load(from: fileURL)
        switch result {
        case .success(let items):
            XCTAssertEqual(items.count, 10, "Curated conversational collection must contain exactly 10 entries")
            XCTAssertNoThrow(try VocabularyValidator.validate(collection: items), "Conversational collection must pass validation")
            
            for item in items {
                XCTAssertFalse(item.kazakh.isEmpty)
                XCTAssertFalse(item.transliteration.isEmpty)
                XCTAssertFalse(item.partOfSpeech.isEmpty)
                XCTAssertFalse(item.meaning.isEmpty)
                XCTAssertFalse(item.primaryExample.kazakh.isEmpty)
                XCTAssertFalse(item.primaryExample.russian.isEmpty)
                XCTAssertNotNil(item.usageExplanation)
                XCTAssertFalse(item.usageExplanation!.isEmpty)
                if let additionals = item.additionalExamples {
                    XCTAssertLessThanOrEqual(additionals.count, 2)
                    for ex in additionals {
                        XCTAssertFalse(ex.kazakh.isEmpty)
                        XCTAssertFalse(ex.russian.isEmpty)
                    }
                }
            }
        case .failure(let error):
            XCTFail("Failed to load conversational entries: \(error)")
        }
    }
    
    // Issue #8 - Acceptance Criteria: 10 expressive and cultural entries pass collection validation and resolve duplicate parasat
    func testCuratedExpressiveCulturalEntries_passStructuralValidation() throws {
        let fileURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("QazaqVocab/CuratedContent/expressive_cultural.json")
        
        let result = VocabularyLoader.load(from: fileURL)
        switch result {
        case .success(let items):
            XCTAssertEqual(items.count, 10, "Curated expressive/cultural collection must contain exactly 10 entries")
            XCTAssertNoThrow(try VocabularyValidator.validate(collection: items), "Expressive/cultural collection must pass validation")
            
            // Acceptance criterion: Duplicate existing parasat entries are resolved intentionally (exactly one parasat entry)
            let parasatEntries = items.filter { $0.kazakh == "парасат" }
            XCTAssertEqual(parasatEntries.count, 1, "Duplicate parasat entries must be resolved to exactly 1 curated entry")
            
            // Acceptance criterion: All 10 entries have unique words
            let uniqueWords = Set(items.map { $0.kazakh })
            XCTAssertEqual(uniqueWords.count, 10, "All 10 expressive/cultural entries must be distinct words")
            
            for item in items {
                XCTAssertFalse(item.kazakh.isEmpty)
                XCTAssertFalse(item.transliteration.isEmpty)
                XCTAssertFalse(item.partOfSpeech.isEmpty)
                XCTAssertFalse(item.meaning.isEmpty)
                XCTAssertFalse(item.primaryExample.kazakh.isEmpty)
                XCTAssertFalse(item.primaryExample.russian.isEmpty)
                XCTAssertNotNil(item.usageExplanation)
                XCTAssertFalse(item.usageExplanation!.isEmpty)
                if let additionals = item.additionalExamples {
                    XCTAssertLessThanOrEqual(additionals.count, 2)
                    for ex in additionals {
                        XCTAssertFalse(ex.kazakh.isEmpty)
                        XCTAssertFalse(ex.russian.isEmpty)
                    }
                }
            }
        case .failure(let error):
            XCTFail("Failed to load expressive/cultural entries: \(error)")
        }
    }
}



