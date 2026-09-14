# QazaqVocab 🇰🇿📱

**QazaqVocab** is a native iOS application designed for learning and expanding Kazakh vocabulary through interactive flashcards, daily widgets, and social sharing.

---

## ✨ Features

- **Interactive Vocabulary Cards:** Learn new Kazakh words, definitions, and contextual usage.
- **Daily Word Widget (WidgetKit):** Stay consistent with a native iOS Home Screen widget featuring the word of the day via `QazaqVocabWidget`.
- **Card Sharing:** Export beautiful 9:16 format cards directly to Instagram Stories or messaging apps via system share sheet (`UIActivityViewController`).
- **Tactile UI & Half-Sheets:** Native SwiftUI interface with custom bottom sheets and tactile interaction elements.
- **Shared Data Layer:** Synchronized state between the main app and widget extensions using `SharedDataManager`.

---

## 🛠 Tech Stack & Architecture

- **Language:** Swift 5.x / 6
- **UI Framework:** SwiftUI
- **Extensions:** WidgetKit
- **Architecture:** MVVM / Modular Components
- **Version Control:** Git (Conventional Commits)

---

## 🚀 Getting Started

### Prerequisites
- macOS Sonoma / Sequoia
- Xcode 15+ / 16+
- iOS 17.0+ deployment target

### Installation
1. Clone the repository:
   ```bash
   git clone [https://github.com/mustnotsin/QazaqVocab.git](https://github.com/mustnotsin/QazaqVocab.git)
