# Hours: notes for agents

Hours is a macOS menu bar app for clocking deep-focus hours. Swift 6 (language mode 6), SwiftUI views inside an AppKit `NSStatusItem` + `NSPopover`. macOS 14.0 deployment target, built with Xcode 26.

## Build and test

```sh
make build   # xcodegen generate, then xcodebuild into ./build
make test    # same, then runs HoursTests (Swift Testing)
make run     # build, quit any running Hours, open build/Build/Products/Debug/Hours.app
```

- `project.yml` is the project. `Hours.xcodeproj` is generated and gitignored. Sources are folder globs (`Hours/`, `HoursTests/`), so a new file is picked up by the next `make` without touching `project.yml`.
- No signing (`CODE_SIGN_IDENTITY=-`), no sandbox. Bundle id `com.hoursapp.Hours`, `LSUIElement` (no Dock icon).
- Tests run inside the app (`TEST_HOST`). `HoursApp` returns early from launch when it detects XCTest, so tests never touch the real store or the menu bar.
- `HOURS_STORE=/path/store.json` points the store at another file. Use it for seeding and manual checks; never write test data into `~/Library/Application Support/Hours/`.
- In `#expect`, compare against typed constants (`let hour: TimeInterval = 3600`), not `2 * 3600`: the macro splits the operands and can infer the literal as another type, so equal values fail.

## Driving the app without Accessibility (Debug builds only)

Agents usually can't click the menu bar. A Debug build listens for commands from `scripts/hours-debug.swift` (`Hours/App/DebugControl.swift`, compiled out of Release):

```sh
HOURS_STORE=/tmp/h.json build/Build/Products/Debug/Hours.app/Contents/MacOS/Hours &
swift scripts/hours-debug.swift open          # open the dropdown
swift scripts/hours-debug.swift area:coding   # what a click on Coding does
swift scripts/hours-debug.swift close
swift scripts/hours-debug.swift menu          # right-click menu, closes itself after 3 s
```

`HOURS_APPEARANCE=light` (or `dark`) on launch forces the popover's appearance for screenshots. To capture the popover, find its window id with `CGWindowListCopyWindowInfo` (owner `Hours`, layer 25) and run `screencapture -x -o -l <id>`. On macOS 26 the menu bar item itself is drawn by Control Center (owner `Control Center`, window name `com.hoursapp.Hours`); capture it with `screencapture -R` over that window's bounds. If the menu bar of the active display is hidden (a full-screen app), a popover opened from code is placed off that screen; capturing by window id still works.

## Design rules

The design pictures (six rows: areas, Today, switcher, map, share, block, quit) are out of date. The person condensed the dropdown to the three rows below; build on these.


- Ridiculously basic and monochrome. System font, no icons, no dividers, nothing animated beyond what the system does on its own.
- No emojis anywhere: UI, copy, comments, commits, PRs.
- The only color in the app is each focus area's own color, and it shows only in that area's map. Area names, the menu and every other row are plain text.
- Text uses `.primary` and `.secondary` (system label colors), never a hand-picked gray.
- Menu bar: idle `Hours`, running `Coding 0:42`. Monospaced digits. Ticks once a minute.
- Left click opens the dropdown. Right click or control-click opens a standard menu (see below).
- The dropdown is three rows, 300 pt wide, 14 pt side padding, about 130 pt tall, rows separated by space only:
  1. The area words on one line, `Coding  Writing  Study`. The running one is bold with its time, `Coding 0:42`. Click a word to start, again to stop, another to switch; the dropdown closes. At the right of the same row, today's total as a light `.title` numeral with monospaced digits, `2:15`. There is no separate Today row.
  2. The map, 264 x 34 pt. There is no switcher row. `MapSelection` follows the running area when a session starts, stays on the last pick when idle (All by default), and a click on the map cycles All, then each area. The cycling is already built in `MapSection.swift`; the map task only draws.
  3. `Share  1 year  No hours`.
