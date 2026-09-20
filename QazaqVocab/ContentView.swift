import SwiftUI
import UIKit
import WidgetKit

struct HapticManager {
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

struct ContentView: View {
    @State private var allWords: [WordItem] = loadWords()
    
    @AppStorage(ExperienceEngine.savedWordIDsKey, store: UserDefaults(suiteName: ExperienceEngine.appGroupID))
    private var savedWordIDsRaw: String = "[]"
    
    @AppStorage("seen_word_ids", store: UserDefaults(suiteName: ExperienceEngine.appGroupID))
    private var seenWordIDsRaw: String = "[]"
    
    private var savedWordIDs: Binding<Set<Int>> {
        Binding(
            get: { decodeIDSet(from: savedWordIDsRaw) },
            set: { savedWordIDsRaw = encodeIDSet($0) }
        )
    }
    
    private var seenWordIDs: Binding<Set<Int>> {
        Binding(
            get: { decodeIDSet(from: seenWordIDsRaw) },
            set: { seenWordIDsRaw = encodeIDSet($0) }
        )
    }
    
    var body: some View {
        TabView {
            HomeFeedView(
                allWords: allWords,
                savedWordIDs: savedWordIDs,
                seenWordIDs: seenWordIDs
            )
            .tabItem {
                Label("Words", systemImage: "text.book.closed")
            }
            
            SavedSectionView(
                words: allWords,
                savedWordIDs: savedWordIDs
            )
            .tabItem {
                Label("Saved", systemImage: "bookmark")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            ExperienceEngine.migrateLegacySavedSelectionsIfNeeded()
            WidgetCenter.shared.reloadTimelines(ofKind: "QazaqVocabWidget")
        }
    }
    
    private func decodeIDSet(from raw: String) -> Set<Int> {
        guard let data = raw.data(using: .utf8),
              let array = try? JSONDecoder().decode([Int].self, from: data) else {
            return []
        }
        return Set(array)
    }
    
    private func encodeIDSet(_ set: Set<Int>) -> String {
        guard let data = try? JSONEncoder().encode(Array(set)),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}

enum FeedItem: Identifiable, Equatable {
    case word(WordItem)
    case completion
    
    var id: String {
        switch self {
        case .word(let item):
            return "word_\(item.id)"
        case .completion:
            return "feed_completion"
        }
    }
    
    static func == (lhs: FeedItem, rhs: FeedItem) -> Bool {
        switch (lhs, rhs) {
        case (.word(let a), .word(let b)):
            return a.id == b.id
        case (.completion, .completion):
            return true
        default:
            return false
        }
    }
}

struct HomeFeedView: View {
    let allWords: [WordItem]
    @Binding var savedWordIDs: Set<Int>
    @Binding var seenWordIDs: Set<Int>
    
    @AppStorage(ExperienceEngine.isCollectionCompletedKey, store: UserDefaults(suiteName: ExperienceEngine.appGroupID))
    private var isCollectionCompleted: Bool = false
    
    @State private var feedItems: [FeedItem] = []
    @State private var selectedWordForDetails: WordItem?
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(feedItems) { feedItem in
                        switch feedItem {
                        case .word(let item):
                            VStack(spacing: 14) {
                                Spacer()
                                
                                Text(item.kazakh.lowercased())
                                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                
                                Text(item.partOfSpeech.lowercased())
                                    .font(.system(size: 16, weight: .medium))
                                    .italic()
                                    .foregroundStyle(Color.white.opacity(0.6))
                                
                                Text(item.translation)
                                    .font(.title3)
                                    .fontWeight(.regular)
                                    .foregroundStyle(Color.white.opacity(0.9))
                                    .padding(.top, 4)
                                
                                Text(item.example)
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(Color.white.opacity(0.75))
                                    .padding(.horizontal, 36)
                                    .padding(.top, 16)
                                
                                HStack(spacing: 24) {
                                    ActionPillButton(
                                        systemName: savedWordIDs.contains(item.id) ? "bookmark.fill" : "bookmark",
                                        iconColor: savedWordIDs.contains(item.id) ? Color(red: 0.95, green: 0.77, blue: 0.25) : .white.opacity(0.7),
                                        isActive: savedWordIDs.contains(item.id)
                                    ) {
                                        HapticManager.impact(style: .medium)
                                        toggleSaved(id: item.id)
                                    }
                                    
                                    ActionPillButton(
                                        systemName: "info.circle",
                                        iconColor: .white.opacity(0.85),
                                        isActive: false
                                    ) {
                                        HapticManager.impact(style: .light)
                                        selectedWordForDetails = item
                                    }
                                    
                                    ActionPillButton(
                                        systemName: "square.and.arrow.up",
                                        iconColor: .white.opacity(0.85),
                                        isActive: false
                                    ) {
                                        HapticManager.impact(style: .medium)
                                        SharePresenter.presentShareSheet(word: item)
                                    }
                                }
                                .padding(.top, 28)
                                
                                Spacer()
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .onAppear {
                                markAsSeen(id: item.id)
                            }
                            
                        case .completion:
                            CompletionCardView {
                                handleCollectionCompletion()
                            }
                            .frame(width: proxy.size.width, height: proxy.size.height)
                        }
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12).ignoresSafeArea())
            .sheet(item: $selectedWordForDetails) { word in
                WordDetailSheet(word: word, savedWordIDs: $savedWordIDs)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                prepareFeed()
            }
        }
    }
    
