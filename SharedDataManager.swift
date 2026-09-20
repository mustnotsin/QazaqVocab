import Foundation

enum ExperienceEngine {
    static let appGroupID = "group.com.beksultan.QazaqVocab"
    static let activeWordIDKey = "widget_active_word_id"
    static let seenWordIDsKey = "seen_word_ids"
    static let discoveryFeedOrderKey = "discovery_feed_order"
    static let isCollectionCompletedKey = "collection_completed"
    static let isReminderEligibleKey = "reminder_eligible"
    
    // MARK: - First-Time Setup & Daily Reminders (Issue #10)
    static let hasCompletedFirstTimeSetupKey = "has_completed_first_time_setup"
    static let dailyReminderHourKey = "daily_reminder_hour"
    static let dailyReminderMinuteKey = "daily_reminder_minute"
    static let isReminderEnabledKey = "daily_reminder_enabled"
    static let dailyReminderIdentifier = "qazaqvocab_daily_reminder"
    static let notificationDestinationKey = "destination"
    static let featuredWordDestination = "featured_word"
    
    static let defaultReminderHour = 10
    static let defaultReminderMinute = 0
    
    /// Canonical Russian completion message acknowledging TestFlight testers upon exhausting all unseen entries.
    static let completionMessage = "Упс, похоже, слова закончились! Поздравляем, вы протестировали первую версию моего приложения!"
    
    /// Deterministically selects the featured daily word for a given calendar date from a vocabulary pool.
    /// The same calendar date always produces the exact same featured entry regardless of the time of day.
    static func featuredEntry(
        from pool: [WordItem],
        for date: Date = Date(),
        in calendar: Calendar = Calendar.current
    ) -> WordItem? {
        guard !pool.isEmpty else { return nil }
        
        let startOfDay = calendar.startOfDay(for: date)
        let dayOrdinal = calendar.ordinality(of: .day, in: .era, for: startOfDay) ?? 0
        let index = abs(dayOrdinal) % pool.count
        
        return pool[index]
    }
    
    /// Prepares the Words section feed.
    /// The featured daily word always appears first (index 0) even if previously seen.
    /// The remaining entries from the pool follow without duplicating the featured entry.
    static func prepareWordsFeed(
        from pool: [WordItem],
        featuredEntry: WordItem?,
        seenIDs: Set<Int>
    ) -> [WordItem] {
        guard !pool.isEmpty else { return [] }
        guard let featured = featuredEntry ?? pool.first else { return pool }
        
        let remaining = pool.filter { $0.id != featured.id }
        let unseen = remaining.filter { !seenIDs.contains($0.id) }
        let seen = remaining.filter { seenIDs.contains($0.id) }
        
        return [featured] + unseen + seen
    }
    
    /// Retrieves or initializes the learner's shuffled discovery feed order.
    /// If an order is already persisted in the given defaults, it is loaded.
    /// Otherwise, the pool's IDs are shuffled (or passed through `shuffler`) and persisted.
    static func getOrInitializeDiscoveryFeedOrder(
        from pool: [WordItem],
        defaults: UserDefaults? = UserDefaults(suiteName: appGroupID),
        shuffler: ([Int]) -> [Int] = { $0.shuffled() }
    ) -> [Int] {
        let poolIDs = pool.map(\.id)
        guard !poolIDs.isEmpty else { return [] }
        
        var existingOrder: [Int] = []
        if let defaults = defaults,
           let data = defaults.string(forKey: discoveryFeedOrderKey)?.data(using: .utf8),
           let saved = try? JSONDecoder().decode([Int].self, from: data) {
            existingOrder = saved
        }
        
        if existingOrder.isEmpty {
            let shuffled = shuffler(poolIDs)
            saveDiscoveryFeedOrder(shuffled, in: defaults)
            return shuffled
        } else {
            let poolSet = Set(poolIDs)
            var consolidated = existingOrder.filter { poolSet.contains($0) }
            let consolidatedSet = Set(consolidated)
            let newIDs = poolIDs.filter { !consolidatedSet.contains($0) }
            if !newIDs.isEmpty {
                consolidated.append(contentsOf: shuffler(newIDs))
                saveDiscoveryFeedOrder(consolidated, in: defaults)
            }
            return consolidated
        }
    }
    
