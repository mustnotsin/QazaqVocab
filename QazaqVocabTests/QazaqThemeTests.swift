import XCTest
import SwiftUI
@testable import QazaqVocab

final class QazaqThemeTests: XCTestCase {
    
    func testThemeColors_passWCAGAAContrastAtProductionSeam() {
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
        
        // Extract RGB components directly from production theme tokens
        let bg = QazaqTheme.Colors.rgba(of: QazaqTheme.Colors.background)
        let bgLum = luminance(r: bg.r, g: bg.g, b: bg.b)
        
        // textPrimary on background
        let primary = QazaqTheme.Colors.rgba(of: QazaqTheme.Colors.textPrimary)
        let primaryLum = luminance(r: primary.r, g: primary.g, b: primary.b)
        let primaryContrast = contrastRatio(l1: primaryLum, l2: bgLum)
        XCTAssertGreaterThan(
            primaryContrast,
            7.0,
            "textPrimary (\(primaryContrast):1) should pass WCAG AAA (7:1) contrast against dark background"
        )
        
        // textSecondary on background
        let secondary = QazaqTheme.Colors.rgba(of: QazaqTheme.Colors.textSecondary)
        let secondaryLum = luminance(r: secondary.r, g: secondary.g, b: secondary.b)
        let secondaryContrast = contrastRatio(l1: secondaryLum, l2: bgLum)
        XCTAssertGreaterThan(
            secondaryContrast,
            4.5,
            "textSecondary (\(secondaryContrast):1) should pass WCAG AA (4.5:1) contrast against dark background"
        )
        
        // steppeGold on background
        let gold = QazaqTheme.Colors.rgba(of: QazaqTheme.Colors.steppeGold)
        let goldLum = luminance(r: gold.r, g: gold.g, b: gold.b)
        let goldContrast = contrastRatio(l1: goldLum, l2: bgLum)
        XCTAssertGreaterThan(
            goldContrast,
            4.5,
            "steppeGold (\(goldContrast):1) should pass WCAG AA (4.5:1) contrast against dark background"
        )
    }
}
