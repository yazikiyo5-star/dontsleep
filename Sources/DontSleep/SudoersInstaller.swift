import Foundation

/// Handles one-time installation of a sudoers rule that lets the current
/// user run `sudo pmset -a disablesleep 0/1` without being prompted for
/// a password.
///
/// The installer does the following, all under a single admin-prompt:
///   1. Writes `/etc/sudoers.d/dontsleep` with the NOPASSWD rule.
///   2. Sets its permissions to 440 and owner to root:wheel.
///   3. Runs `visudo -c -f /etc/sudoers.d/dontsleep` to validate syntax.
///
/// If validation fails, the file is removed so the system sudoers isn't
/// left in a broken state.
enum SudoersInstaller {

    static let sudoersPath = "/etc/sudoers.d/dontsleep"

    /// Returns true if the sudoers rule is present AND currently grants
    /// the pmset privilege to the running user (checked via `sudo -n -l`).
    static func isInstalled() -> Bool {
        // First, check the file exists (fast path).
        guard FileManager.default.fileExists(atPath: sudoersPath) else {
            return false
        }
        // Then verify that `sudo -n` can actually run pmset without a prompt.
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["-n", "-l", "/usr/bin/pmset"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Runs the installation using `osascript ... with administrator privileges`,
    /// which prompts the user with a native admin dialog exactly once.
    /// Returns true on success.
    @discardableResult
    static func install() -> Bool {
        let user = NSUserName()
        // Build the rule string. We allow ONLY the two exact pmset invocations
        // we actually need.
        let rule = "\(user) ALL=(root) NOPASSWD: /usr/bin/pmset -a disablesleep 0, /usr/bin/pmset -a disablesleep 1"

        // Shell script that will be executed as root via AppleScript.
        // Use a heredoc-safe format: write the rule to a temp file in /tmp,
        // then move it into place, chmod/chown, and validate.
        let script = """
        set -e
        TMP=$(/usr/bin/mktemp /tmp/dontsleep.sudoers.XXXXXX)
        /bin/cat > "$TMP" <<'EOF'
        \(rule)
        EOF
        /usr/sbin/chown root:wheel "$TMP"
        /bin/chmod 440 "$TMP"
        if /usr/sbin/visudo -c -f "$TMP" >/dev/null; then
            /bin/mv "$TMP" \(sudoersPath)
        else
            /bin/rm -f "$TMP"
            echo "visudo validation failed" >&2
            exit 1
        fi
        """

        // Escape the script for AppleScript string literal.
        let escaped = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")

        let appleScript = """
        do shell script "\(escaped)" with administrator privileges
        """

        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", appleScript]
        let errPipe = Pipe()
        task.standardOutput = Pipe()
        task.standardError = errPipe
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                let errText = String(
                    data: errPipe.fileHandleForReading.readDataToEndOfFile(),
                    encoding: .utf8
                ) ?? ""
                NSLog("[DontSleep] sudoers install failed: \(errText)")
                return false
            }
            return true
        } catch {
            NSLog("[DontSleep] osascript launch error: \(error)")
            return false
        }
    }

    /// Removes the sudoers rule. Also prompts for admin password once.
    @discardableResult
    static func uninstall() -> Bool {
        let script = "/bin/rm -f \(sudoersPath)"
        let appleScript = "do shell script \"\(script)\" with administrator privileges"
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", appleScript]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
