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
    @State private var allWords: [WordItem] = []
    @State private var loadingError: ContentLoadingError? = nil
    
    @AppStorage(ExperienceEngine.savedWordIDsKey, store: UserDefaults(suiteName: ExperienceEngine.appGroupID))
    private var savedWordIDsRaw: String = "[]"
    
    @AppStorage("seen_word_ids", store: UserDefaults(suiteName: ExperienceEngine.appGroupID))
    private var seenWordIDsRaw: String = "[]"
    
    @AppStorage(ExperienceEngine.hasCompletedFirstTimeSetupKey, store: UserDefaults(suiteName: ExperienceEngine.appGroupID))
    private var hasCompletedFirstTimeSetup: Bool = false
    
    @ObservedObject private var navigationState = AppNavigationState.shared
    
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
        Group {
            if let error = loadingError {
                ContentErrorView(error: error) {
                    reloadContent()
                }
            } else if !hasCompletedFirstTimeSetup {
                FirstTimeSetupView {
                    withAnimation(.easeInOut) {
                        hasCompletedFirstTimeSetup = true
                    }
                }
            } else {
                TabView(selection: $navigationState.selectedTab) {
                    HomeFeedView(
                        allWords: allWords,
                        savedWordIDs: savedWordIDs,
                        seenWordIDs: seenWordIDs
                    )
                    .tabItem {
                        Label("Слова", systemImage: "character.bubble")
                    }
                    .tag(AppTab.words)
                    
                    SavedSectionView(
                        words: allWords,
                        savedWordIDs: savedWordIDs
                    )
                    .tabItem {
                        Label("Сохранённое", systemImage: "bookmark")
                    }
                    .tag(AppTab.saved)
                }
                .tint(QazaqTheme.Colors.steppeGold)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            reloadContent()
            ExperienceEngine.migrateLegacySavedSelectionsIfNeeded()
            WidgetCenter.shared.reloadTimelines(ofKind: "QazaqVocabWidget")
        }
    }
    
    private func reloadContent() {
        switch VocabularyLoader.loadFromBundle() {
        case .success(let words):
            self.allWords = words
            self.loadingError = nil
        case .failure(let error):
            self.allWords = []
            self.loadingError = error
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

struct ContentErrorView: View {
    let error: ContentLoadingError
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(QazaqTheme.Colors.pillSurface)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(QazaqTheme.Colors.steppeGold)
            }
            .accessibilityHidden(true)
            
            Text("Не удалось загрузить слова")
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 32)
            
            Text(error.localizedDescription)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(QazaqTheme.Colors.textSecondary)
                .lineSpacing(4)
                .padding(.horizontal, 36)
            
            Button {
                HapticManager.impact(style: .medium)
                onRetry()
            } label: {
                Text("Повторить попытку")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(QazaqTheme.Colors.pillSurface)
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                            )
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Повторить попытку загрузки слов")
            .padding(.top, 12)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(QazaqTheme.Colors.background.ignoresSafeArea())
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
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(feedItems) { feedItem in
                            Group {
                                switch feedItem {
                                case .word(let item):
                                    VStack(spacing: 12) {
                                        Spacer()
                                        
                                        // Kazakh Word
                                        Text(item.kazakh.lowercased())
                                            .font(.system(size: 46, weight: .bold, design: .rounded))
                                            .foregroundStyle(QazaqTheme.Colors.textPrimary)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                            .minimumScaleFactor(0.7)
                                            .padding(.horizontal, 28)
                                        
                                        // Part of speech
                                        Text(item.partOfSpeech.lowercased())
                                            .font(.system(size: 16, weight: .medium))
                                            .italic()
                                            .foregroundStyle(QazaqTheme.Colors.textSecondary)
                                        
                                        // Russian Meaning
                                        Text(item.meaning)
                                            .font(.title3)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Color.white.opacity(0.92))
                                            .multilineTextAlignment(.center)
                                            .lineLimit(3)
                                            .minimumScaleFactor(0.8)
                                            .padding(.horizontal, 32)
                                            .padding(.top, 4)
                                        
                                        // Restrained Kazakh ornament divider
                                        KazakhOrnamentDivider(width: 72, accentColor: QazaqTheme.Colors.steppeGold)
                                            .padding(.vertical, 10)
                                        
                                        // Primary Example & Translation
                                        VStack(spacing: 6) {
                                            Text("«\(item.primaryExample.kazakh)»")
                                                .font(.body)
                                                .fontWeight(.medium)
                                                .multilineTextAlignment(.center)
                                                .foregroundStyle(Color.white.opacity(0.88))
                                                .lineSpacing(3)
                                                .lineLimit(4)
                                                .minimumScaleFactor(0.8)
                                            
                                            if !item.primaryExample.russian.isEmpty {
                                                Text(item.primaryExample.russian)
                                                    .font(.subheadline)
                                                    .italic()
                                                    .multilineTextAlignment(.center)
                                                    .foregroundStyle(QazaqTheme.Colors.textSecondary)
                                                    .lineSpacing(2)
                                                    .lineLimit(4)
                                                    .minimumScaleFactor(0.8)
                                            }
                                        }
                                        .padding(.horizontal, 36)
                                        .padding(.top, 4)
                                        
                                        // Action Pill Buttons
                                        HStack(spacing: 22) {
                                            ActionPillButton(
                                                systemName: savedWordIDs.contains(item.id) ? "bookmark.fill" : "bookmark",
                                                iconColor: savedWordIDs.contains(item.id) ? QazaqTheme.Colors.steppeGold : .white.opacity(0.75),
                                                accessibilityLabel: savedWordIDs.contains(item.id)
                                                    ? "Удалить слово «\(item.kazakh)» из сохранённых"
                                                    : "Сохранить слово «\(item.kazakh)»",
                                                isActive: savedWordIDs.contains(item.id)
                                            ) {
                                                HapticManager.impact(style: .medium)
                                                toggleSaved(id: item.id)
                                            }
                                            
                                            ActionPillButton(
                                                systemName: "info.circle",
                                                iconColor: .white.opacity(0.85),
                                                accessibilityLabel: "Подробнее о слове «\(item.kazakh)»",
                                                isActive: false
                                            ) {
                                                HapticManager.impact(style: .light)
                                                selectedWordForDetails = item
                                            }
                                            
                                            ActionPillButton(
                                                systemName: "square.and.arrow.up",
                                                iconColor: .white.opacity(0.85),
                                                accessibilityLabel: "Поделиться карточкой слова «\(item.kazakh)»",
                                                isActive: false
                                            ) {
                                                HapticManager.impact(style: .medium)
                                                SharePresenter.presentShareSheet(word: item)
                                            }
                                        }
                                        .padding(.top, 24)
                                        
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
                            .id(feedItem.id)
                        }
                    }
                }
                .scrollTargetBehavior(.paging)
                .background(QazaqTheme.Colors.background.ignoresSafeArea())
                .onReceive(AppNavigationState.shared.$scrollToFeaturedTrigger) { _ in
                    if let firstID = feedItems.first?.id {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollProxy.scrollTo(firstID, anchor: .top)
                        }
                    }
                }
            }
            .sheet(item: $selectedWordForDetails) { word in
                WordDetailSheet(word: word, savedWordIDs: $savedWordIDs)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onReceive(AppNavigationState.shared.$dismissDetailsTrigger) { _ in
                selectedWordForDetails = nil
            }
            .onAppear {
                prepareFeed()
            }
            .onChange(of: allWords) { _, _ in
                prepareFeed(force: true)
            }
        }
    }
    
    private func prepareFeed(force: Bool = false) {
        if !force && !feedItems.isEmpty { return }
        guard !allWords.isEmpty else {
            feedItems = []
            return
        }
        
        let featured = ExperienceEngine.featuredEntryOrDefault(from: allWords)
        ExperienceEngine.saveActiveWordID(featured.id)
        
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
            DailyReminderManager.shared.cancelReminders()
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
                    .fill(QazaqTheme.Colors.pillSurface)
                    .frame(width: 84, height: 84)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                
                QazaqLogoMark(size: 46, accentColor: QazaqTheme.Colors.steppeGold)
            }
            .accessibilityHidden(true)
            
            Text(ExperienceEngine.completionMessage)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.95))
                .lineSpacing(6)
                .padding(.horizontal, 32)
            
            Text("Все слова первой версии пройдены. Сохранённые слова остаются доступны, а виджеты продолжат показывать новые слова каждый день.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(QazaqTheme.Colors.textSecondary)
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
    let accessibilityLabel: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(QazaqTheme.Colors.pillSurface)
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
        .accessibilityLabel(accessibilityLabel)
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
                            .foregroundStyle(QazaqTheme.Colors.textPrimary)
                        
                        HStack(spacing: 8) {
                            if !word.transliteration.isEmpty {
                                Text("/\(word.transliteration)/")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(QazaqTheme.Colors.steppeGold)
                            }
                            
                            Text("•")
                                .foregroundStyle(Color.white.opacity(0.3))
                            
                            Text(word.partOfSpeech.lowercased())
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(QazaqTheme.Colors.textSecondary)
                        }
                        
                        Text(word.meaning)
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundStyle(.white.opacity(0.92))
                            .padding(.top, 4)
                    }
                    
                    Divider()
                        .background(Color.white.opacity(0.1))
                    
                    if let explanation = word.usageExplanation, !explanation.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Особенности употребления")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .foregroundStyle(QazaqTheme.Colors.textTertiary)
                            
                            Text(explanation)
                                .font(.body)
                                .foregroundStyle(Color.white.opacity(0.85))
                                .lineSpacing(4)
                        }
                    }
                    
                    if let examples = word.additionalExamples, !examples.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Дополнительные примеры")
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .foregroundStyle(QazaqTheme.Colors.textTertiary)
                            
                            ForEach(examples.indices, id: \.self) { idx in
                                let ex = examples[idx]
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(QazaqTheme.Colors.steppeGold)
                                        .frame(width: 5, height: 5)
                                        .padding(.top, 7)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(ex.kazakh)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.white.opacity(0.88))
                                        
                                        if !ex.russian.isEmpty {
                                            Text(ex.russian)
                                                .font(.caption)
                                                .foregroundStyle(QazaqTheme.Colors.textSecondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(QazaqTheme.Colors.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        HapticManager.impact(style: .medium)
                        SharePresenter.presentShareSheet(word: word)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .accessibilityLabel("Поделиться карточкой слова «\(word.kazakh)»")
                }
                
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
                            .foregroundStyle(isSaved ? QazaqTheme.Colors.steppeGold : .white.opacity(0.8))
                    }
                    .accessibilityLabel(isSaved ? "Удалить слово «\(word.kazakh)» из сохранённых" : "Сохранить слово «\(word.kazakh)»")
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
    
    private func formatWordCount(_ count: Int) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 {
            return "\(count) слово"
        } else if (2...4).contains(mod10) && !(12...14).contains(mod100) {
            return "\(count) слова"
        } else {
            return "\(count) слов"
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if savedWords.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 48))
                            .foregroundStyle(QazaqTheme.Colors.textTertiary)
                        Text("Нет сохранённых слов")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.8))
                        Text("Нажмите на значок закладки на карточке слова или в подробностях, чтобы сохранить его.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(QazaqTheme.Colors.textSecondary)
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
                                                .foregroundStyle(QazaqTheme.Colors.textPrimary)
                                            Spacer()
                                            Text(word.partOfSpeech.lowercased())
                                                .font(.caption)
                                                .italic()
                                                .foregroundStyle(QazaqTheme.Colors.textSecondary)
                                        }
                                        Text(word.meaning)
                                            .font(.subheadline)
                                            .foregroundStyle(Color.white.opacity(0.85))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityLabel("Слово \(word.kazakh), \(word.partOfSpeech), перевод: \(word.meaning)")
                                .accessibilityHint("Дважды коснитесь, чтобы открыть подробности")
                                .listRowBackground(QazaqTheme.Colors.cardSurface)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        HapticManager.impact(style: .medium)
                                        _ = withAnimation {
                                            savedWordIDs.remove(word.id)
                                        }
                                        WidgetCenter.shared.reloadTimelines(ofKind: "QazaqVocabWidget")
                                    } label: {
                                        Label("Удалить", systemImage: "bookmark.slash")
                                    }
                                    .tint(.red)
                                }
                            }
                        } header: {
                            Text(formatWordCount(savedWords.count))
                                .font(.footnote)
                                .foregroundStyle(QazaqTheme.Colors.textTertiary)
                                .textCase(.uppercase)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(QazaqTheme.Colors.background.ignoresSafeArea())
            .navigationTitle("Сохранённое")
            .sheet(item: $selectedWordForDetails) { word in
                WordDetailSheet(word: word, savedWordIDs: $savedWordIDs)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onReceive(AppNavigationState.shared.$dismissDetailsTrigger) { _ in
                selectedWordForDetails = nil
            }
        }
    }
}

#Preview {
    ContentView()
}
