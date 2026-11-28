import AppKit

// A held key repeats, as in WezTerm; macOS would show its accent menu instead and send no repeats.
// Set in the app domain: it outranks a global ApplePressAndHoldEnabled, which register(defaults:) does not.
UserDefaults.standard.set(false, forKey: "ApplePressAndHoldEnabled")
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
