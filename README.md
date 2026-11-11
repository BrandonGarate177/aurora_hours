# Hours

A macOS menu bar app for clocking deep-focus hours. The menu bar reads `Hours`. Click it, click an area like `Coding`, and the bar reads `Coding 0:00` and counts up once a minute. Click the area again to stop. Right-click the menu bar item for Quit, and for Block sites: while a session runs it blocks the sites in `~/Library/Application Support/Hours/blocked.txt` through `/etc/hosts`, asking for your password when it blocks and unblocks.

Needs macOS 14 or later. Building needs Xcode 26 and XcodeGen (`brew install xcodegen`).

```sh
make build   # generate the Xcode project and build Hours.app
make test    # run the unit tests
make run     # build, then open the app (quits a running copy first)
```

Sessions are saved to `~/Library/Group Containers/group.com.hoursapp.Hours/store.json`, where the desktop widget can read them. A store left in `~/Library/Application Support/Hours/` by an older build is copied there on first launch, and the old file is kept. Set `HOURS_STORE=/some/file.json` to use another file.

The widget (small: 13 weeks, medium: a year, with today's total) is in the widget gallery under Hours. With the default ad hoc signing macOS won't let the widget read the store, so its map stays empty. Build with your team to fix that: `make run TEAM=<your team id>`.