    /// Persists the discovery feed order to storage.
    static func saveDiscoveryFeedOrder(_ order: [Int], in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) {
        guard let defaults = defaults,
              let data = try? JSONEncoder().encode(order),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        defaults.set(string, forKey: discoveryFeedOrderKey)
    }
    
    /// Prepares the finite discovery feed.
    /// Today's featured entry is always index 0 (even if previously seen).
    /// Followed by all remaining UNSEEN entries from `feedOrder` in their persisted relative order.
    /// If today's featured entry is present in `feedOrder`, it is excluded from the remaining list so it never appears twice.
    /// All entries in `seenIDs` are excluded from the remaining list.
    static func prepareDiscoveryFeed(
        from pool: [WordItem],
        featuredEntry: WordItem?,
        feedOrder: [Int],
        seenIDs: Set<Int>
    ) -> [WordItem] {
        guard !pool.isEmpty else { return [] }
        let wordsByID = Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
        
        var result: [WordItem] = []
        let featuredID = featuredEntry?.id
        
        if let featured = featuredEntry {
            result.append(featured)
        } else if let first = pool.first {
            result.append(first)
        }
        
        let excludedIDs: Set<Int> = Set(seenIDs).union(featuredID.map { [$0] } ?? [])
        
        for id in feedOrder {
            if !excludedIDs.contains(id), let word = wordsByID[id] {
                result.append(word)
            }
        }
        
        return result
    }
    