- The right-click menu: `Block sites` (checkmark item), `Edit blocked list`, `Open at login`, `Quit`. The first three are disabled stubs for the blocking and onboarding tasks. Quit is the only way to quit.
- The popover background is Liquid Glass on macOS 26 and the `.popover` material before that. Only `Glass.swift` knows which.

## Where each feature lives

| File | Owns |
|---|---|
| `Hours/App/HoursApp.swift` | Entry point and app delegate. Builds the store and clock, makes the status item. The seed call is here. A running session stays running across quit and relaunch. |
| `Hours/App/StatusItemController.swift` | Menu bar title, left click (popover) versus right click (menu), what an area click does, including pointing `MapSelection` at the area that starts. `openPopover()` is what onboarding calls to show the dropdown once. |
| `Hours/App/MenuController.swift` | The right-click menu. Site blocking fills `blockSites` and `editBlockedList`; onboarding fills `openAtLogin`. |
| `Hours/App/Glass.swift` | The popover background. The `#available(macOS 26)` switch lives only here. |
| `Hours/App/DebugControl.swift` | Debug-only command listener for scripts. |
| `Hours/Assets.xcassets/AppIcon.appiconset` | App icon. Generated, don't edit the PNGs by hand. |
| `scripts/icon.svg`, `scripts/make-icon.sh` | Icon source and generator. Edit the SVG, then run `./scripts/make-icon.sh`. It uses `sips`, which ships with macOS and reads SVG. |
| `Hours/Model/FocusArea.swift` | `id`, `name`, `colorHex` (six hex digits, no `#`). |
| `Hours/Model/Session.swift` | `areaId`, `start`, `end` (nil while running). |
| `Hours/Model/Store.swift` | Loads and saves `StoreFile` as JSON, atomically. `Store.defaultURL()` is the one place the location is decided: the widget task points it at an app group container. Start, stop and switch (`toggle`). The seed (`seedIfEmpty`, marked `SEED`) goes when onboarding lands. |
| `Hours/Model/Totals.swift` | Daily totals with sessions split at local midnight, today's total, per-area totals over N days as `[day: seconds]`. The map and share tasks read from here. |
| `Hours/Model/MapSelection.swift` | Which map is shown (`.all` or `.area(id)`), in UserDefaults under `mapSelection`, and `next(in:)` for the click-to-cycle order. The share task reads it to know which map to share. |
| `Hours/Model/Clock.swift` | The minute tick. Lines up with the running session's start. Views read `clock.now`. |
| `Hours/Model/HoursMinutes.swift` | `hoursMinutes(_:)`, the `h:mm` format used by the bar and the dropdown. |
| `Hours/Views/DropdownView.swift` | Stacks the three rows. |
| `Hours/Views/Row.swift` | Shared sizes (`Layout`) and the `.row()` modifier. |
| `Hours/Views/AreasRow.swift` | Row 1: area words and today's total. |
| `Hours/Views/MapSection.swift` | Row 2. STUB: 264 x 34 pt of empty space that cycles `MapSelection` on click. The map task draws in it. |
| `Hours/Views/ShareRow.swift` | Row 3. STUB text. The share task. |
| `HoursTests/TotalsTests.swift`, `HoursTests/StoreTests.swift` | Unit tests (`StoreTests.swift` also holds the `MapSelection` tests). Add a new file per feature rather than growing these. |

## Store format

One JSON file, plain `Codable` with default coders, so any target decodes it with a bare `JSONDecoder()`:

```json
{ "version": 1,
  "areas": [{ "id": "coding", "name": "Coding", "colorHex": "2da44e" }],
  "sessions": [{ "areaId": "coding", "start": 816123776.6, "end": 816123869.4 }] }
```

Dates are seconds since 2001-01-01 UTC (Swift's default `Date` encoding). A running session has no `end`. A file that fails to decode is renamed to `store.unreadable-<unix time>.json` and the app starts empty, so a bad write never gets saved over.
