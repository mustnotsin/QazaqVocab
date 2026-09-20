import SwiftUI

/// Branded 9:16 bilingual visual share card for a vocabulary entry.
/// Designed specifically for sharing outside the app without public marketing or store links.
public struct ShareCardView: View {
    public let word: WordItem
    
    // Canonical 9:16 dimensions (390 x 693.33)
    public static let cardWidth: CGFloat = 390
    public static let cardHeight: CGFloat = 390 * 16 / 9
    
    public init(word: WordItem) {
        self.word = word
    }
    
    public var body: some View {
        ZStack {
            // Background: Minimal dark steppe obsidian
            QazaqTheme.Colors.background
                .ignoresSafeArea()
            
            // Subtle warm ambient radial gradient
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.04),
                    QazaqTheme.Colors.steppeGold.opacity(0.02),
                    Color.clear
                ]),
                center: .center,
                startRadius: 40,
                endRadius: 380
            )
            .ignoresSafeArea()
            
            // Subtle outer hairline frame with corner ornament accents
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
                .padding(16)
            
            VStack(spacing: 0) {
                // Top Header: Restrained Kazakh ornament header
                HStack(spacing: 8) {
                    KazakhOrnamentShape()
                        .stroke(QazaqTheme.Colors.steppeGold, lineWidth: 1.2)
                        .frame(width: 14, height: 11)
                    
                    Text("ҚАЗАҚ ТІЛІ")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(2.5)
                        .foregroundStyle(Color.white.opacity(0.45))
                    
                    KazakhOrnamentShape()
                        .stroke(QazaqTheme.Colors.steppeGold, lineWidth: 1.2)
                        .frame(width: 14, height: 11)
                        .scaleEffect(x: -1, y: 1)
                }
                .padding(.top, 48)
                
                Spacer(minLength: 16)
                
                // Main Content Block
                VStack(spacing: 14) {
                    // Kazakh Word
                    Text(word.kazakh.lowercased())
                        .font(.system(size: 46, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.65)
                        .padding(.horizontal, 28)
                    
                    // Latin Pronunciation & Part of Speech
                    HStack(spacing: 8) {
                        if !word.transliteration.isEmpty {
                            Text("/\(word.transliteration)/")
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundStyle(QazaqTheme.Colors.steppeGold)
                            
                            Text("•")
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        
                        Text(word.partOfSpeech.lowercased())
                            .font(.system(size: 15, weight: .regular))
                            .italic()
                            .foregroundStyle(Color.white.opacity(0.65))
                    }
                    .padding(.top, 2)
                    
                    // Russian Meaning
                    Text(word.meaning)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.8)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)
                    
                    // Restrained Ornament Divider
                    KazakhOrnamentDivider(width: 90, accentColor: QazaqTheme.Colors.steppeGold)
                        .padding(.vertical, 14)
                    
                    // Primary Kazakh Example & Russian Translation
                    VStack(spacing: 8) {
                        Text("«\(word.primaryExample.kazakh)»")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.white.opacity(0.88))
                            .lineSpacing(4)
                            .lineLimit(4)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 32)
                        
                        if !word.primaryExample.russian.isEmpty {
                            Text(word.primaryExample.russian)
                                .font(.system(size: 14, weight: .regular))
                                .italic()
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.white.opacity(0.60))
                                .lineSpacing(3)
                                .lineLimit(4)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, 36)
                        }
                    }
                }
                
                Spacer(minLength: 16)
                
                // Bottom: Subtle QazaqVocab branding (No public URLs, no App Store links)
                HStack(spacing: 8) {
                    QazaqLogoMark(size: 24, accentColor: QazaqTheme.Colors.steppeGold)
                    
                    Text("QazaqVocab")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.white.opacity(0.80))
                        .tracking(0.5)
                }
                .padding(.bottom, 48)
            }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Карточка слова \(word.kazakh). Произношение: \(word.transliteration). Перевод: \(word.meaning). Пример: \(word.primaryExample.kazakh) — \(word.primaryExample.russian)")
    }
}
