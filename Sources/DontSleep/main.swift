import AppKit
import Foundation

// Menu bar only app (no Dock icon)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)

let delegate = AppDelegate()
app.delegate = delegate

// Install SIGTERM / SIGINT / SIGHUP handlers so that `kill <pid>` (or a
// parent shell exiting) triggers NSApplicationDelegate.applicationWillTerminate,
// giving SleepSuppressor a chance to terminate its caffeinate child and / or
// turn `pmset disablesleep` back off. Without this, a background-launched
// binary that receives SIGTERM dies instantly and leaves the child caffeinate
// orphaned — a real bug observed during testing.
var signalSources: [DispatchSourceSignal] = []
for sig in [SIGTERM, SIGINT, SIGHUP] as [Int32] {
    // Ignore default disposition so DispatchSource can observe the signal.
    signal(sig, SIG_IGN)
    let src = DispatchSource.makeSignalSource(signal: sig, queue: .main)
    src.setEventHandler {
        // Ask NSApplication to quit cleanly. This routes through
        // applicationShouldTerminate → applicationWillTerminate.
        NSApp.terminate(nil)
    }
    src.resume()
    signalSources.append(src)
}

app.run()
