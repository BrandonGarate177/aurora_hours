import AppKit

/// The menu a right-click or control-click on the menu bar item shows.
@MainActor
final class MenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()
    let blockSites = NSMenuItem(title: "Block sites", action: nil, keyEquivalent: "")
    let editBlockedList = NSMenuItem(title: "Edit blocked list", action: nil, keyEquivalent: "")
    let openAtLogin = NSMenuItem(title: "Open at login", action: nil, keyEquivalent: "")
    private let blocker: Blocker
    private let onQuit: () -> Void

    init(blocker: Blocker, onQuit: @escaping () -> Void) {
        self.blocker = blocker
        self.onQuit = onQuit
        super.init()
        menu.autoenablesItems = false

        blockSites.target = self
        blockSites.action = #selector(toggleBlockSites)
        editBlockedList.target = self
        editBlockedList.action = #selector(editList)
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
        blockSites.state = blocker.isOn ? .on : .off
        openAtLogin.state = LoginItem.isOn ? .on : .off
    }

    @objc private func toggleOpenAtLogin() {
        LoginItem.set(!LoginItem.isOn)
    }

    /// Flips the setting. With a session running, this blocks or unblocks now.
    @objc private func toggleBlockSites() {
        blocker.isOn.toggle()
    }

    /// Opens blocked.txt in the default text editor, creating it first.
    @objc private func editList() {
        NSWorkspace.shared.open(blocker.ensureList())
    }

    @objc private func quit() {
        onQuit()
    }
}
