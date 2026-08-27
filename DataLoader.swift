import Foundation

// 1. Data model matching your JSON keys
struct WordItem: Codable, Identifiable {
    let id: Int
    let kazakh: String
    let partOfSpeech: String
    let translation: String
    let example: String
}

// 2. Helper function to read and decode words.json from the app bundle
func loadWords() -> [WordItem] {
    guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
        print("Error: words.json not found in bundle.")
        return []
    }
    
    do {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode([WordItem].self, from: data)
        return decoded
    } catch {
        print("Error decoding JSON: \(error)")
        return []
    }
}
