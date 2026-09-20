import XCTest
import SwiftUI
@testable import QazaqVocab

@MainActor
final class ShareCardTests: XCTestCase {
    
    private func makeSampleWord(
        id: Int = 101,
        kazakh: String = "парасат",
        transliteration: String = "parasat",
        partOfSpeech: String = "зат есім",
        meaning: String = "мудрость, рассудительность, здравый смысл",
        exampleKazakh: String = "Адамның басты байлығы — парасат пен білім.",
        exampleRussian: String = "Главное богатство человека — мудрость и знания."
    ) -> WordItem {
        WordItem(
            id: id,
            kazakh: kazakh,
            transliteration: transliteration,
            partOfSpeech: partOfSpeech,
            meaning: meaning,
            primaryExample: BilingualExample(kazakh: exampleKazakh, russian: exampleRussian)
        )
    }
    
    func testShareCard_rendersImageSuccessfully() {
        let word = makeSampleWord()
        let image = ShareImageGenerator.renderCard(for: word)
        
        XCTAssertNotNil(image, "Share card should render to a valid UIImage")
        guard let img = image else { return }
        XCTAssertGreaterThan(img.size.width, 0)
        XCTAssertGreaterThan(img.size.height, 0)
    }
    
    func testShareCard_hasExact9to16AspectRatio() {
        let word = makeSampleWord()
        guard let image = ShareImageGenerator.renderCard(for: word) else {
            XCTFail("Failed to render card")
            return
        }
        
        let ratio = image.size.width / image.size.height
        let expectedRatio: CGFloat = 9.0 / 16.0
        
        XCTAssertEqual(
            ratio,
            expectedRatio,
            accuracy: 0.01,
            "Card should match 9:16 aspect ratio (ratio: \(ratio), expected: \(expectedRatio))"
        )
    }
    
    func testShareCard_handlesLongestVocabularyEntriesWithoutFailure() {
        let longWord = makeSampleWord(
            id: 999,
            kazakh: "жауапкершілік",
            transliteration: "jawapkerşilik",
            partOfSpeech: "зат есім",
            meaning: "Замечать / обращать внимание / быть осторожным и бдительным во всех жизненных ситуациях",
            exampleKazakh: "Жақсы дос қуанышта да, қиындықта да қасыңнан табылады, ешқашан жалғыз қалдырмайды.",
            exampleRussian: "Гражданин, обладающий чувством чести и долга, всегда ставит интересы своей страны выше личных амбиций."
        )
        
        let image = ShareImageGenerator.renderCard(for: longWord)
        XCTAssertNotNil(image, "Share card should render without failure even with extra-long Kazakh and Russian text")
        
        if let img = image {
            let ratio = img.size.width / img.size.height
            XCTAssertEqual(ratio, 9.0 / 16.0, accuracy: 0.01)
        }
    }
    
    func testShareCard_rendersAllCuratedWordsSuccessfully() {
        let loadResult = VocabularyLoader.loadFromBundle()
        switch loadResult {
        case .success(let words):
            XCTAssertEqual(words.count, 30, "Expected 30 bundled TestFlight words")
            for word in words {
                let image = ShareImageGenerator.renderCard(for: word)
                XCTAssertNotNil(image, "Failed to render share card for word: \(word.kazakh) (id: \(word.id))")
            }
        case .failure(let error):
            XCTFail("Failed to load bundled vocabulary: \(error)")
        }
    }
    
    func testShareCard_metadataContainsNoPublicUrlsOrStoreLinks() {
        let word = makeSampleWord()
        guard let image = ShareImageGenerator.renderCard(for: word) else {
            XCTFail("Failed to render card")
            return
        }
        
        let itemSource = ShareCardActivityItemSource(image: image, title: "QazaqVocab: \(word.kazakh.capitalized)")
        let activityVC = UIActivityViewController(activityItems: [itemSource], applicationActivities: nil)
        
        let metadata = itemSource.activityViewControllerLinkMetadata(activityVC)
        XCTAssertNotNil(metadata)
        XCTAssertNil(metadata?.originalURL, "Private TestFlight share card must not contain a public URL")
        XCTAssertNil(metadata?.url, "Private TestFlight share card must not contain an app store link")
        XCTAssertTrue(metadata?.title?.contains("QazaqVocab") == true)
    }
    
    func testThemeColors_passWCAGAAContrast() {
        // WCAG relative luminance formula
        func luminance(r: Double, g: Double, b: Double) -> Double {
            func channel(_ c: Double) -> Double {
                return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
        }
        
        func contrastRatio(l1: Double, l2: Double) -> Double {
            let lighter = max(l1, l2)
            let darker = min(l1, l2)
            return (lighter + 0.05) / (darker + 0.05)
        }
        
        let bgLum = luminance(r: 0.07, g: 0.07, b: 0.08)
        
        // textPrimary: rgb(0.98, 0.98, 0.98)
        let primaryLum = luminance(r: 0.98, g: 0.98, b: 0.98)
        let primaryContrast = contrastRatio(l1: primaryLum, l2: bgLum)
        XCTAssertGreaterThan(primaryContrast, 7.0, "textPrimary should pass WCAG AAA (7:1) contrast against dark background")
        
        // textSecondary: rgb(0.68, 0.70, 0.75)
        let secondaryLum = luminance(r: 0.68, g: 0.70, b: 0.75)
        let secondaryContrast = contrastRatio(l1: secondaryLum, l2: bgLum)
        XCTAssertGreaterThan(secondaryContrast, 4.5, "textSecondary should pass WCAG AA (4.5:1) contrast against dark background")
        
        // steppeGold: rgb(0.90, 0.71, 0.26)
        let goldLum = luminance(r: 0.90, g: 0.71, b: 0.26)
        let goldContrast = contrastRatio(l1: goldLum, l2: bgLum)
        XCTAssertGreaterThan(goldContrast, 4.5, "steppeGold should pass WCAG AA (4.5:1) contrast against dark background")
    }
}
