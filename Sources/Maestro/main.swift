import AppKit

// A held key repeats, as in WezTerm; macOS would show its accent menu instead and send no repeats.
UserDefaults.standard.register(defaults: ["ApplePressAndHoldEnabled": false])
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
