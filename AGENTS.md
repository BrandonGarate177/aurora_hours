# Hours: notes for agents

Hours is a macOS menu bar app for clocking deep-focus hours. Swift 6 (language mode 6), SwiftUI views inside an AppKit `NSStatusItem` + `NSPopover`. macOS 14.0 deployment target, built with Xcode 26.

## Build and test

```sh
make build   # xcodegen generate, then xcodebuild into ./build
make test    # same, then runs HoursTests (Swift Testing)
make run     # build, stop the copy this checkout's last make run started, start the new one
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
swift scripts/hours-debug.swift "item:Block sites"   # what choosing that menu item does
swift scripts/hours-debug.swift quit          # quits the way the menu's Quit does
```

A command reaches only the copy whose store matches the script's `HOURS_STORE`, spelled the same way, so copies with different stores don't hear each other. Export it once (`export HOURS_STORE=/tmp/h.json`) before launching the app and running the script. `make run` passes `HOURS_STORE` through, so `HOURS_STORE=/tmp/h.json make run` pairs with the script run the same way. It keeps its copy's pid in `build/hours.pid` and stops only that copy, never other checkouts' copies; the app's output goes to `build/hours.log`.

`HOURS_APPEARANCE=light` (or `dark`) on launch forces the popover's appearance for screenshots. To capture the popover, find its window id with `CGWindowListCopyWindowInfo` (owner `Hours`, layer 25) and run `screencapture -x -o -l <id>`. On macOS 26 the menu bar item itself is drawn by Control Center (owner `Control Center`, window name `com.hoursapp.Hours`); capture it with `screencapture -R` over that window's bounds. If the menu bar of the active display is hidden (a full-screen app), a popover opened from code is placed off that screen; capturing by window id still works.

To press a button inside the popover without the debug script, use the Accessibility API by pid (`AXUIElementCreateApplication`, then `AXPress` on the element); it works on your own Debug build. The UserDefaults domain `com.hoursapp.Hours` is shared by every running build on this Mac, so restore any key you change (`mapSelection`, share settings) when you finish.

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
- The right-click menu: `Block sites` (checkmark item), `Edit blocked list`, `Open at login`, `Quit`. Quit is the only way to quit.
- The popover background is Liquid Glass on macOS 26 and the `.popover` material before that. Only `Glass.swift` knows which.

## Where each feature lives

