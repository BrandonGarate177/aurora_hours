# Hours: notes for agents

Hours is a macOS menu bar app for clocking deep-focus hours. Swift 6 (language mode 6), SwiftUI views inside an AppKit `NSStatusItem` + `NSPopover`. macOS 14.0 deployment target, built with Xcode 26.

## Build and test

```sh
make build   # xcodegen generate, then xcodebuild into ./build
make test    # same, then runs HoursTests (Swift Testing)
make run     # build, stop the copy this checkout's last make run started, start the new one
```

- `project.yml` is the project. `Hours.xcodeproj` is generated and gitignored. Sources are folder globs (`Hours/`, `Shared/`, `HoursWidget/`, `HoursTests/`), so a new file is picked up by the next `make` without touching `project.yml`.
- Ad hoc signing by default (`CODE_SIGN_IDENTITY=-`). The app isn't sandboxed; the widget extension (`com.hoursapp.Hours.Widget`, embedded in `Contents/PlugIns`) is, as WidgetKit requires. Bundle id `com.hoursapp.Hours`, `LSUIElement` (no Dock icon). See "Widget and signing" below.
- Tests run inside the app (`TEST_HOST`). `HoursApp` returns early from launch when it detects XCTest, so tests never touch the real store or the menu bar.
- `HOURS_STORE=/path/store.json` points the store at another file. Use it for seeding and manual checks; never write test data into the real store (`~/Library/Group Containers/<group>/store.json`, or the old `~/Library/Application Support/Hours/store.json`). The widget can't see `HOURS_STORE`: it always reads the group container.
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

### Pomodoro

`HOURS_POMODORO_SCALE=0.01` on launch (Debug builds only) multiplies every interval and break, so `25 / 5` runs 15 s of work and a 3 s break; `0.05` gives 75 s and 15 s, enough to screenshot the break. The one-minute rule for a call ending mid-break scales too; the 5 s call check does not. The debug script picks a preset with `pomodoro:25/5` (or `off`, `50/10`, `90/15`), presses Skip with `skip`, and fakes a call with `call:on` (`call:off`, and `call:auto` to go back to the real camera and mic). For a real call, hold the default input open: `ffmpeg -f avfoundation -i ":<index of the default mic>" -f null -` (list the indexes with `ffmpeg -f avfoundation -list_devices true -i ""`).

The break covers every screen at `.screenSaver` level and takes focus, so it gets in the way of anyone, or any other agent, using this Mac. Keep test breaks short. Capture a break by window id (owner `Hours`, layer 1000). The preset is in UserDefaults under `pomodoro`: delete it when you finish (`defaults delete com.hoursapp.Hours pomodoro`). The phase sits next to the store as `<store name>.pomodoro.json`.

## Design rules

The design pictures (six rows: areas, Today, switcher, map, share, block, quit) are out of date. The person condensed the dropdown to the three rows below; build on these.


- Ridiculously basic and monochrome. System font, no icons, no dividers, nothing animated beyond what the system does on its own.
- No emojis anywhere: UI, copy, comments, commits, PRs.
- The only color in the app is each focus area's own color, and it shows only in that area's map. Area names, the menu and every other row are plain text.
- Text uses `.primary` and `.secondary` (system label colors), never a hand-picked gray.
- Menu bar: idle `Hours`, running `Coding 0:42`. Monospaced digits. Ticks once a minute. With Pomodoro on it counts the interval down by the second, `Coding 24:59`, and a break reads `Break 4:59`.
- Left click opens the dropdown. Right click or control-click opens a standard menu (see below).
- The dropdown is three rows, 300 pt wide, 14 pt side padding, about 130 pt tall, rows separated by space only:
  1. The area words on one line, `Coding  Writing  Study`. The running one is bold with its time, `Coding 0:42`. Click a word to start, again to stop, another to switch; the dropdown closes. At the right of the same row, today's total as a light `.title` numeral with monospaced digits, `2:15`. There is no separate Today row.
  2. The map, 264 x 34 pt. There is no switcher row. `MapSelection` follows the running area when a session starts, stays on the last pick when idle (All by default), and a click on the map cycles All, then each area. The cycling is already built in `MapSection.swift`; the map task only draws.
  3. `Share  1 year  No hours`.
