// =====================================================================
//  SPRFST Tour — the way in.
//
//  Start the lessons, put one window on the screen, and give every
//  menu item something real to do. Nothing here relies on the
//  responder chain: each item points at this delegate and names the
//  method it wants, so there are no grey entries that do nothing.
// =====================================================================
import AppKit

final class TourDelegate: NSObject, NSApplicationDelegate {
    var tour: TourWindow?

    func applicationDidFinishLaunching(_ note: Notification) {
        Tour.shared.onTrouble = { reason in
            DispatchQueue.main.async { TourDelegate.explain(reason) }
        }
        guard Tour.shared.start() else {
            TourDelegate.explain("the lessons could not be started")
            NSApp.terminate(nil)
            return
        }
        buildMenu()
        let window = TourWindow()
        window.showWindow(nil)
        window.window?.makeKeyAndOrderFront(nil)
        tour = window
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ note: Notification) {
        Tour.shared.stop()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { true }

    static func explain(_ reason: String) {
        let alert = NSAlert()
        alert.messageText = "SPRFST Tour cannot run"
        alert.informativeText = reason + """


        The tour needs the SPRFST interpreter and learn/tour.spf. From a
        checkout, build them first:

            make
            ./tools/build_tour_app.sh --install
        """
        alert.alertStyle = .critical
        alert.runModal()
    }

    // --------------------------------------------------------------- menu
    private func item(_ menu: NSMenu, _ title: String, _ key: String,
                      _ method: String, _ mask: NSEvent.ModifierFlags = [.command]) {
        let entry = NSMenuItem(title: title, action: #selector(passOn(_:)), keyEquivalent: key)
        entry.keyEquivalentModifierMask = mask
        entry.target = self
        entry.representedObject = method
        menu.addItem(entry)
    }

    @objc private func passOn(_ sender: NSMenuItem) {
        guard let method = sender.representedObject as? String else { return }
        if let window = tour, window.responds(to: NSSelectorFromString(method)) {
            window.perform(NSSelectorFromString(method))
        }
    }

    private func buildMenu() {
        let bar = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About SPRFST Tour", action: #selector(about), keyEquivalent: "")
            .target = self
        appMenu.addItem(NSMenuItem.separator())
        item(appMenu, "Open my work folder", "", "openFolder")
        item(appMenu, "Start over…", "", "startOver")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide SPRFST Tour", action: #selector(NSApplication.hide(_:)),
                        keyEquivalent: "h")
        appMenu.addItem(withTitle: "Quit SPRFST Tour", action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu
        bar.addItem(appItem)

        let lessonItem = NSMenuItem()
        let lessonMenu = NSMenu(title: "Lesson")
        item(lessonMenu, "Check my answer", "\r", "check")
        item(lessonMenu, "Run", "r", "runIt")
        lessonMenu.addItem(NSMenuItem.separator())
        item(lessonMenu, "Hint", "h", "askHint", [.command, .shift])
        item(lessonMenu, "Show me the answer", "", "showAnswer")
        lessonMenu.addItem(NSMenuItem.separator())
        item(lessonMenu, "Next lesson", "]", "goNext")
        item(lessonMenu, "Previous lesson", "[", "goBack")
        lessonItem.submenu = lessonMenu
        bar.addItem(lessonItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)),
                         keyEquivalent: "a")
        editItem.submenu = editMenu
        bar.addItem(editItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimise", action: #selector(NSWindow.performMiniaturize(_:)),
                           keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)),
                           keyEquivalent: "")
        windowItem.submenu = windowMenu
        bar.addItem(windowItem)

        NSApp.mainMenu = bar
        NSApp.windowsMenu = windowMenu
    }

    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "SPRFST Tour"
        alert.informativeText = """
        Twenty six lessons, basics to pro.

        Every lesson, every check and every point is decided by
        learn/tour.spf, which is written in SPRFST. When you press Check
        my answer, your file is handed to the real interpreter and the
        real output is compared. Nothing here is simulated.

        Your work is in \(Tour.shared.home)
        """
        alert.runModal()
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
let delegate = TourDelegate()
application.delegate = delegate
application.run()
