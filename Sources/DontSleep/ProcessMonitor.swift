import Foundation

/// Polls the system process list periodically and reports whether
/// any of the watched process names are currently running.
final class ProcessMonitor {

    private var watchedNames: [String]
    private let pollInterval: TimeInterval
    private var timer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "dontsleep.processmonitor")

    /// Snapshot of which watched processes are running (name -> running)
    private var runningSet: Set<String> = []
    private let runningLock = NSLock()

    /// Called when the aggregate "any watched running" state changes.
    var onStateChange: ((Bool) -> Void)?

    private var lastAnyRunning: Bool = false

    init(watchedProcessNames: [String], pollInterval: TimeInterval = 3.0) {
        self.watchedNames = watchedProcessNames
        self.pollInterval = pollInterval
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: pollInterval)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func updateWatchedProcessNames(_ names: [String]) {
        queue.async {
            self.watchedNames = names
            self.tick()
        }
    }

    /// Synchronous check against the last snapshot (thread-safe).
    func isRunning(_ name: String) -> Bool {
        runningLock.lock()
        defer { runningLock.unlock() }
        return runningSet.contains(name)
    }

    func anyWatchedProcessRunning() -> Bool {
        runningLock.lock()
        defer { runningLock.unlock() }
        return !runningSet.isEmpty
    }

    // MARK: - Implementation

    private func tick() {
        let snapshot = currentProcessNames()
        var matched: Set<String> = []
        for name in watchedNames {
            // Substring match, case-insensitive, so "claude" matches "claude-code"
            let lowerName = name.lowercased()
            for proc in snapshot {
                if proc.lowercased().contains(lowerName) {
                    matched.insert(name)
                    break
                }
            }
        }

        runningLock.lock()
        runningSet = matched
        runningLock.unlock()

        let anyRunning = !matched.isEmpty
        if anyRunning != lastAnyRunning {
            lastAnyRunning = anyRunning
            DispatchQueue.main.async { [weak self] in
                self?.onStateChange?(anyRunning)
            }
        }
    }

    /// Returns the list of currently running process commands (as ps -o comm=).
    private func currentProcessNames() -> [String] {
        let task = Process()
        task.launchPath = "/bin/ps"
        task.arguments = ["-Axo", "comm="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        do {
            try task.run()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return text
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