- The right-click menu: `Block sites` (checkmark item), `Edit blocked list`, `Pomodoro` (submenu `Off`, `25 / 5`, `50 / 10`, `90 / 15`, checkmark on the current one), `Open at login`, `Quit`. Quit is the only way to quit.
- The popover background is Liquid Glass on macOS 26 and the `.popover` material before that. Only `Glass.swift` knows which.

## Widget and signing

- Files both targets build live in `Shared/` (model, `Store`, `Totals`, `MapGrid`, `MapLevels`, `MapView`, `WidgetSnapshot`). `project.yml` lists `Shared` as a source of both `Hours` and `HoursWidget`; a plain folder was simpler in XcodeGen than a framework target. Tests reach `Shared/` through `@testable import Hours`.
- The store lives in the app group container, `~/Library/Group Containers/<group>/store.json`. `Store.appGroup` reads `<group>` from the process's own signed entitlements. On launch `StoreMigration` copies the old `~/Library/Application Support/Hours/store.json` there, checks the copy, and only then switches; the old file stays. If the container can't be written it stays on the old path.
- Entitlements are in `Entitlements/` and go to codesign through `OTHER_CODE_SIGN_FLAGS`, not `CODE_SIGN_ENTITLEMENTS`: with the latter Xcode refuses an app group without a provisioning profile.
- Ad hoc builds use the group `group.com.hoursapp.Hours`. The app can use that container, but macOS refuses it to the sandboxed widget ("Group containers identifiers should be prefixed by requestor's team ID", logged by `containermanagerd`), so the widget draws an empty map. `make run TEAM=<team id>` signs with that team's Apple Development identity and the group `<team id>.com.hoursapp.Hours`, which works without a provisioning profile. The two groups are separate containers with separate stores.
- To fill the widget with sample data: `HOURS_STORE="$HOME/Library/Group Containers/<group>/store.json" make seed` (it copies an existing store aside first), then restart the app and start or stop a session so it reloads the widget. Debug script commands for a TEAM build need `HOURS_GROUP=<team id>.com.hoursapp.Hours`.
- Every checkout builds the same bundle id. App Intents (`linkd`) and the widget's configuration follow whichever copy LaunchServices prefers, and a copy without the widget makes the widget fail with "Intent configuration is required but was not provided". Check with `NSWorkspace.shared.urlsForApplications(withBundleIdentifier:)`; `lsregister -u <other copy>` then `lsregister -f <this copy>` (in `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/`) fixes it. After that, `killall chronod` makes the widget gallery read the new description.
- Logs: `/usr/bin/log show --last 2m --predicate 'process == "HoursWidget" OR process == "containermanagerd"'` (in zsh, bare `log` is a builtin).

## Where each feature lives

