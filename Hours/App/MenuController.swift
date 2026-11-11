import AppKit

/// The menu a right-click or control-click on the menu bar item shows.
/// Pomodoro has a submenu of presets with a checkmark on the current one.
@MainActor
final class MenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()
    let blockSites = NSMenuItem(title: "Block sites", action: nil, keyEquivalent: "")
    let editBlockedList = NSMenuItem(title: "Edit blocked list", action: nil, keyEquivalent: "")
    let openAtLogin = NSMenuItem(title: "Open at login", action: nil, keyEquivalent: "")
    let pomodoroItem = NSMenuItem(title: "Pomodoro", action: nil, keyEquivalent: "")
    private let blocker: Blocker
    private let pomodoro: Pomodoro
    private var presetItems: [NSMenuItem] = []
    private let onQuit: () -> Void

    init(blocker: Blocker, pomodoro: Pomodoro, onQuit: @escaping () -> Void) {
        self.blocker = blocker
        self.pomodoro = pomodoro
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

        let presets = NSMenu()
        presets.autoenablesItems = false
        for preset in PomodoroPreset.allCases {
            let item = NSMenuItem(title: preset.title, action: #selector(pickPreset(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = preset.rawValue
            presets.addItem(item)
            presetItems.append(item)
        }
        pomodoroItem.submenu = presets

        for item in [blockSites, editBlockedList, pomodoroItem, openAtLogin, quit] {
            menu.addItem(item)
        }
        menu.delegate = self
    }

    func menuWillOpen(_ menu: NSMenu) {
        blockSites.state = blocker.isOn ? .on : .off
        openAtLogin.state = LoginItem.isOn ? .on : .off
        for item in presetItems {
            item.state = item.representedObject as? String == pomodoro.preset.rawValue ? .on : .off
        }
    }

    @objc private func pickPreset(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let preset = PomodoroPreset(rawValue: raw) else { return }
        pomodoro.setPreset(preset)
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
