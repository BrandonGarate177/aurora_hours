# Hours

A macOS menu bar app for clocking deep-focus hours. The menu bar reads `Hours`. Click it, click an area like `Coding`, and the bar reads `Coding 0:00` and counts up once a minute. Click the area again to stop. Right-click the menu bar item for Quit.

Needs macOS 14 or later. Building needs Xcode 26 and XcodeGen (`brew install xcodegen`).

```sh
make build   # generate the Xcode project and build Hours.app
make test    # run the unit tests
make run     # build, then open the app (quits a running copy first)
```

Sessions are saved to `~/Library/Application Support/Hours/store.json`. Set `HOURS_STORE=/some/file.json` to use another file.
