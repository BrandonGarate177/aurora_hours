import AppKit

/// The menu a right-click or control-click on the menu bar item shows.
/// Block sites and Edit blocked list are stubs: the site blocking task gives
/// them actions. Until then they are disabled so they don't pretend to work.
@MainActor
final class MenuController: NSObject, NSMenuDelegate {
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
        openAtLogin.target = self
        openAtLogin.action = #selector(toggleOpenAtLogin)

        let quit = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quit.target = self

        for item in [blockSites, editBlockedList, openAtLogin, quit] {
            menu.addItem(item)
        }
        menu.delegate = self
    }

    func menuWillOpen(_ menu: NSMenu) {
        openAtLogin.state = LoginItem.isOn ? .on : .off
    }

    @objc private func toggleOpenAtLogin() {
        LoginItem.set(!LoginItem.isOn)
    }

    @objc private func quit() {
        onQuit()
    }
}
