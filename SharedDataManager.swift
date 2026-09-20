import Foundation

enum ExperienceEngine {
    static let appGroupID = "group.com.beksultan.QazaqVocab"
    static let activeWordIDKey = "widget_active_word_id"
    
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
