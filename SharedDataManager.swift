import Foundation

struct SharedDataManager {
    static let appGroupID = "group.com.yourname.QazaqVocab"
    private static let userDefaults = UserDefaults(suiteName: appGroupID)
    
    private static let currentWidgetWordKey = "widget_active_word_id"
    
    static func getDailyWord(from allWords: [WordItem]) -> WordItem? {
        guard !allWords.isEmpty else { return nil }
        
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let wordIndex = (dayOfYear - 1) % allWords.count
        
        return allWords[wordIndex]
    }
    
    static func saveActiveWordID(_ id: Int) {
        userDefaults?.set(id, forKey: currentWidgetWordKey)
    }
    
    static func getActiveWordID() -> Int? {
        return userDefaults?.integer(forKey: currentWidgetWordKey)
    }
}
