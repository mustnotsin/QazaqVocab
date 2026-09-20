import SwiftUI
import UIKit

/// Central design system tokens and visual identity elements for QazaqVocab.
/// Implements a minimal dark aesthetic with authentic, restrained Kazakh visual cues (Steppe Gold and subtle ornaments).
enum QazaqTheme {
    enum Colors {
        /// Deep charcoal-black background for dark-only presentation.
        static let background = Color(red: 0.07, green: 0.07, blue: 0.08)
        
        /// Elevated card surface.
        static let cardSurface = Color(red: 0.12, green: 0.12, blue: 0.13)
        
        /// Button or pill background.
        static let pillSurface = Color(red: 0.17, green: 0.17, blue: 0.18)
        
        /// Subtle 1px card border.
        static let cardBorder = Color.white.opacity(0.09)
        
        /// Kazakh Steppe Gold: warm noble gold accent derived from traditional Kazakh metalwork.
        static let steppeGold = Color(red: 0.90, green: 0.71, blue: 0.26)
        
        /// Soft muted gold for secondary accents.
        static let steppeGoldMuted = Color(red: 0.90, green: 0.71, blue: 0.26).opacity(0.3)
        
        /// High-contrast primary text (contrast > 14:1 on background).
        static let textPrimary = Color(red: 0.98, green: 0.98, blue: 0.98)
        
        /// Secondary readable text (contrast > 6:1 on background).
        static let textSecondary = Color(red: 0.68, green: 0.70, blue: 0.75)
        
        /// Tertiary labels and captions (contrast > 4.5:1 on background).
        static let textTertiary = Color(red: 0.52, green: 0.54, blue: 0.58)
        
        /// Extracts standard sRGB components for color-contrast inspection at the production seam.
        static func rgba(of color: Color) -> (r: Double, g: Double, b: Double, a: Double) {
            let uiColor = UIColor(color)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var a: CGFloat = 0
            uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
            return (Double(r), Double(g), Double(b), Double(a))
        }
    }
}

/// Symmetrical Kazakh ram-horn ornament shape (Қошқар мүйіз / Қосмүйіз).
struct KazakhOrnamentShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let midX = rect.midX
        let bottomY = rect.minY + h * 0.95
        
        // Single horn builder mirrored across midX
        func addHorn(direction: CGFloat) {
            path.move(to: CGPoint(x: midX, y: bottomY))
            path.addCurve(
                to: CGPoint(x: midX + direction * w * 0.38, y: rect.minY + h * 0.25),
                control1: CGPoint(x: midX + direction * w * 0.15, y: rect.minY + h * 0.75),
                control2: CGPoint(x: midX + direction * w * 0.45, y: rect.minY + h * 0.45)
            )
            path.addCurve(
                to: CGPoint(x: midX + direction * w * 0.22, y: rect.minY + h * 0.35),
                control1: CGPoint(x: midX + direction * w * 0.32, y: rect.minY + h * 0.10),
                control2: CGPoint(x: midX + direction * w * 0.18, y: rect.minY + h * 0.20)
            )
            path.addCurve(
                to: CGPoint(x: midX + direction * w * 0.28, y: rect.minY + h * 0.42),
                control1: CGPoint(x: midX + direction * w * 0.24, y: rect.minY + h * 0.40),
                control2: CGPoint(x: midX + direction * w * 0.27, y: rect.minY + h * 0.42)
            )
        }
        
        // Left horn (-1) and Right horn (+1)
        addHorn(direction: -1)
        addHorn(direction: 1)
        
        return path
    }
}

/// Brand logo mark combining the minimal Q and Kazakh ornament in a stylized emblem.
struct QazaqLogoMark: View {
    let size: CGFloat
    var accentColor: Color = QazaqTheme.Colors.steppeGold
    
    init(size: CGFloat = 32, accentColor: Color = QazaqTheme.Colors.steppeGold) {
        self.size = size
        self.accentColor = accentColor
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24)
                .fill(Color(red: 0.15, green: 0.15, blue: 0.16))
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
            
            // Stylized Q letter with Kazakh ornament
            ZStack {
                // Bowl of the Q
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.white, accentColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.5, size * 0.10)
                    )
                    .frame(width: size * 0.54, height: size * 0.54)
                    .offset(x: -size * 0.04, y: -size * 0.04)
                
                // Tail curving into Kazakh ram-horn flourish
                Path { path in
                    let startX = size * 0.52
                    let startY = size * 0.52
                    path.move(to: CGPoint(x: startX, y: startY))
                    path.addCurve(
                        to: CGPoint(x: size * 0.80, y: size * 0.78),
                        control1: CGPoint(x: size * 0.62, y: size * 0.60),
                        control2: CGPoint(x: size * 0.74, y: size * 0.70)
                    )
                    path.addCurve(
                        to: CGPoint(x: size * 0.70, y: size * 0.85),
                        control1: CGPoint(x: size * 0.84, y: size * 0.84),
                        control2: CGPoint(x: size * 0.78, y: size * 0.88)
                    )
                }
                .stroke(
                    accentColor,
                    style: StrokeStyle(lineWidth: max(1.5, size * 0.09), lineCap: .round)
                )
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Логотип QazaqVocab")
    }
}

/// Restrained ornamental divider with subtle center motif.
struct KazakhOrnamentDivider: View {
    var width: CGFloat = 80
    var accentColor: Color = QazaqTheme.Colors.steppeGold
    
    init(width: CGFloat = 80, accentColor: Color = QazaqTheme.Colors.steppeGold) {
        self.width = width
        self.accentColor = accentColor
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.02), accentColor.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
            
            // Center miniature ornament
            KazakhOrnamentShape()
                .stroke(accentColor, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                .frame(width: 18, height: 14)
            
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accentColor.opacity(0.5), Color.white.opacity(0.02)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 1)
        }
        .frame(width: width)
        .accessibilityHidden(true)
    }
}
