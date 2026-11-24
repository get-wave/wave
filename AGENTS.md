# Wave — CLAUDE.md

Wave is a lightweight macOS dictation app. Press a shortcut, speak, and your words are transcribed and pasted at the cursor. It supports on-device Whisper and Groq cloud transcription, plus an AI Mode that sends the transcription to an LLM and pastes the response.

---

## Architecture

- **Single source of truth.** All app state lives in one `@Observable @MainActor` class (`AppState`). Do not create additional observable singletons or pass state through multiple layers.
- **Services are owned by `AppState`**, not created in views. Views call methods on the state object; they never instantiate services directly.
- **All persistent settings** are stored in `UserDefaults` via `didSet` on the property. No other persistence mechanism. The one exception is secrets (API keys), which go in the Keychain through `KeychainService`, still written from the property's `didSet`.
- **Views are display-only.** Business logic belongs in `AppState` or a service. If a view is doing more than formatting and rendering, move the logic out.

---

## Design system

All UI uses the design system in `Wave/DesignSystem.swift`, documented in `DESIGN.md`. Read `DESIGN.md` before any UI change and run its checklist after.

- Use `WaveFont`, `WaveSpacing`, `WaveRadius`, `Color.brand` and the `Color.wave…` status colours. Never write a raw font size, padding number, corner radius or `Color(red:…)` in a view.
- Buttons always use a `.wave…` button style (`.wave`, `.wavePrimary`, `.waveSubtle`, `.waveIcon`, `.waveIconDestructive`).
- Section titles use `WaveSection("Title") { … }`. Do not write a private `section(_:)` helper.
- Rows and cards use `.waveCard()` (or `.waveCard(tint:)` for selected or warning rows); tiles and charts use `.waveSurface()`; text editors use `.waveField()`.
- Brand colour is `#7B6EF6`, defined as `Color.brand` in `DesignSystem.swift`. Never use `.blue` or `.accentColor`.
- Floating overlays (pill, answer card) use `WaveHUD` tokens and are always dark.
- If something is missing, add a token or component to `DesignSystem.swift` and `DESIGN.md` first, then use it.

---

## Navigation

The sidebar is a `NavigationSplitView` with a fixed-width column. Items are grouped into sections. The detail pane renders the selected view.

- Settings pages (General, Shortcut, Models) are **not scrollable** — use a plain `VStack` with padding.
- The window size is **fixed**. Do not make it resizable or change its dimensions without explicit instruction.
- Sidebar icons use **SF Symbols** via `Label("Title", systemImage: "symbol.name")`.

---

## Shortcuts

- Distinguish Left vs Right modifier keys explicitly — flag bitmasks alone (`maskAlternate`, `maskCommand`) are identical for both sides. Track the exact keyCodes being held to tell them apart.
- The shortcut recorder persists the pressed combination (`savedCombo`) after the user releases keys, so Enter can confirm it even after release. Regular key presses save immediately without needing Enter.

---

## MenuBar

Keep the menu bar menu lean and in this order:
1. Status (idle / recording / transcribing / error)
2. Recent Transcriptions submenu (max 7, copy on click, truncate long text)
3. Check for Updates
4. Settings (⌘,)
5. Quit (⌘Q)

Dividers between logical groups, not between every item.

---

## Code style

- No docstrings or comments on code you didn't write or change.
- No error handling for internal code paths — only at system boundaries (user input, external APIs).
- No helpers or abstractions for one-off operations.
- No speculative features, flags, or "future-proofing."
- Prefer editing existing files over creating new ones.
- If something is unused, delete it — don't rename it with a leading underscore or leave a comment.

---

## Things never to do

- Do not add `ScrollView` to settings pages.
- Do not mock services in a way that diverges from production behavior.
- Do not re-add `CommandGroup(replacing: .undoRedo) {}` — it breaks Cmd+Z in text fields.
- Do not remove the menu-cleaning logic in `applicationDidBecomeActive` — it removes ghost headers left by SwiftUI `CommandGroup` replacements.
- Do not push to main or create PRs without being explicitly asked.