| File | Owns |
|---|---|
| `Hours/App/HoursApp.swift` | Entry point and app delegate. Builds the store and clock, makes the status item. The seed call is here. A running session stays running across quit and relaunch. |
| `Hours/App/StatusItemController.swift` | Menu bar title, left click (popover) versus right click (menu), what an area click does, including pointing `MapSelection` at the area that starts. `openPopover()` is what onboarding calls to show the dropdown once. |
| `Hours/App/MenuController.swift` | The right-click menu. `Block sites` flips `Blocker.isOn`; `Edit blocked list` opens blocked.txt in the default text editor; `Open at login` flips `LoginItem`. |
| `Hours/App/Glass.swift` | The popover background. The `#available(macOS 26)` switch lives only here. |
| `Hours/App/DebugControl.swift` | Debug-only command listener for scripts. |
| `Hours/AppIcon.icon`, `Hours/Assets.xcassets/AppIcon.appiconset` | App icon. `AppIcon.icon` is the Icon Composer format: Xcode 26 builds the macOS 26 icon and the `AppIcon.icns` for macOS 14 and 15 from it. The PNG set alone would be drawn inside a gray frame on macOS 26. Both are generated; don't edit them by hand. |
| `scripts/icon.svg`, `scripts/make-icon.sh` | Icon source and generator. Edit the SVG, then run `./scripts/make-icon.sh`; it rewrites the PNG set and the `.icon` layer. It uses `sips`, which ships with macOS and reads SVG. To check how Finder draws it: `NSWorkspace.shared.icon(forFile:)` on a fresh copy of the built app (the icon cache keys on the path). |
| `Hours/Model/FocusArea.swift` | `id`, `name`, `colorHex` (six hex digits, no `#`). |
| `Hours/Model/Session.swift` | `areaId`, `start`, `end` (nil while running). |
| `Hours/Model/Store.swift` | Loads and saves `StoreFile` as JSON, atomically. `Store.defaultURL()` is the one place the location is decided: the widget task points it at an app group container. Start, stop and switch (`toggle`). The seed (`seedIfEmpty`, marked `SEED`) goes when onboarding lands. |
| `Hours/Model/Totals.swift` | Daily totals with sessions split at local midnight, today's total, per-area totals over N days as `[day: seconds]`. The map and share tasks read from here. |
| `Hours/Model/MapSelection.swift` | Which map is shown (`.all` or `.area(id)`), in UserDefaults under `mapSelection`, and `next(in:)` for the click-to-cycle order. The share task reads it to know which map to share. |
| `Hours/Model/HostsFile.swift` | The hosts rewrite, a pure function: given the file text and the hosts, it returns the text with Hours' lines between `# hours start` and `# hours end` (127.0.0.1 and ::1, each host and its `www.` form). Lines outside the markers stay as they are. Also parses blocked.txt. |
| `Hours/Model/Blocker.swift` | Site blocking. Blocks while a session runs and the setting (UserDefaults `blockSites`, off by default) is on; follows session starts and stops by observing `store.running`. Quit unblocks (`applicationWillTerminate`); launch removes a stale block unless its session is still running. blocked.txt sits next to the store. |
| `Hours/Model/Clock.swift` | The minute tick. Lines up with the running session's start. Views read `clock.now`. |
| `Hours/Model/HoursMinutes.swift` | `hoursMinutes(_:)`, the `h:mm` format used by the bar and the dropdown. |
| `Hours/Views/DropdownView.swift` | Stacks the three rows. |
| `Hours/Views/Row.swift` | Shared sizes (`Layout`) and the `.row()` modifier. |
| `Hours/Views/AreasRow.swift` | Row 1: area words and today's total. |
| `Hours/Views/MapSection.swift` | Row 2. STUB: 264 x 34 pt of empty space that cycles `MapSelection` on click. The map task draws in it. |
| `Hours/Views/ShareRow.swift` | Row 3. STUB text. The share task. |
| `HoursTests/TotalsTests.swift`, `HoursTests/StoreTests.swift` | Unit tests (`StoreTests.swift` also holds the `MapSelection` tests). Add a new file per feature rather than growing these. |

## Site blocking

The block lives in `/etc/hosts`, which needs admin rights. There is no privileged helper: each write (a session start, a stop, quit) runs `do shell script ... with administrator privileges`, so macOS asks for the password each time, then flushes DNS. A `SMAppService.daemon` helper would need a signed app, and the project builds unsigned.

`HOURS_HOSTS=/path/hosts-test` on launch points blocking at a plain file and skips the admin prompt and the DNS flush. Use it, with `HOURS_STORE`, for every manual check; never let a dev build write the real `/etc/hosts`. Tests build `Blocker` with `.file(url)` and a throwaway UserDefaults suite. The setting itself lives in the app's real defaults (`defaults delete com.hoursapp.Hours blockSites` after a manual check).

## Store format

One JSON file, plain `Codable` with default coders, so any target decodes it with a bare `JSONDecoder()`:

```json
{ "version": 1,
  "areas": [{ "id": "coding", "name": "Coding", "colorHex": "2da44e" }],
  "sessions": [{ "areaId": "coding", "start": 816123776.6, "end": 816123869.4 }] }
```

Dates are seconds since 2001-01-01 UTC (Swift's default `Date` encoding). A running session has no `end`. A file that fails to decode is renamed to `store.unreadable-<unix time>.json` and the app starts empty, so a bad write never gets saved over.