    /// Returns whether the learner has completed the finite TestFlight collection.
    static func isCollectionCompleted(in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Bool {
        defaults?.bool(forKey: isCollectionCompletedKey) ?? false
    }
    
    /// Returns whether the learner is eligible for daily reminders.
    /// Completion of the collection marks reminder eligibility false.
    static func isReminderEligible(in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Bool {
        guard let defaults = defaults else { return true }
        if defaults.object(forKey: isReminderEligibleKey) == nil {
            return !isCollectionCompleted(in: defaults)
        }
        return defaults.bool(forKey: isReminderEligibleKey)
    }
    
    /// Marks the finite TestFlight collection as completed and disables reminder eligibility.
    static func markCollectionCompleted(in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) {
        defaults?.set(true, forKey: isCollectionCompletedKey)
        defaults?.set(false, forKey: isReminderEligibleKey)
    }
    
    /// Saves the active featured word ID into shared user defaults for widget access.
    static func saveActiveWordID(_ id: Int, in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) {
        defaults?.set(id, forKey: activeWordIDKey)
    }
    
    /// Retrieves the active featured word ID from shared user defaults.
    static func getActiveWordID(from defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Int? {
        guard let defaults = defaults, defaults.object(forKey: activeWordIDKey) != nil else {
            return nil
        }
        return defaults.integer(forKey: activeWordIDKey)
    }
    
    // MARK: - Setup & Reminder State Helpers (Issue #10)
    
    /// Returns whether the learner has completed first-time setup.
    static func hasCompletedFirstTimeSetup(in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Bool {
        defaults?.bool(forKey: hasCompletedFirstTimeSetupKey) ?? false
    }
    
    /// Persists whether the learner has completed first-time setup.
    static func setFirstTimeSetupCompleted(_ completed: Bool = true, in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) {
        defaults?.set(completed, forKey: hasCompletedFirstTimeSetupKey)
    }
    
    /// Retrieves the chosen reminder time (hour, minute), defaulting to 10:00 if not previously set.
    static func getReminderTime(from defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> (hour: Int, minute: Int) {
        guard let defaults = defaults, defaults.object(forKey: dailyReminderHourKey) != nil else {
            return (defaultReminderHour, defaultReminderMinute)
        }
        let hour = defaults.integer(forKey: dailyReminderHourKey)
        let minute = defaults.integer(forKey: dailyReminderMinuteKey)
        return (hour, minute)
    }
    
    /// Persists the chosen reminder time.
    static func saveReminderTime(hour: Int, minute: Int, in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) {
        defaults?.set(hour, forKey: dailyReminderHourKey)
        defaults?.set(minute, forKey: dailyReminderMinuteKey)
    }
    
    /// Returns whether reminders are enabled by the learner.
    static func isReminderEnabled(in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Bool {
        defaults?.bool(forKey: isReminderEnabledKey) ?? false
    }
    
    /// Persists reminder enabled state.
    static func setReminderEnabled(_ enabled: Bool, in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) {
        defaults?.set(enabled, forKey: isReminderEnabledKey)
    }
    
    // MARK: - Saved Words Management (Issue #4)
    
    static let savedWordIDsKey = "saved_word_ids"
    static let legacyFavoriteWordIDsKey = "favorite_word_ids"
    static let legacyWantToLearnIDsKey = "want_to_learn_ids"
    static let hasMigratedSavedWordsKey = "has_migrated_saved_words"
    
    /// Retrieves the learner's set of saved word IDs.
    static func getSavedWordIDs(from defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Set<Int> {
        guard let defaults = defaults,
              let raw = defaults.string(forKey: savedWordIDsKey),
              let data = raw.data(using: .utf8),
              let array = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return Set(array)
    }
    
    /// Persists the learner's set of saved word IDs.
    static func saveSavedWordIDs(_ ids: Set<Int>, in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) {
        guard let defaults = defaults,
              let data = try? JSONEncoder().encode(Array(ids)),
              let string = String(data: data, encoding: .utf8) else {
            return
        }
        defaults.set(string, forKey: savedWordIDsKey)
    }
    
    /// Toggles the saved state for a word ID and returns the updated set of saved word IDs.
    @discardableResult
    static func toggleSavedWordID(_ id: Int, in defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Set<Int> {
        var current = getSavedWordIDs(from: defaults)
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        saveSavedWordIDs(current, in: defaults)
        return current
    }
    
    /// Migrates existing selections from legacy Favorites and Want to Learn into Saved without duplicates.
    @discardableResult
    static func migrateLegacySavedSelectionsIfNeeded(defaults: UserDefaults? = UserDefaults(suiteName: appGroupID)) -> Set<Int> {
        guard let defaults = defaults else { return [] }
        var currentSaved = getSavedWordIDs(from: defaults)
        
        func decodeSet(forKey key: String) -> Set<Int> {
            if let raw = defaults.string(forKey: key),
               let data = raw.data(using: .utf8),
               let array = try? JSONDecoder().decode([Int].self, from: data) {
                return Set(array)
            } else if let array = defaults.array(forKey: key) as? [Int] {
                return Set(array)
            }
            return []
        }
        
        let legacyFavorites = decodeSet(forKey: legacyFavoriteWordIDsKey)
        let legacyWantToLearn = decodeSet(forKey: legacyWantToLearnIDsKey)
        
        if !legacyFavorites.isEmpty || !legacyWantToLearn.isEmpty {
            currentSaved.formUnion(legacyFavorites)
            currentSaved.formUnion(legacyWantToLearn)
            saveSavedWordIDs(currentSaved, in: defaults)
            defaults.set(true, forKey: hasMigratedSavedWordsKey)
        }
        
        return currentSaved
    }
    
    /// Filters and returns the vocabulary entries matching the saved word IDs.
    static func filterSavedWords(from pool: [WordItem], savedIDs: Set<Int>) -> [WordItem] {
        pool.filter { savedIDs.contains($0.id) }
    }
}

struct SharedDataManager {
    static let appGroupID = ExperienceEngine.appGroupID
    
    static func getDailyWord(from allWords: [WordItem]) -> WordItem? {
        ExperienceEngine.featuredEntry(from: allWords)
    }
    
    static func saveActiveWordID(_ id: Int) {
        ExperienceEngine.saveActiveWordID(id)
    }
    
    static func getActiveWordID() -> Int? {
        ExperienceEngine.getActiveWordID()
    }
}
