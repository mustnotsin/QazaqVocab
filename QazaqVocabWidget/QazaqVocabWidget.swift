import WidgetKit
import SwiftUI

struct WordEntry: TimelineEntry {
    let date: Date
    let word: WordItem
}

struct Provider: TimelineProvider {
    private let words: [WordItem] = loadWords()
    
    private var fallbackWord: WordItem {
        words.first ?? WordItem(
            id: 1,
            kazakh: "нан",
            transliteration: "nan",
            partOfSpeech: "существительное",
            meaning: "Хлеб",
            primaryExample: BilingualExample(
                kazakh: "Дүкеннен жаңа піскен нан сатып алдық.",
                russian: "Мы купили в магазине свежий хлеб."
            ),
            usageExplanation: "Базовый продукт питания и символ достатка. В казахской традиции к хлебу относятся с особым почтением: его не бросают и не кладут вверх дном.",
            additionalExamples: nil
        )
    }

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), word: fallbackWord)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> ()) {
        let entryWord = ExperienceEngine.featuredEntry(from: words) ?? fallbackWord
        let entry = WordEntry(date: Date(), word: entryWord)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        let calendar = Calendar.current
        
        let todayWord = ExperienceEngine.featuredEntry(from: words, for: currentDate, in: calendar) ?? fallbackWord
        let todayEntry = WordEntry(date: currentDate, word: todayWord)
        
        let nextMidnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate)
        let tomorrowWord = ExperienceEngine.featuredEntry(from: words, for: nextMidnight, in: calendar) ?? fallbackWord
        let tomorrowEntry = WordEntry(date: nextMidnight, word: tomorrowWord)
        
        let timeline = Timeline(entries: [todayEntry, tomorrowEntry], policy: .after(nextMidnight))
        completion(timeline)
    }
}

struct QazaqVocabWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(word: entry.word)
            case .systemMedium:
                MediumWidgetView(word: entry.word)
            case .accessoryRectangular:
                AccessoryRectangularView(word: entry.word)
            case .accessoryInline:
                Text("\(entry.word.kazakh.lowercased()) • \(entry.word.translation)")
            default:
                SmallWidgetView(word: entry.word)
            }
        }
        .containerBackground(for: .widget) {
            Color(red: 0.12, green: 0.12, blue: 0.12)
        }
    }
}

struct SmallWidgetView: View {
    let word: WordItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("WORD OF THE DAY")
                .font(.system(size: 9, weight: .bold))
                .tracking(1)
                .foregroundStyle(Color.white.opacity(0.45))
            
            Spacer()
            
            Text(word.kazakh.lowercased())
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(word.partOfSpeech.lowercased())
                .font(.system(size: 11, weight: .medium))
                .italic()
                .foregroundStyle(Color.white.opacity(0.6))
            
            Text(word.translation)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.85))
                .lineLimit(2)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MediumWidgetView: View {
    let word: WordItem
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("WORD OF THE DAY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.45))
                
                Spacer()
                
                Text(word.kazakh.lowercased())
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                HStack(spacing: 6) {
                    if let phonetic = word.phonetic {
                        Text("/\(phonetic)/")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    Text("•")
                        .foregroundStyle(Color.white.opacity(0.3))
                    Text(word.partOfSpeech.lowercased())
                        .font(.system(size: 12))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                
                Text(word.translation)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("EXAMPLE")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.45))
                
                Spacer()
                
                Text(word.example)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .lineSpacing(2)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct AccessoryRectangularView: View {
    let word: WordItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(word.kazakh.lowercased())
                .font(.headline)
                .widgetAccentable()
            Text(word.translation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

@main
struct QazaqVocabWidget: Widget {
    let kind: String = "QazaqVocabWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            QazaqVocabWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Daily Kazakh Word")
        .description("Learn a curated Kazakh word every day right from your home and lock screen.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
