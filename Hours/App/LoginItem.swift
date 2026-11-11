import Foundation
import ServiceManagement

/// Open at login, through SMAppService.mainApp. Onboarding and the
/// right-click menu both go through here.
@MainActor
enum LoginItem {
    /// True when the app is registered and approved.
    static var isOn: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app. If macOS wants the person to approve
    /// it first, opens Login Items in System Settings.
    @discardableResult
    static func set(_ on: Bool) -> SMAppService.Status {
        let service = SMAppService.mainApp
        do {
            if on {
                try service.register()
            } else if service.status != .notRegistered {
                try service.unregister()
            }
        } catch {
            NSLog("Hours: could not \(on ? "register" : "unregister") the login item: \(error)")
        }
        let status = service.status
        NSLog("Hours: login item status after \(on ? "register" : "unregister"): \(describe(status))")
        if on, status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        return status
    }

    static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .notRegistered: "notRegistered"
        case .enabled: "enabled"
        case .requiresApproval: "requiresApproval"
        case .notFound: "notFound"
        @unknown default: "unknown(\(status.rawValue))"
        }
    }
}
