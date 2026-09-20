import Foundation

public struct BilingualExample: Codable, Equatable, Hashable {
    public let kazakh: String
    public let russian: String
    
    public init(kazakh: String, russian: String) {
        self.kazakh = kazakh
        self.russian = russian
    }
}

public struct WordItem: Codable, Identifiable, Equatable, Hashable {
    public let id: Int
    public let kazakh: String
    public let transliteration: String
    public let partOfSpeech: String
    public let meaning: String
    public let primaryExample: BilingualExample
    public let usageExplanation: String?
    public let additionalExamples: [BilingualExample]?
    
    // Backward compatibility accessors
    public var translation: String { meaning }
    public var phonetic: String? { transliteration }
    public var example: String { primaryExample.kazakh }
    public var details: String? { usageExplanation }
    
    enum CodingKeys: String, CodingKey {
        case id
        case kazakh
        case transliteration
        case phonetic
        case partOfSpeech
        case meaning
        case translation
        case primaryExample
        case example
        case usageExplanation
        case details
        case additionalExamples
    }
    
    public init(
        id: Int,
        kazakh: String,
        transliteration: String,
        partOfSpeech: String,
        meaning: String,
        primaryExample: BilingualExample,
        usageExplanation: String? = nil,
        additionalExamples: [BilingualExample]? = nil
    ) {
        self.id = id
        self.kazakh = kazakh
        self.transliteration = transliteration
        self.partOfSpeech = partOfSpeech
        self.meaning = meaning
        self.primaryExample = primaryExample
        self.usageExplanation = usageExplanation
        self.additionalExamples = additionalExamples
    }
    
    public init(
        id: Int,
        kazakh: String,
        partOfSpeech: String,
        translation: String,
        example: String,
        phonetic: String? = nil,
        details: String? = nil,
        additionalExamples: [String]? = nil,
        exampleTranslation: String = ""
    ) {
        self.id = id
        self.kazakh = kazakh
        self.transliteration = phonetic ?? ""
        self.partOfSpeech = partOfSpeech
        self.meaning = translation
        self.primaryExample = BilingualExample(kazakh: example, russian: exampleTranslation)
        self.usageExplanation = details
        self.additionalExamples = additionalExamples?.map { BilingualExample(kazakh: $0, russian: "") }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.kazakh = try container.decode(String.self, forKey: .kazakh)
        
        if let trans = try container.decodeIfPresent(String.self, forKey: .transliteration) {
            self.transliteration = trans
        } else if let phon = try container.decodeIfPresent(String.self, forKey: .phonetic) {
            self.transliteration = phon
        } else {
            self.transliteration = ""
        }
        
        self.partOfSpeech = try container.decode(String.self, forKey: .partOfSpeech)
        
        if let mean = try container.decodeIfPresent(String.self, forKey: .meaning) {
            self.meaning = mean
        } else if let trans = try container.decodeIfPresent(String.self, forKey: .translation) {
            self.meaning = trans
        } else {
            self.meaning = ""
        }
        
        if let primary = try container.decodeIfPresent(BilingualExample.self, forKey: .primaryExample) {
            self.primaryExample = primary
        } else if let primary = try container.decodeIfPresent(BilingualExample.self, forKey: .example) {
            self.primaryExample = primary
        } else if let exampleStr = try container.decodeIfPresent(String.self, forKey: .example) {
            self.primaryExample = BilingualExample(kazakh: exampleStr, russian: "")
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.primaryExample,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Missing primaryExample or example")
            )
        }
        
        self.usageExplanation = try container.decodeIfPresent(String.self, forKey: .usageExplanation)
            ?? container.decodeIfPresent(String.self, forKey: .details)
        
        if let bilingualAdd = try container.decodeIfPresent([BilingualExample].self, forKey: .additionalExamples) {
            self.additionalExamples = bilingualAdd
        } else if let stringAdd = try container.decodeIfPresent([String].self, forKey: .additionalExamples) {
            self.additionalExamples = stringAdd.map { BilingualExample(kazakh: $0, russian: "") }
        } else {
            self.additionalExamples = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(kazakh, forKey: .kazakh)
        try container.encode(transliteration, forKey: .transliteration)
        try container.encode(partOfSpeech, forKey: .partOfSpeech)
        try container.encode(meaning, forKey: .meaning)
        try container.encode(primaryExample, forKey: .primaryExample)
        try container.encodeIfPresent(usageExplanation, forKey: .usageExplanation)
        try container.encodeIfPresent(additionalExamples, forKey: .additionalExamples)
    }
}

public enum VocabularyValidationError: LocalizedError, Equatable {
    case emptyCollection
    case missingRequiredField(id: Int, field: String)
    case malformedBilingualExample(id: Int, context: String)
    case excessiveAdditionalExamples(id: Int, count: Int)
    case duplicateID(id: Int)
    case duplicateWord(kazakh: String)
    
