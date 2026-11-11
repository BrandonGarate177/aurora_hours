import AppKit

/// The menu a right-click or control-click on the menu bar item shows.
/// Block sites, Edit blocked list and Open at login are stubs: the site
/// blocking and onboarding tasks give them actions. Until then they are
/// disabled so they don't pretend to work.
@MainActor
final class MenuController: NSObject {
    let menu = NSMenu()
    let blockSites = NSMenuItem(title: "Block sites", action: nil, keyEquivalent: "")
    let editBlockedList = NSMenuItem(title: "Edit blocked list", action: nil, keyEquivalent: "")
    let openAtLogin = NSMenuItem(title: "Open at login", action: nil, keyEquivalent: "")
    private let onQuit: () -> Void

    init(onQuit: @escaping () -> Void) {
        self.onQuit = onQuit
        super.init()
        menu.autoenablesItems = false

        blockSites.state = .off // STUB: checkmark shows when blocking is on.
        blockSites.isEnabled = false
        editBlockedList.isEnabled = false // STUB
        openAtLogin.isEnabled = false // STUB

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self

        for item in [blockSites, editBlockedList, openAtLogin, quit] {
            menu.addItem(item)
        }
    }

    @objc private func quit() {
        onQuit()
    }
}
