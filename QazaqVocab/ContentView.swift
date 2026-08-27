import SwiftUI

// MARK: - 1. Main Navigation (Bottom Tabs)
struct ContentView: View {
    var body: some View {
        TabView {
            // First Tab: The Word Feed
            HomeView()
                .tabItem {
                    Label("Сөздер", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
                }
            
            // Second Tab: The User Profile
            ProfileView()
                .tabItem {
                    Label("Профиль", systemImage: "person.crop.circle.fill")
                }
        }
        // Forces the active tab icon to be white
        .tint(.white)
        // Forces the entire app (including the bottom bar) into dark mode
        .preferredColorScheme(.dark)
    }
}

// MARK: - 2. Home Page (Your Word Feed)
struct HomeView: View {
    @State private var words: [WordItem] = loadWords()
    @State private var likedWords: Set<Int> = []
    @State private var favoriteWords: Set<Int> = []
    
    var body: some View {
        GeometryReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(words) { item in
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
                            
                            HStack(spacing: 28) {
                                Button(action: {
                                    if likedWords.contains(item.id) {
                                        likedWords.remove(item.id)
                                    } else {
                                        likedWords.insert(item.id)
                                    }
                                }) {
                                    Image(systemName: likedWords.contains(item.id) ? "heart.fill" : "heart")
                                        .font(.system(size: 24))
                                        .foregroundStyle(likedWords.contains(item.id) ? .red : Color.white.opacity(0.8))
                                }
                                
                                Button(action: {
                                    if favoriteWords.contains(item.id) {
                                        favoriteWords.remove(item.id)
                                    } else {
                                        favoriteWords.insert(item.id)
                                    }
                                }) {
                                    Image(systemName: favoriteWords.contains(item.id) ? "star.fill" : "star")
                                        .font(.system(size: 24))
                                        .foregroundStyle(favoriteWords.contains(item.id) ? .yellow : Color.white.opacity(0.8))
                                }
                            }
                            .padding(.top, 20)
                            
                            Spacer()
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
            .scrollTargetBehavior(.paging)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12).ignoresSafeArea())
        }
    }
}

// MARK: - 3. Profile Page Design
struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // User Header Area
                    VStack(spacing: 12) {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 80, height: 80)
                            .foregroundStyle(Color.white.opacity(0.8))
                            .padding(.top, 20)
                        
                        Text("Қонақ / Guest")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                    
                    // Stats Grid Layout
                    HStack(spacing: 16) {
                        StatCard(title: "Learned", value: "12", icon: "checkmark.circle.fill", color: .green)
                        StatCard(title: "Streak", value: "3", icon: "flame.fill", color: .orange)
                    }
                    .padding(.horizontal)
                    
                    // Premium / Upsell Card (Crucial for indie revenue)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("QazaqVocab Pro")
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        
                        Text("Unlock all word categories, native audio pronunciation, and interactive widgets.")
                            .font(.subheadline)
                            .foregroundStyle(Color.white.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Button(action: {
                            // Upgrade action goes here later
                        }) {
                            Text("Unlock Lifetime Access")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.top, 4)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            // Matching dark-grey background
            .background(Color(red: 0.12, green: 0.12, blue: 0.12).ignoresSafeArea())
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Reusable UI Component for Stats
struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ContentView()
}
