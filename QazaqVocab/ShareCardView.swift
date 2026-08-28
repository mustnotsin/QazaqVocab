import SwiftUI

struct ShareCardView: View {
    let word: WordItem
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.08)
                .ignoresSafeArea()
            
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.white.opacity(0.04),
                    Color.clear
                ]),
                center: .center,
                startRadius: 40,
                endRadius: 400
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                    Text("DAILY QAZAQ VOCABULARY")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .tracking(2.0)
                }
                .foregroundStyle(Color.white.opacity(0.45))
                .padding(.top, 70)
                
                Spacer()
                
                VStack(spacing: 16) {
                    Text(word.kazakh.lowercased())
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 8) {
                        if let phonetic = word.phonetic {
                            Text("/\(phonetic)/")
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.55))
                            
                            Text("•")
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                        
                        Text(word.partOfSpeech.lowercased())
                            .font(.system(size: 16, weight: .medium))
                            .italic()
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    
                    Text(word.translation)
                        .font(.system(size: 22, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.top, 4)
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 48, height: 1)
                        .padding(.vertical, 14)
                    
                    Text("“\(word.example)”")
                        .font(.system(size: 17, weight: .regular, design: .serif))
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineSpacing(4)
                        .padding(.horizontal, 44)
                }
                
                Spacer()
                
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                            .frame(width: 26, height: 26)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                            )
                        
                        Text("Q")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text("QazaqVocab")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Learn Kazakh daily on iOS")
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .frame(width: 390, height: 693)
    }
}
