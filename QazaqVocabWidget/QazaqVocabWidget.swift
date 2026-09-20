import WidgetKit
import SwiftUI

struct WordEntry: TimelineEntry {
    let date: Date
    let word: WordItem
}

struct Provider: TimelineProvider {
    private let words: [WordItem] = loadWords()
    
    private var fallbackWord: WordItem {
        ExperienceEngine.fallbackEntry
    }

    func placeholder(in context: Context) -> WordEntry {
        WordEntry(date: Date(), word: fallbackWord)
    }

    func getSnapshot(in context: Context, completion: @escaping (WordEntry) -> ()) {
        let entryWord = ExperienceEngine.featuredEntryOrDefault(from: words)
        let entry = WordEntry(date: Date(), word: entryWord)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let timelineData = ExperienceEngine.widgetTimelineEntries(from: words)
        let todayEntry = WordEntry(date: timelineData.current.date, word: timelineData.current.word)
        let tomorrowEntry = WordEntry(date: timelineData.next.date, word: timelineData.next.word)
        let timeline = Timeline(entries: [todayEntry, tomorrowEntry], policy: .after(timelineData.nextMidnight))
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
                Text("\(entry.word.kazakh.lowercased()) • \(entry.word.meaning)")
            default:
                SmallWidgetView(word: entry.word)
            }
        }
        .widgetURL(ExperienceEngine.featuredWordURL)
        .containerBackground(for: .widget) {
            Color(red: 0.12, green: 0.12, blue: 0.12)
        }
    }
}

struct SmallWidgetView: View {
    let word: WordItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ГЛАВНОЕ СЛОВО")
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
            
            Text(word.meaning)
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
                Text("ГЛАВНОЕ СЛОВО")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.45))
                
                Spacer()
                
                Text(word.kazakh.lowercased())
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                HStack(spacing: 6) {
                    if !word.transliteration.isEmpty {
                        Text("/\(word.transliteration)/")
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
                
                Text(word.meaning)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .lineLimit(2)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Divider()
                .background(Color.white.opacity(0.15))
            
            VStack(alignment: .leading, spacing: 6) {
                Text("ПРИМЕР")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Color.white.opacity(0.45))
                
                Spacer()
                
                Text(word.primaryExample.kazakh)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineSpacing(2)
                    .lineLimit(3)
                
                if !word.primaryExample.russian.isEmpty {
                    Text(word.primaryExample.russian)
                        .font(.system(size: 11, weight: .regular))
                        .italic()
                        .foregroundStyle(Color.white.opacity(0.55))
                        .lineLimit(2)
                }
                
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
            Text(word.meaning)
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
        .configurationDisplayName("Главное слово дня")
        .description("Открывайте главное казахское слово каждый день прямо на экране «Домой» и экране блокировки.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}
