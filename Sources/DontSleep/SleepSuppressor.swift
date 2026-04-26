import Foundation

enum SuppressionMode: String, CaseIterable {
    case caffeinate  // No password required; does NOT reliably block clamshell sleep
    case pmset       // Requires sudoers setup; fully blocks clamshell sleep
}

/// Starts/stops sleep suppression. Tracks the state so repeated
/// start() calls are idempotent.
final class SleepSuppressor {

    private var caffeinateTask: Process?
    private var pmsetActive: Bool = false

    func start(mode: SuppressionMode) {
        switch mode {
        case .caffeinate:
            startCaffeinate()
        case .pmset:
            setPmsetDisableSleep(true)
        }
    }

    func stop(mode: SuppressionMode) {
        switch mode {
        case .caffeinate:
            stopCaffeinate()
        case .pmset:
            setPmsetDisableSleep(false)
        }
    }

    // MARK: - caffeinate

    private func startCaffeinate() {
        // Already running?
        if let t = caffeinateTask, t.isRunning { return }

        let task = Process()
        task.launchPath = "/usr/bin/caffeinate"
        // -d: prevent display sleep
        // -i: prevent idle sleep
        // -m: prevent disk sleep
        // -s: prevent system sleep (only while on AC)
        // -u: declare user is active (resets idle timer at start)
        task.arguments = ["-disu"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            caffeinateTask = task
        } catch {
            NSLog("[DontSleep] failed to start caffeinate: \(error)")
        }
    }

    private func stopCaffeinate() {
        caffeinateTask?.terminate()
        caffeinateTask = nil
    }

    // MARK: - pmset

    /// Turns `pmset -a disablesleep` on or off.
    /// Uses `sudo -n` (non-interactive) so it only works if the user has
    /// already installed the /etc/sudoers.d/dontsleep entry.
    private func setPmsetDisableSleep(_ enabled: Bool) {
        let value = enabled ? "1" : "0"
        let task = Process()
        task.launchPath = "/usr/bin/sudo"
        task.arguments = ["-n", "/usr/bin/pmset", "-a", "disablesleep", value]
        let err = Pipe()
        task.standardOutput = Pipe()
        task.standardError = err
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                pmsetActive = enabled
            } else {
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                let errText = String(data: errData, encoding: .utf8) ?? ""
                NSLog("[DontSleep] pmset failed (status=\(task.terminationStatus)): \(errText)")
            }
        } catch {
            NSLog("[DontSleep] pmset launch error: \(error)")
        }
    }
}
