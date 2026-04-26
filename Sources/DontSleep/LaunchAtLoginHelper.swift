import Foundation
import ServiceManagement

/// Thin wrapper around SMAppService to enable / disable "launch at login".
///
/// Notes:
/// - SMAppService.mainApp requires macOS 13 (Ventura) or later.
/// - For it to work on a development build, the app must be run from
///   `/Applications`, `~/Applications`, or an explicitly registered
///   location. Running the raw `.build/release/DontSleep` binary will
///   silently succeed but the helper won't actually register.
/// - Errors are swallowed and logged; the caller should read
///   `isEnabled` after a change to know whether it stuck.
enum LaunchAtLoginHelper {

    /// True if the app is currently registered to launch at login.
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// Enable or disable launch-at-login. Returns true on success.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            return true
        } catch {
            NSLog("[DontSleep] LaunchAtLoginHelper.setEnabled(\(enabled)) failed: \(error)")
            return false
        }
    }
}
