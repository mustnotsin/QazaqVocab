# Real-Device Widget & Deep Link Verification Checklist

This checklist defines the physical device verification requirements for QazaqVocab widgets and deep links on iOS 18+ before TestFlight deployment.

---

## 1. Widget Families & Visual Layout

### Small Home Screen Widget (`systemSmall`)
- [ ] **Header**: Displays `"ГЛАВНОЕ СЛОВО"` in subtle uppercase caption styling (no English `"WORD OF THE DAY"`).
- [ ] **Headword**: Shows the Kazakh headword in bold lowercase with adequate margin.
- [ ] **Part of Speech**: Shows Russian part of speech in italics (e.g., `существительное`, `глагол`).
- [ ] **Meaning**: Shows the Russian meaning, wrapping cleanly up to 2 lines without clipping.
- [ ] **Dark Background**: Container background matches the minimal dark theme (`#1F1F1F` / `0.12` grayscale).

### Medium Home Screen Widget (`systemMedium`)
- [ ] **Two-Column Split**: Left column displays word discovery details; right column displays primary example.
- [ ] **Left Column**:
  - [ ] Header: `"ГЛАВНОЕ СЛОВО"`.
  - [ ] Kazakh headword with minimum scale factor (fits up to 14 characters without clipping).
  - [ ] Transliteration (`/.../`) and part of speech separated by a dot separator.
  - [ ] Russian meaning clearly legible.
- [ ] **Right Column**:
  - [ ] Header: `"ПРИМЕР"` (no English `"EXAMPLE"`).
  - [ ] Kazakh primary example sentence (up to 3 lines, readable line height).
  - [ ] Russian translation of the example in italics/secondary text.
- [ ] **Divider**: Subtle vertical divider line separates both columns.

### Lock Screen Rectangular Widget (`accessoryRectangular`)
- [ ] **Headword**: Prominently displayed in bold headline font, responds to Lock Screen tinting.
- [ ] **Meaning**: Russian meaning shown below headword (up to 2 lines).
- [ ] **Legibility**: Readable against both light and dark Lock Screen wallpapers.

### Lock Screen Inline Widget (`accessoryInline`)
- [ ] **Format**: Displays compact single line: `<kazakh_word> • <russian_meaning>`.
- [ ] **Truncation**: Gracefully handles long words without layout distortion.

---

## 2. Deep Linking & Tap Navigation

- [ ] **Tap from Small Home Screen Widget**:
  - Opens the app directly.
  - Automatically switches to the `Words` tab (if user was on `Saved`).
  - Dismisses any open word detail sheet.
  - Smoothly scrolls to the top card (the featured daily word).
- [ ] **Tap from Medium Home Screen Widget**:
  - Directs to the featured daily word on the `Words` tab.
- [ ] **Tap from Lock Screen Rectangular Widget**:
  - Unlocks device and navigates directly to the featured daily word.
- [ ] **Tap from Lock Screen Inline Widget**:
  - Launches app cleanly to the Words tab.
- [ ] **Cold Launch vs. Warm Launch**:
  - Widget tap from a terminated app state (cold launch) successfully lands on the featured word.
  - Widget tap from backgrounded state (warm launch) seamlessly transitions and scrolls to the featured word.

---

## 3. Date Rollover & Multi-Day Agreement

- [ ] **Same-Day Agreement**:
  - App's featured word and all 4 widget families display the exact same vocabulary entry.
- [ ] **Midnight Transition / Date Advance**:
  - Change device date forward by 1 day in iOS Settings (`Settings > General > Date & Time`).
  - Observe widget timeline updating to the next day's featured word.
  - Open the app: the app's featured word matches the widget's new entry.
- [ ] **Multi-Day Rotation**:
  - Advance device date by 30 days: verify entries cycle through the approved collection deterministically.

---

## 4. Collection Completion & Fallback Handling

- [ ] **Completed Feed Behavior**:
  - Swipe through all 30 entries until reaching the completion card (`CompletionCardView`).
  - Verify widgets **continue rotating** daily through the reviewed pool.
  - Tapping a widget after collection completion still opens the app on today's featured entry.
- [ ] **Airplane Mode / Offline Reliability**:
  - Turn on Airplane Mode and reboot device.
  - Widgets load and render immediately without placeholder hangs or network dependencies.
- [ ] **Graceful Fallback**:
  - Under missing or corrupted content scenarios, widgets reliably display the intentional fallback entry (`нан` / `Хлеб`) without blank screens or crashing.

---

## 5. Accessibility & System Integration

- [ ] **Dynamic Type**: Test with Large, Extra Large, and Accessibility text sizes; verify no text collisions or truncated Kazakh characters.
- [ ] **VoiceOver**:
  - Swipe through widgets with VoiceOver enabled.
  - Kazakh headwords, parts of speech, and Russian meanings are announced distinctly.
- [ ] **Haptics**: Confirm standard system haptic feedback on interactive transitions.