| File | Owns |
|---|---|
| `Hours/App/HoursApp.swift` | Entry point and app delegate. Builds the store and clock, makes the status item. A running session stays running across quit and relaunch. |
| `Hours/App/StatusItemController.swift` | Menu bar title, left click (popover) versus right click (menu), what an area click does, including pointing `MapSelection` at the area that starts. `openPopover()` is what onboarding calls to show the dropdown once. |
| `Hours/App/MenuController.swift` | The right-click menu. `Block sites` flips `Blocker.isOn`; `Edit blocked list` opens blocked.txt in the default text editor; `Pomodoro` is a submenu of presets; `Open at login` flips `LoginItem`. |
| `Hours/App/BreakWindow.swift` | The full-screen break: one borderless window per screen at `.screenSaver` level, `Break`, the time left, `Skip` (Esc too). Shown while `Pomodoro.showsBreakWindow` is true. |
| `Hours/App/CallDetector.swift` | Whether the person is on a call: any camera running (CoreMediaIO) or the default input running (CoreAudio). Screen sharing is not detected; there is no public signal for another app capturing the screen. |
| `Hours/App/Glass.swift` | The popover background. The `#available(macOS 26)` switch lives only here. |
| `Hours/App/DebugControl.swift` | Debug-only command listener for scripts. |
| `Hours/AppIcon.icon`, `Hours/Assets.xcassets/AppIcon.appiconset` | App icon. `AppIcon.icon` is the Icon Composer format: Xcode 26 builds the macOS 26 icon and the `AppIcon.icns` for macOS 14 and 15 from it. The PNG set alone would be drawn inside a gray frame on macOS 26. Both are generated; don't edit them by hand. |
| `scripts/icon.svg`, `scripts/make-icon.sh` | Icon source and generator. Edit the SVG, then run `./scripts/make-icon.sh`; it rewrites the PNG set and the `.icon` layer. It uses `sips`, which ships with macOS and reads SVG. To check how Finder draws it: `NSWorkspace.shared.icon(forFile:)` on a fresh copy of the built app (the icon cache keys on the path). |
| `Shared/FocusArea.swift` | `id`, `name`, `colorHex` (six hex digits, no `#`). |
| `Shared/Session.swift` | `areaId`, `start`, `end` (nil while running). |
| `Shared/Store.swift` | Loads and saves `StoreFile` as JSON, atomically. `Store.defaultURL()` (HOURS_STORE, else the group container), `groupURL()`, `legacyURL()` and `appGroup` decide the location. Start, stop and switch (`toggle`). |
| `Hours/Model/StoreMigration.swift` | Picks the store file for this launch and copies the old Application Support store into the group container once. |
| `Shared/Totals.swift` | Daily totals with sessions split at local midnight, today's total, per-area totals over N days as `[day: seconds]`. The map and share tasks read from here. |
| `Hours/Model/MapSelection.swift` | Which map is shown (`.all` or `.area(id)`), in UserDefaults under `mapSelection`, and `next(in:)` for the click-to-cycle order. The share task reads it to know which map to share. |
| `Hours/Model/HostsFile.swift` | The hosts rewrite, a pure function: given the file text and the hosts, it returns the text with Hours' lines between `# hours start` and `# hours end` (127.0.0.1 and ::1, each host and its `www.` form). Lines outside the markers stay as they are. Also parses blocked.txt. |
| `Hours/Model/Blocker.swift` | Site blocking. Blocks while a session runs and the setting (UserDefaults `blockSites`, off by default) is on; follows session starts and stops by observing `store.running`. Quit unblocks (`applicationWillTerminate`); launch removes a stale block unless its session is still running. blocked.txt stays in `~/Library/Application Support/Hours/` (next to `HOURS_STORE` when set); only the app reads it. |
| `Hours/Model/Clock.swift` | The minute tick. Lines up with the running session's start. Views read `clock.now`. |
| `Hours/Model/Pomodoro.swift` | Presets (in UserDefaults under `pomodoro`), the interval state machine and the call rule. Starting an area starts interval 1; an interval's end closes the session and starts a break; the break's end starts a new session of the same area. Every 4th break is 3x. Area clicks go through it (`areaClicked`), so a click during a break stops the run. |
| `Shared/HoursMinutes.swift` | `hoursMinutes(_:)`, the `h:mm` format used by the bar and the dropdown. |
| `Hours/Views/DropdownView.swift` | Stacks the three rows. |
| `Hours/Views/Row.swift` | Shared sizes (`Layout`) and the `.row()` modifier. |
| `Hours/Views/AreasRow.swift` | Row 1: area words and today's total. |
| `Hours/Views/MapSection.swift` | Row 2. STUB: 264 x 34 pt of empty space that cycles `MapSelection` on click. The map task draws in it. |
| `Hours/Views/ShareRow.swift` | Row 3. STUB text. The share task. |
| `Shared/MapGrid.swift`, `Shared/MapLevels.swift`, `Shared/MapView.swift` | The map: where each day sits, its shade step, and the drawing. `MapView` takes a column count and square size; the widget passes its own. |
| `Shared/WidgetSnapshot.swift` | What the widget draws (levels, color, today's total) from a `StoreFile`, the same way the dropdown works it out, and the next timeline date (top of the next hour). |
| `HoursWidget/` | The widget extension: `HoursWidget.swift` (bundle, timeline provider, small and medium views), `MapIntent.swift` (the All or one-area setting), `Info.plist`. |
| `Entitlements/` | App group entitlements for the app and the widget (sandbox too). The Makefile writes team-prefixed copies into `build/entitlements` for TEAM builds. |
| `HoursTests/WidgetTests.swift` | Timeline dates, the store migration, and widget map data against the dropdown's. |
| `HoursTests/PomodoroTests.swift` | Interval math, the session split, skip, stop during a break, and the call rule with a fake detector. |
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
