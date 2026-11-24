# Wave design system

Wave's UI is built from one file: [`Wave/DesignSystem.swift`](Wave/DesignSystem.swift). Views use its tokens and components; they don't set raw font sizes, paddings, radii or colours. If a screen needs something the system doesn't have, add it to `DesignSystem.swift` and to this page first, then use it.

## Principles

1. **Quiet and native.** Wave sits next to the user's work. Use system materials, secondary text and SF Symbols. Use brand colour only for the one action or state that matters on a screen.
2. **One way to do each thing.** A button, a row, a section header, a status colour: each has exactly one component or token.
3. **Fixed, calm layouts.** The window is a fixed size and settings pages don't scroll. Content fits by being concise, not by growing.
4. **Dark heads-up surface for overlays.** The pill and answer card float over other apps and are always dark, whatever the system appearance.

## Tokens

### Colour

| Token | Value | Use |
| --- | --- | --- |
| `Color.brand` | `#7B6EF6` | Primary actions, selected states, charts. Never `.blue` or `.accentColor`. |
| `Color.waveSuccess` | system green | "Active", "Operational", granted |
| `Color.waveWarning` | system orange | Permissions needed, attention |
| `Color.waveDanger` | system red | Errors, delete icons |
| `.secondary` / `.tertiary` / `.quaternary` | system | Supporting text, hints, empty states |
| `WaveHUD.*` | dark grey at 90%, white strokes | Pill, answer card and other floating overlays only |

### Typography (`WaveFont`)

| Token | Spec | Use |
| --- | --- | --- |
| `pageTitle` | 20 semibold rounded | Big numbers on stat tiles |
| `sheetTitle` | 16 semibold | Title of a sheet or dialog |
| `sectionHeader` | 11 medium, uppercase, secondary | Section labels and table column headers |
| `body` | 13 | Row labels, form fields, body text |
| `bodyEmphasis` | 13 medium | Row titles, item names |
| `detail` | 12 | Secondary detail, descriptions |
| `caption` | 11 | Hints and metadata under a control |
| `micro` | 10 | Timestamps, footnotes ("Right-click for more options") |
| `mono` | 12 monospaced | API keys, code, prompts |
| `button` | 12 medium rounded | All button labels (applied by the button styles) |
| `chartLabel` | 10 medium rounded | Chart axis labels, small button icons in the HUD |
| `heatmapLabel` | 9 monospaced | Activity heatmap axes only |
| `emptyStateIcon` / `dismissIcon` / `heroIcon` | 24 / 18 / 48 | Empty-state symbol, sheet close button, onboarding illustration |

Use `.monospacedDigit()` on a token for numbers that change in place (percentages, prices).

### Spacing (`WaveSpacing`)

| Token | Value | Use |
| --- | --- | --- |
| `page` | 16 | Padding around every sidebar page |
| `section` | 20 | Between sections on a page |
| `item` | 8 | Between items inside a section (applied by `WaveSection`) |
| `card` | 12 | Inner padding of cards, tiles and charts |
| `sheet` | 20 | Padding inside sheets |

### Radius (`WaveRadius`)

| Token | Value | Use |
| --- | --- | --- |
| `card` | 8 | Cards, rows, fields, tiles |
| `button` | 6 | Standard buttons |
| `primaryButton` | 7 | Primary buttons |

## Components

| Component | Use it for | Instead of |
| --- | --- | --- |
| `WaveSection("Title") { … }` | Every titled block on a page | A private `section(_:)` helper per view |
| `.buttonStyle(.wave)` | Standard actions: Edit, Use, Download, Allow | Hand-set font, padding and background |
| `.buttonStyle(.wavePrimary)` | The one main action of a sheet or row: Save, Add | `Color.brand` backgrounds by hand |
| `.buttonStyle(.waveSubtle)` | Cancel and other dismissive text actions | Plain buttons with secondary text |
| `.buttonStyle(.waveIcon)` | Icon-only actions: close, cancel download, remove term | `.plain` plus a foreground colour |
| `.buttonStyle(.waveIconDestructive)` | Trash icons | Red plain buttons |
| `.waveCard()` | A list row or settings row | Padding plus `.quaternary.opacity(0.5)` by hand |
| `.waveCard(tint: .brand)` | A selected row | Custom fill and stroke |
| `.waveCard(tint: .waveWarning)` | A row that needs attention (permissions) | Orange fill and stroke |
| `.waveSurface()` | Tiles and charts that set their own padding | A background by hand |
| `.waveField()` | Background of a `TextEditor` | A background by hand |
| `.padding(WaveSpacing.page)` | The outer padding of a page | `.padding(16)` |

All button styles dim to 40% when disabled and to 70% while pressed. Don't add `.opacity` or `.foregroundStyle` to change that.

## Layout rules

- Sidebar pages: a `VStack(alignment: .leading, spacing: WaveSpacing.section)` of `WaveSection`s, padded with `WaveSpacing.page`. Settings pages (General, Shortcuts, Models) never scroll.
- The page title lives in the window toolbar. Never repeat it as the first section header; open with a one-line `detail` description or a differently named section instead.
- The toolbar keeps its automatic background, so content that scrolls under the title is covered by the system material. Never hide the toolbar background.
- The sidebar is a fixed 160 pt column, so the detail pane is always 360 pt wide. Lay pages out for that width.
- Sheets: `sheetTitle` heading, `WaveSpacing.sheet` padding, actions at the bottom right with `waveSubtle` Cancel before the `wavePrimary` action.
- Rows: a leading label (`bodyEmphasis` with an optional `caption` beneath), `Spacer()`, trailing controls in an `HStack(spacing: 6)`.
- Empty states: centred `emptyStateIcon` in `.quaternary`, a `detail` line in `.tertiary`, an optional `caption` hint.

## Allowed exceptions

These keep raw values because they draw graphics, not UI chrome:

- `OverlayPanel` waveform bar colours and the AI-mode gradient.
- Chart geometry in `HomePageView` (bar corners of 4, heatmap cells of 2).
- The two dark-surface buttons inside `AnswerCardView`, which use `WaveHUD` tokens and `WaveRadius.button`.

## Checklist for any UI change

- [ ] No `.font(.system(size:))`, raw `cornerRadius`, raw padding numbers or `Color(red:)` in the view
- [ ] Every button uses a `.wave…` style
- [ ] Section titles use `WaveSection`
- [ ] Rows and cards use `.waveCard` or `.waveSurface`
- [ ] Brand colour appears at most once per row or sheet, for the main action or the selected state
- [ ] Works in light and dark appearance
- [ ] First section header doesn't repeat the page title
- [ ] Fits a 360 pt wide detail pane; scrolled content stays below the title
