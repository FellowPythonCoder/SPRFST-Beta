


import AppKit

final class BrowserDelegate: NSObject, NSApplicationDelegate {
    var windows: [BrowserWindow] = []
    var front: BrowserWindow? { windows.first { $0.window?.isKeyWindow == true } ?? windows.last }

    func applicationDidFinishLaunching(_ note: Notification) {
        Engine.shared.onTrouble = { trouble in
            let alert = NSAlert()
            alert.messageText = "The engine stopped"
            alert.informativeText = trouble + "\n\nThe browser's engine is a SPRFST program inside this " +
                "application. Without it there is no browser, so this window will not load pages."
            alert.alertStyle = .critical
            alert.addButton(withTitle: "Quit")
            alert.runModal()
            NSApp.terminate(nil)
        }
        _ = Engine.shared.start()
        buildMenu()
        newWindow(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }


    func application(_ application: NSApplication, open urls: [URL]) {
        guard let first = urls.first else { return }
        if let window = front {
            window.openTab(at: first.absoluteString)
            window.window?.makeKeyAndOrderFront(nil)
        } else {
            newWindow(nil)
            front?.open(first.absoluteString)
        }
        for extra in urls.dropFirst() { front?.openTab(at: extra.absoluteString) }
    }
    func applicationWillTerminate(_ note: Notification) { Engine.shared.stop() }

    @objc func newWindow(_ sender: Any?) {
        let window = BrowserWindow()
        windows.append(window)
        window.showWindow(nil)
        window.window?.makeKeyAndOrderFront(nil)
    }



    @objc func pass(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? String, let window = front else { return }
        window.perform(NSSelectorFromString(action))
    }

    private func item(_ title: String, _ key: String, _ action: String,
                      _ flags: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let entry = NSMenuItem(title: title, action: #selector(pass(_:)), keyEquivalent: key)
        entry.keyEquivalentModifierMask = flags
        entry.representedObject = action
        entry.target = self
        return entry
    }

    private func buildMenu() {
        let bar = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About SPRFST Browser", action: #selector(about), keyEquivalent: "")
            .target = self
        appMenu.addItem(.separator())
        appMenu.addItem(item("Settings", ",", "showSettings"))
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide SPRFST", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit SPRFST", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        bar.addItem(appItem)

        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let window = NSMenuItem(title: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "n")
        window.target = self
        fileMenu.addItem(window)
        fileMenu.addItem(item("New Tab", "t", "newTab"))
        fileMenu.addItem(item("Close Tab", "w", "closeCurrentTab"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(item("Copy Page Text", "c", "copyPage", [.command, .shift]))
        fileItem.submenu = fileMenu
        bar.addItem(fileItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(.separator())
        editMenu.addItem(item("Find on Page", "f", "openFind"))
        editMenu.addItem(item("Find Again", "g", "findNext"))
        editMenu.addItem(item("Hide Find", "e", "hideFind"))
        editItem.submenu = editMenu
        bar.addItem(editItem)

        let goItem = NSMenuItem()
        let goMenu = NSMenu(title: "Go")
        goMenu.addItem(item("Address", "l", "focusAddress"))
        goMenu.addItem(.separator())
        goMenu.addItem(item("Back", "[", "goBack"))
        goMenu.addItem(item("Forward", "]", "goForward"))
        goMenu.addItem(item("Reload", "r", "reload"))
        goMenu.addItem(.separator())
        goMenu.addItem(item("Start Page", "1", "goHome", [.command, .shift]))
        goMenu.addItem(item("The Shield", "2", "showShield", [.command, .shift]))
        goMenu.addItem(item("The Trail", "3", "showTrail", [.command, .shift]))
        goItem.submenu = goMenu
        bar.addItem(goItem)

        let viewItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(item("The Lens", "k", "toggleLens"))
        viewMenu.addItem(item("Ember", "u", "toggleEmber"))
        viewMenu.addItem(item("The Shield", "d", "toggleShield", [.command, .shift]))
        viewItem.submenu = viewMenu
        bar.addItem(viewItem)

        NSApp.mainMenu = bar
    }

    @objc private func about() {
        front?.open("sprfst://about")
    }
}

let application = NSApplication.shared
let delegate = BrowserDelegate()
application.delegate = delegate
application.setActivationPolicy(.regular)
application.activate(ignoringOtherApps: true)
application.run()
