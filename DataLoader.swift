import Foundation

struct WordItem: Codable, Identifiable {
    let id: Int
    let kazakh: String
    let partOfSpeech: String
    let translation: String
    let example: String
    let phonetic: String?
    let details: String?
    let additionalExamples: [String]?
}

func loadWords() -> [WordItem] {
    guard let url = Bundle.main.url(forResource: "words", withExtension: "json") else {
        return []
    }
    
    do {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([WordItem].self, from: data)
    } catch {
        return []
    }
}