    public var errorDescription: String? {
        switch self {
        case .emptyCollection:
            return "Коллекция слов пуста."
        case .missingRequiredField(let id, let field):
            return "Слово (ID: \(id)) не содержит обязательное поле '\(field)'."
        case .malformedBilingualExample(let id, let context):
            return "Слово (ID: \(id)) содержит некорректный двуязычный пример: \(context)."
        case .excessiveAdditionalExamples(let id, let count):
            return "Слово (ID: \(id)) содержит \(count) дополнительных примеров (разрешено не более 2)."
        case .duplicateID(let id):
            return "Обнаружен дубликат идентификатора: \(id)."
        case .duplicateWord(let kazakh):
            return "Обнаружен дубликат слова: '\(kazakh)'."
        }
    }
}

public struct VocabularyValidator {
    public static func validate(entry: WordItem) throws {
        let trimmedKazakh = entry.kazakh.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKazakh.isEmpty else {
            throw VocabularyValidationError.missingRequiredField(id: entry.id, field: "kazakh")
        }
        
        let trimmedTrans = entry.transliteration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTrans.isEmpty else {
            throw VocabularyValidationError.missingRequiredField(id: entry.id, field: "transliteration")
        }
        
        let trimmedPos = entry.partOfSpeech.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPos.isEmpty else {
            throw VocabularyValidationError.missingRequiredField(id: entry.id, field: "partOfSpeech")
        }
        
        let trimmedMeaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMeaning.isEmpty else {
            throw VocabularyValidationError.missingRequiredField(id: entry.id, field: "meaning")
        }
        
        let primaryKz = entry.primaryExample.kazakh.trimmingCharacters(in: .whitespacesAndNewlines)
        let primaryRu = entry.primaryExample.russian.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !primaryKz.isEmpty && !primaryRu.isEmpty else {
            throw VocabularyValidationError.malformedBilingualExample(
                id: entry.id,
                context: "Основной пример должен содержать казахский текст и русский перевод"
            )
        }
        
        if let additionals = entry.additionalExamples {
            guard additionals.count <= 2 else {
                throw VocabularyValidationError.excessiveAdditionalExamples(id: entry.id, count: additionals.count)
            }
            
            for (idx, ex) in additionals.enumerated() {
                let exKz = ex.kazakh.trimmingCharacters(in: .whitespacesAndNewlines)
                let exRu = ex.russian.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !exKz.isEmpty && !exRu.isEmpty else {
                    throw VocabularyValidationError.malformedBilingualExample(
                        id: entry.id,
                        context: "Дополнительный пример #\(idx + 1) должен содержать текст на казахском и перевод на русский"
                    )
                }
            }
        }
    }
    
    public static func validate(collection: [WordItem]) throws {
        guard !collection.isEmpty else {
            throw VocabularyValidationError.emptyCollection
        }
        
        var seenIDs = Set<Int>()
        var seenWords = Set<String>()
        for entry in collection {
            guard !seenIDs.contains(entry.id) else {
                throw VocabularyValidationError.duplicateID(id: entry.id)
            }
            seenIDs.insert(entry.id)
            
            let normalizedWord = entry.kazakh.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !seenWords.contains(normalizedWord) else {
                throw VocabularyValidationError.duplicateWord(kazakh: entry.kazakh)
            }
            seenWords.insert(normalizedWord)
            
            try validate(entry: entry)
        }
    }
}

public enum ContentLoadingError: LocalizedError, Equatable {
    case fileNotFound
    case dataCorrupted(String)
    case validationFailed(VocabularyValidationError)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Файл словаря не найден."
        case .dataCorrupted(let message):
            return "Не удалось прочитать данные словаря: \(message)"
        case .validationFailed(let error):
            return error.errorDescription ?? "Ошибка структуры словаря."
        }
    }
}

public struct VocabularyLoader {
    public static func loadFromBundle(
        bundle: Bundle = Bundle.main,
        resource: String = "words",
        extension ext: String = "json"
    ) -> Result<[WordItem], ContentLoadingError> {
        guard let url = bundle.url(forResource: resource, withExtension: ext) else {
            return .failure(.fileNotFound)
        }
        return load(from: url)
    }
    
    public static func load(from url: URL) -> Result<[WordItem], ContentLoadingError> {
        do {
            let data = try Data(contentsOf: url)
            return load(fromData: data)
        } catch {
            return .failure(.dataCorrupted(error.localizedDescription))
        }
    }
    
    public static func load(fromData data: Data) -> Result<[WordItem], ContentLoadingError> {
        let items: [WordItem]
        do {
            items = try JSONDecoder().decode([WordItem].self, from: data)
        } catch {
            return .failure(.dataCorrupted(error.localizedDescription))
        }
        
        do {
            try VocabularyValidator.validate(collection: items)
            return .success(items)
        } catch let valError as VocabularyValidationError {
            return .failure(.validationFailed(valError))
        } catch {
            return .failure(.validationFailed(.emptyCollection))
        }
    }
}

public func loadWords() -> [WordItem] {
    switch VocabularyLoader.loadFromBundle() {
    case .success(let items):
        return items
    case .failure:
        return []
    }
}