    private func prepareFeed() {
        guard feedItems.isEmpty else { return }
        guard !allWords.isEmpty else { return }
        
        let featured = ExperienceEngine.featuredEntry(from: allWords)
        if let featured = featured {
            ExperienceEngine.saveActiveWordID(featured.id)
        }
        
        let feedOrder = ExperienceEngine.getOrInitializeDiscoveryFeedOrder(from: allWords)
        let feedWords = ExperienceEngine.prepareDiscoveryFeed(
            from: allWords,
            featuredEntry: featured,
            feedOrder: feedOrder,
            seenIDs: seenWordIDs
        )
        
        feedItems = feedWords.map { .word($0) } + [.completion]
    }
    
    private func markAsSeen(id: Int) {
        if !seenWordIDs.contains(id) {
            seenWordIDs.insert(id)
        }
    }
    
    private func handleCollectionCompletion() {
        if !isCollectionCompleted {
            isCollectionCompleted = true
            ExperienceEngine.markCollectionCompleted()
            HapticManager.impact(style: .medium)
        }
    }
    
    private func toggleSaved(id: Int) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            if savedWordIDs.contains(id) {
                savedWordIDs.remove(id)
            } else {
                savedWordIDs.insert(id)
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "QazaqVocabWidget")
    }
}

struct CompletionCardView: View {
    let onAppearAction: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                Image(systemName: "sparkles")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(Color(red: 0.95, green: 0.77, blue: 0.25))
            }
            
            Text(ExperienceEngine.completionMessage)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(6)
                .padding(.horizontal, 32)
            
            Text("Все слова первой версии пройдены. Сохранённые слова остаются доступны, а виджеты продолжат показывать новые слова каждый день.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.white.opacity(0.6))
                .lineSpacing(4)
                .padding(.horizontal, 36)
                .padding(.top, 4)
            
            Spacer()
        }
        .padding()
        .onAppear {
            onAppearAction()
        }
    }
}

struct ActionPillButton: View {
    let systemName: String
    let iconColor: Color
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(red: 0.18, green: 0.18, blue: 0.18))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                    )
                
                Image(systemName: systemName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .scaleEffect(isActive ? 1.15 : 1.0)
            }
        }
        .buttonStyle(.plain)
    }
}

struct WordDetailSheet: View {
    let word: WordItem
    @Binding var savedWordIDs: Set<Int>
    
    private var isSaved: Bool {
        savedWordIDs.contains(word.id)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(word.kazakh.lowercased())
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        HStack(spacing: 8) {
                            if let phonetic = word.phonetic {
                                Text("/\(phonetic)/")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            
                            Text("•")
                                .foregroundStyle(.white.opacity(0.3))
                            
                            Text(word.partOfSpeech.lowercased())
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        
                        Text(word.translation)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.top, 4)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    if let details = word.details {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Usage & Nuance")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            Text(details)
                                .font(.body)
                                .foregroundStyle(.white.opacity(0.85))
                                .lineSpacing(4)
                        }
                    }
                    
                    if let examples = word.additionalExamples, !examples.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("More Examples")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .foregroundStyle(.white.opacity(0.5))
                            
                            ForEach(examples, id: \.self) { ex in
                                HStack(alignment: .top, spacing: 10) {
                                    Circle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    
                                    Text(ex)
                                        .font(.subheadline)
                                        .foregroundStyle(.white.opacity(0.8))
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(red: 0.12, green: 0.12, blue: 0.12).ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticManager.impact(style: .medium)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                            if isSaved {
                                savedWordIDs.remove(word.id)
                            } else {
                                savedWordIDs.insert(word.id)
                            }
                        }
                        WidgetCenter.shared.reloadTimelines(ofKind: "QazaqVocabWidget")
                    } label: {
                        Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isSaved ? Color(red: 0.95, green: 0.77, blue: 0.25) : .white.opacity(0.8))
                    }
                }
            }
        }
    }
}

struct SavedSectionView: View {
    let words: [WordItem]
    @Binding var savedWordIDs: Set<Int>
    @State private var selectedWordForDetails: WordItem?
    
    private var savedWords: [WordItem] {
        ExperienceEngine.filterSavedWords(from: words, savedIDs: savedWordIDs)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if savedWords.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No saved words yet")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.7))
                        Text("Tap the bookmark icon on any card or in word details to save words for later.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    List {
                        Section {
                            ForEach(savedWords) { word in
                                Button {
                                    selectedWordForDetails = word
                                } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(word.kazakh.lowercased())
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Spacer()
                                            Text(word.partOfSpeech.lowercased())
                                                .font(.caption)
                                                .italic()
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        Text(word.translation)
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .listRowBackground(Color(red: 0.16, green: 0.16, blue: 0.16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        HapticManager.impact(style: .medium)
                                        withAnimation {
                                            savedWordIDs.remove(word.id)
                                        }
                                        WidgetCenter.shared.reloadTimelines(ofKind: "QazaqVocabWidget")
                                    } label: {
                                        Label("Unsave", systemImage: "bookmark.slash")
                                    }
                                }
                            }
                        } header: {
                            Text("\(savedWords.count) \(savedWords.count == 1 ? "word" : "words")")
                                .font(.footnote)
                                .foregroundStyle(.white.opacity(0.4))
                                .textCase(.uppercase)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.10).ignoresSafeArea())
            .navigationTitle("Saved")
            .sheet(item: $selectedWordForDetails) { word in
                WordDetailSheet(word: word, savedWordIDs: $savedWordIDs)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

#Preview {
    ContentView()
}
