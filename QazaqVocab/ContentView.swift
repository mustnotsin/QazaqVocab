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
    
    @AppStorage("favorite_word_ids", store: UserDefaults(suiteName: "group.com.yourname.QazaqVocab"))
    private var favoriteWordIDsRaw: String = "[]"
    
    @AppStorage("want_to_learn_ids", store: UserDefaults(suiteName: "group.com.yourname.QazaqVocab"))
    private var wantToLearnIDsRaw: String = "[]"
    
    @AppStorage("seen_word_ids", store: UserDefaults(suiteName: "group.com.yourname.QazaqVocab"))
    private var seenWordIDsRaw: String = "[]"
    
    private var favoriteWordIDs: Binding<Set<Int>> {
        Binding(
            get: { decodeIDSet(from: favoriteWordIDsRaw) },
            set: { favoriteWordIDsRaw = encodeIDSet($0) }
        )
    }
    
    private var wantToLearnIDs: Binding<Set<Int>> {
        Binding(
            get: { decodeIDSet(from: wantToLearnIDsRaw) },
            set: { wantToLearnIDsRaw = encodeIDSet($0) }
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
                favoriteWordIDs: favoriteWordIDs,
                wantToLearnIDs: wantToLearnIDs,
                seenWordIDs: seenWordIDs
            )
            .tabItem {
                Label("Words", systemImage: "text.book.closed")
            }
            
            ProfileSectionView(
                words: allWords,
                favoriteWordIDs: favoriteWordIDs,
                wantToLearnIDs: wantToLearnIDs
            )
            .tabItem {
                Label("Profile", systemImage: "person")
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
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

struct HomeFeedView: View {
    let allWords: [WordItem]
    @Binding var favoriteWordIDs: Set<Int>
    @Binding var wantToLearnIDs: Set<Int>
    @Binding var seenWordIDs: Set<Int>
    
    @State private var feedWords: [WordItem] = []
    @State private var selectedWordForDetails: WordItem?
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(feedWords) { item in
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
                            
                            HStack(spacing: 18) {
                                ActionPillButton(
                                    systemName: favoriteWordIDs.contains(item.id) ? "heart.fill" : "heart",
                                    iconColor: favoriteWordIDs.contains(item.id) ? .red : .white.opacity(0.7),
                                    isActive: favoriteWordIDs.contains(item.id)
                                ) {
                                    HapticManager.impact(style: .medium)
                                    toggleMembership(id: item.id, set: &favoriteWordIDs)
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
                                    systemName: wantToLearnIDs.contains(item.id) ? "bookmark.fill" : "bookmark",
                                    iconColor: wantToLearnIDs.contains(item.id) ? .yellow : .white.opacity(0.7),
                                    isActive: wantToLearnIDs.contains(item.id)
                                ) {
                                    HapticManager.impact(style: .medium)
                                    toggleMembership(id: item.id, set: &wantToLearnIDs)
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
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12).ignoresSafeArea())
            .sheet(item: $selectedWordForDetails) { word in
                WordDetailSheet(word: word)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .onAppear {
                prepareFeed()
            }
        }
    }
    
    private func prepareFeed() {
        guard feedWords.isEmpty else { return }
        var unseenWords = allWords.filter { !seenWordIDs.contains($0.id) }
        
        if unseenWords.isEmpty && !allWords.isEmpty {
            seenWordIDs.removeAll()
            unseenWords = allWords
        }
        
        feedWords = unseenWords.shuffled()
    }
    
    private func markAsSeen(id: Int) {
        if !seenWordIDs.contains(id) {
            seenWordIDs.insert(id)
        }
    }
    
    private func toggleMembership(id: Int, set: inout Set<Int>) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
            if set.contains(id) {
                set.remove(id)
            } else {
                set.insert(id)
            }
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "QazaqVocabWidget")
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
        }
    }
}

struct ProfileSectionView: View {
    let words: [WordItem]
    @Binding var favoriteWordIDs: Set<Int>
    @Binding var wantToLearnIDs: Set<Int>
    @State private var selectedTab: Int = 0
    
    private var favoriteWords: [WordItem] {
        words.filter { favoriteWordIDs.contains($0.id) }
    }
    
    private var wantToLearnWords: [WordItem] {
        words.filter { wantToLearnIDs.contains($0.id) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                HStack(spacing: 16) {
                    CategorySummaryCard(
                        title: "Favorite Words",
                        count: favoriteWords.count,
                        icon: "heart.fill",
                        iconColor: .red,
                        isSelected: selectedTab == 0
                    )
                    .onTapGesture {
                        HapticManager.impact(style: .light)
                        selectedTab = 0
                    }
                    
                    CategorySummaryCard(
                        title: "Want to Learn",
                        count: wantToLearnWords.count,
                        icon: "bookmark.fill",
                        iconColor: .yellow,
                        isSelected: selectedTab == 1
                    )
                    .onTapGesture {
                        HapticManager.impact(style: .light)
                        selectedTab = 1
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                
                let activeList = selectedTab == 0 ? favoriteWords : wantToLearnWords
                let emptyMessage = selectedTab == 0 ? "No favorite words added yet" : "No words marked to learn yet"
                
                if activeList.isEmpty {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: selectedTab == 0 ? "heart.slash" : "bookmark.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.3))
                        Text(emptyMessage)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    List(activeList) { word in
                        VStack(alignment: .leading, spacing: 4) {
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
                        .listRowBackground(Color(red: 0.16, green: 0.16, blue: 0.16))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color(red: 0.10, green: 0.10, blue: 0.10).ignoresSafeArea())
            .navigationTitle("Profile")
        }
    }
}

struct CategorySummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let iconColor: Color
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icon)
                    .font(.headline)
                    .foregroundStyle(iconColor)
                Spacer()
                Text("\(count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            
            Text(title)
                .font(.footnote)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(isSelected ? Color(red: 0.22, green: 0.22, blue: 0.24) : Color(red: 0.15, green: 0.15, blue: 0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? iconColor.opacity(0.7) : Color.clear, lineWidth: 1.5)
        )
    }
}

#Preview {
    ContentView()
}
