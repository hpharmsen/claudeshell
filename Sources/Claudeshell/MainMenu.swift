import AppKit

/// The main menu; every shortcut of the app is a menu item, so it works from inside a terminal pane.
@MainActor enum MainMenu {
    static func make(target: MainWindowController) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(submenu("Claudeshell", [
            item("Verberg Claudeshell", #selector(NSApplication.hide(_:)), "h"),
            .separator(),
            item("Stop Claudeshell", #selector(NSApplication.terminate(_:)), "q"),
        ]))
        menu.addItem(submenu("Bewerken", [
            item("Kopieer", #selector(NSText.copy(_:)), "c"),
            item("Plak", #selector(NSText.paste(_:)), "v"),
            item("Selecteer alles", #selector(NSText.selectAll(_:)), "a"),
        ]))
        // Cmd+1...0 select tile 1...10, Cmd+Option+1...0 tile 11...20 (R16); hidden but active.
        let tiles = (0..<20).map { index in
            let tile = item("Tile \(index + 1)", #selector(MainWindowController.selectTile(_:)),
                            String((index + 1) % 10), target: target)
            tile.keyEquivalentModifierMask = index < 10 ? [.command] : [.command, .option]
            tile.tag = index
            tile.isHidden = true
            tile.allowsKeyEquivalentWhenHidden = true
            return tile
        }
        menu.addItem(submenu("Projecten", [
            item("Zoek project…", #selector(MainWindowController.showQuickOpen(_:)), "p", target: target),
            item("Spring naar wachtend project", #selector(MainWindowController.jumpToWaiting(_:)), "§", target: target),
        ] + tiles))
        return menu
    }

    private static func item(_ title: String, _ action: Selector, _ key: String, target: AnyObject? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        return item
    }

    private static func submenu(_ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
        let menu = NSMenu(title: title)
        items.forEach(menu.addItem)
        let item = NSMenuItem()
        item.submenu = menu
        return item
    }
}
