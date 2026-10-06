






import AppKit

final class Tab {
    let id: String
    var title = "New tab"
    var address = ""
    var page = Page.blank()
    var scroll: CGFloat = 0
    var loading = false
    init(id: String) { self.id = id }
}

final class BrowserWindow: NSWindowController, PageViewDelegate, NSTextFieldDelegate {
    private var tabs: [Tab] = []
    private var current = 0
    private var nextId = 0

    private let strip = TabStrip(frame: .zero)
    private let address = NSTextField()
    private let pageView = PageView()
    private let scroller = NSScrollView()
    private let statusLeft = label("", Fonts.ui(11), Theme.muted)
    private let statusRight = label("", Fonts.ui(11), Theme.faint)
    private let progress = ProgressBar(frame: .zero)
    private var backButton: BarButton!
    private var forwardButton: BarButton!
    private var reloadButton: BarButton!
    private var lensButton: BarButton!
    private var emberButton: BarButton!
    private var shieldButton: BarButton!
    private let findBar = GlassSurface(material: .hudWindow, radius: 8)
    private let findField = NSTextField()
    private let findCount = label("", Fonts.ui(11), Theme.faint)
    private var stripHeight: NSLayoutConstraint!
    private var resizeWork: DispatchWorkItem?

    private var tab: Tab { tabs[min(current, tabs.count - 1)] }
    private var reading = false
    private var ember = true
    private var shieldOn = true


    convenience init() {
        let frame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 860)
        let size = NSRect(x: 0, y: 0,
                          width: min(1180, frame.width - 80),
                          height: min(820, frame.height - 60))
        let window = NSWindow(contentRect: size,
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.title = "SPRFST"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.minSize = NSSize(width: 680, height: 420)
        window.center()
        self.init(window: window)
        window.delegate = self
        build()
        openTab(at: nil)
    }

    private func build() {
        guard let root = window?.contentView else { return }
        root.wantsLayer = true
        root.layer?.backgroundColor = Theme.ink.cgColor




        let bar = GlassSurface(material: .headerView)
        bar.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(bar)

        backButton = BarButton("‹", kind: .quiet) { [weak self] in self?.goBack() }
        forwardButton = BarButton("›", kind: .quiet) { [weak self] in self?.goForward() }
        reloadButton = BarButton("⟳", kind: .quiet) { [weak self] in self?.reload() }
        lensButton = BarButton("Lens", kind: .quiet) { [weak self] in self?.toggleLens() }
        emberButton = BarButton("Ember", kind: .primary) { [weak self] in self?.toggleEmber() }
        shieldButton = BarButton("Shield", kind: .quiet) { [weak self] in self?.showShield() }

        let holder = GlassSurface(material: .hudWindow, radius: 9)
        holder.translatesAutoresizingMaskIntoConstraints = false

        address.translatesAutoresizingMaskIntoConstraints = false
        address.isBordered = false
        address.drawsBackground = false
        address.focusRingType = .none
        address.font = Fonts.ui(13)
        address.textColor = Theme.text
        address.placeholderString = "Search, or type an address"
        address.delegate = self
        address.target = self
        address.action = #selector(addressEntered)
        address.cell?.wraps = false
        address.cell?.isScrollable = true
        holder.addSubview(address)

        let logo = LogoView(frame: .zero)
        logo.translatesAutoresizingMaskIntoConstraints = false

        let pieces: [NSView] = [logo, backButton, forwardButton, reloadButton, holder,
                                lensButton, emberButton, shieldButton]
        for view in pieces { bar.addSubview(view) }


        strip.accessories.addArrangedSubview(BarButton("+", kind: .quiet) { [weak self] in
            self?.openTab(at: nil)
        })
        root.addSubview(strip)


        pageView.delegate = self
        scroller.translatesAutoresizingMaskIntoConstraints = false
        scroller.hasVerticalScroller = true
        scroller.drawsBackground = true
        scroller.backgroundColor = Theme.ink
        scroller.documentView = pageView
        scroller.contentView.postsBoundsChangedNotifications = true
        scroller.scrollerStyle = .overlay
        root.addSubview(scroller)


        let status = GlassSurface(material: .underWindowBackground)
        status.translatesAutoresizingMaskIntoConstraints = false
        let texts: [NSTextField] = [statusLeft, statusRight, findCount]
        for text in texts { text.translatesAutoresizingMaskIntoConstraints = false }
        statusLeft.lineBreakMode = .byTruncatingMiddle
        status.addSubview(statusLeft)
        status.addSubview(statusRight)
        root.addSubview(status)
        root.addSubview(progress)


        findBar.translatesAutoresizingMaskIntoConstraints = false
        findBar.isHidden = true
        findField.translatesAutoresizingMaskIntoConstraints = false
        findField.isBordered = false
        findField.drawsBackground = false
        findField.focusRingType = .none
        findField.font = Fonts.ui(12)
        findField.textColor = Theme.text
        findField.placeholderString = "Find on this page"
        findField.delegate = self
        findField.target = self
        findField.action = #selector(findNext)
        findBar.addSubview(findField)
        findBar.addSubview(findCount)
        root.addSubview(findBar)

        let rule = Hairline(horizontal: true)
        root.addSubview(rule)

        stripHeight = strip.heightAnchor.constraint(equalToConstant: 0)
        stripHeight.priority = .required

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: root.topAnchor, constant: 26),
            bar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            bar.heightAnchor.constraint(equalToConstant: Theme.topBarHeight),

            logo.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 14),
            logo.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            logo.widthAnchor.constraint(equalToConstant: 22),
            logo.heightAnchor.constraint(equalToConstant: 22),

            backButton.leadingAnchor.constraint(equalTo: logo.trailingAnchor, constant: 10),
            backButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 2),
            forwardButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            reloadButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 2),
            reloadButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            holder.leadingAnchor.constraint(equalTo: reloadButton.trailingAnchor, constant: 10),
            holder.trailingAnchor.constraint(equalTo: lensButton.leadingAnchor, constant: -10),
            holder.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            holder.heightAnchor.constraint(equalToConstant: 30),
            address.leadingAnchor.constraint(equalTo: holder.leadingAnchor, constant: 12),
            address.trailingAnchor.constraint(equalTo: holder.trailingAnchor, constant: -12),
            address.centerYAnchor.constraint(equalTo: holder.centerYAnchor),

            lensButton.trailingAnchor.constraint(equalTo: emberButton.leadingAnchor, constant: -4),
            lensButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            emberButton.trailingAnchor.constraint(equalTo: shieldButton.leadingAnchor, constant: -4),
            emberButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
            shieldButton.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -12),
            shieldButton.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            strip.topAnchor.constraint(equalTo: bar.bottomAnchor),
            strip.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            strip.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            stripHeight,

            progress.topAnchor.constraint(equalTo: strip.bottomAnchor),
            progress.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            progress.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            progress.heightAnchor.constraint(equalToConstant: 2),

            scroller.topAnchor.constraint(equalTo: strip.bottomAnchor),
            scroller.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scroller.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            scroller.bottomAnchor.constraint(equalTo: rule.topAnchor),

            rule.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            rule.bottomAnchor.constraint(equalTo: status.topAnchor),

            status.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            status.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            status.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            status.heightAnchor.constraint(equalToConstant: Theme.statusHeight),
            statusLeft.leadingAnchor.constraint(equalTo: status.leadingAnchor, constant: 14),
            statusLeft.centerYAnchor.constraint(equalTo: status.centerYAnchor),
            statusLeft.trailingAnchor.constraint(lessThanOrEqualTo: statusRight.leadingAnchor, constant: -12),
            statusRight.trailingAnchor.constraint(equalTo: status.trailingAnchor, constant: -14),
            statusRight.centerYAnchor.constraint(equalTo: status.centerYAnchor),

            findBar.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -18),
            findBar.topAnchor.constraint(equalTo: strip.bottomAnchor, constant: 12),
            findBar.widthAnchor.constraint(equalToConstant: 260),
            findBar.heightAnchor.constraint(equalToConstant: 32),
            findField.leadingAnchor.constraint(equalTo: findBar.leadingAnchor, constant: 10),
            findField.centerYAnchor.constraint(equalTo: findBar.centerYAnchor),
            findField.trailingAnchor.constraint(equalTo: findCount.leadingAnchor, constant: -8),
            findCount.trailingAnchor.constraint(equalTo: findBar.trailingAnchor, constant: -10),
            findCount.centerYAnchor.constraint(equalTo: findBar.centerYAnchor)
        ])

        NotificationCenter.default.addObserver(
            self, selector: #selector(scrolled),
            name: NSView.boundsDidChangeNotification, object: scroller.contentView)
    }


    func openTab(at place: String?) {
        nextId += 1
        let fresh = Tab(id: String(nextId))
        tabs.append(fresh)
        current = tabs.count - 1
        refreshTabs()
        open(place ?? "sprfst://start")
        if place == nil {
            window?.makeFirstResponder(address)
        } else {
            window?.makeFirstResponder(pageView)
        }
    }

    func closeTab(_ which: Int) {
        guard tabs.count > 1, tabs.indices.contains(which) else { return }
        let going = tabs.remove(at: which)
        Engine.shared.ask(["do": "close", "tab": going.id]) { _ in }
        current = min(current, tabs.count - 1)
        refreshTabs()
        show(tab.page)
    }

    private func refreshTabs() {
        let visible = tabs.count > 1
        stripHeight.constant = visible ? Theme.stripHeight : 0
        strip.isHidden = !visible
        guard visible else { return }
        var buttons: [TabButton] = []
        for (index, one) in tabs.enumerated() {
            let button = TabButton(one.title.isEmpty ? "New tab" : one.title,
                                   closable: true, target: self, action: #selector(tabPicked(_:)))
            button.tag = index
            button.state = index == current ? .on : .off
            button.onClose = { [weak self] in self?.closeTab(index) }
            buttons.append(button)
        }
        strip.setTabs(buttons)
    }

    @objc private func tabPicked(_ sender: NSButton) {
        guard tabs.indices.contains(sender.tag) else { return }
        current = sender.tag
        refreshTabs()
        show(tab.page)
        address.stringValue = tab.address
    }


    func open(_ what: String) {
        let asked = what.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !asked.isEmpty else { return }
        tab.loading = true
        progress.begin()
        statusLeft.stringValue = "reading \(asked)…"
        send(["do": "open", "url": asked])
    }

    private func send(_ request: [String: Any]) {
        var full = request
        let which = tab
        full["tab"] = which.id
        full["width"] = Double(max(360, scroller.contentSize.width - 24))
        Engine.shared.ask(full) { [weak self] page in
            guard let self = self else { return }
            which.loading = false
            which.page = page
            which.address = page.address
            which.title = page.title.isEmpty ? page.address : page.title
            self.progress.finish()
            if which === self.tab {
                self.show(page)
                self.address.stringValue = page.address
                self.window?.title = which.title
            }
            self.refreshTabs()
        }
    }

    private func show(_ page: Page) {
        pageView.loadImages = true
        pageView.show(page)
        scroller.backgroundColor = page.background
        pageView.scroll(NSPoint(x: 0, y: tab.scroll))
        backButton.isEnabled = page.canBack
        forwardButton.isEnabled = page.canForward
        backButton.alphaValue = page.canBack ? 1 : 0.3
        forwardButton.alphaValue = page.canForward ? 1 : 0.3
        shieldButton.text = page.blocked > 0 ? "Shield \(page.blocked)" : "Shield"
        shieldButton.kind = page.blocked > 0 ? .primary : .quiet
        lensButton.kind = page.reading ? .primary : .quiet
        emberButton.kind = ember ? .primary : .quiet

        if !page.error.isEmpty {
            statusLeft.stringValue = page.error
        } else {
            statusLeft.stringValue = page.secure ? "secure · \(page.address)" : page.address
        }
        var parts: [String] = ["\(page.ms) ms"]
        if page.cached { parts[0] = "\(page.ms) ms · from store" }
        parts.append(bytes(page.bytes))
        if page.blocked > 0 { parts.append("\(page.blocked) blocked") }
        if page.hidden > 0 { parts.append("\(page.hidden) hidden") }
        parts.append("\(page.requests) asked for")
        parts.append("\(page.words) words")
        statusRight.stringValue = parts.joined(separator: "  ·  ")
        pageView.refreshMatches()
        updateFindCount()
    }

    private func bytes(_ count: Int) -> String {
        if count <= 0 { return "nothing fetched" }
        if count < 1024 { return "\(count) B" }
        if count < 1024 * 1024 { return String(format: "%.1f kB", Double(count) / 1024) }
        return String(format: "%.1f MB", Double(count) / 1048576)
    }


    @objc func addressEntered() {
        open(address.stringValue)
        window?.makeFirstResponder(pageView)
    }

    @objc func goBack() { tab.scroll = 0; send(["do": "back"]) }
    @objc func goForward() { tab.scroll = 0; send(["do": "forward"]) }
    @objc func reload() { send(["do": "reload"]) }
    @objc func focusAddress() {
        address.becomeFirstResponder()
        address.currentEditor()?.selectAll(nil)
    }
    @objc func newTab() { openTab(at: nil) }
    @objc func closeCurrentTab() { closeTab(current) }
    @objc func showShield() { open("sprfst://shield") }
    @objc func showTrail() { open("sprfst://trail") }
    @objc func showSettings() { open("sprfst://settings") }
    @objc func goHome() { open("sprfst://start") }

    @objc func toggleLens() {
        reading.toggle()
        send(["do": "set", "what": "reading", "value": reading ? "true" : "false"])
    }

    @objc func toggleEmber() {
        ember.toggle()
        emberButton.kind = ember ? .primary : .quiet
        send(["do": "set", "what": "ember", "value": ember ? "true" : "false"])
    }

    @objc func toggleShield() {
        shieldOn.toggle()
        send(["do": "set", "what": "shield", "value": shieldOn ? "true" : "false"])
    }

    @objc func copyPage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pageView.pageText, forType: .string)
    }

    @objc func openFind() {
        findBar.isHidden = false
        findField.becomeFirstResponder()
    }

    @objc func findNext() {
        pageView.findTerm = findField.stringValue
        pageView.refreshMatches()
        pageView.stepMatch(0)
        updateFindCount()
    }

    @objc func hideFind() {
        findBar.isHidden = true
        pageView.findTerm = ""
        window?.makeFirstResponder(pageView)
    }

    private func updateFindCount() {
        let total = pageView.findMatches.count
        findCount.stringValue = total == 0 ? (pageView.findTerm.isEmpty ? "" : "none")
                                           : "\(pageView.currentMatch + 1)/\(total)"
    }

    func controlTextDidChange(_ note: Notification) {
        guard let field = note.object as? NSTextField, field === findField else { return }
        pageView.findTerm = field.stringValue
        pageView.refreshMatches()
        updateFindCount()
        pageView.needsDisplay = true
    }

    @objc private func scrolled() {
        tab.scroll = scroller.contentView.bounds.origin.y
    }


    func pageView(_ view: PageView, didClick link: String) {
        if NSEvent.modifierFlags.contains(.command) {
            openTab(at: link)
            return
        }
        tab.scroll = 0
        open(link)
    }

    func pageView(_ view: PageView, hovering link: String) {
        if link.isEmpty {
            statusLeft.stringValue = tab.page.address
        } else {
            statusLeft.stringValue = link
        }
    }
}


extension BrowserWindow: NSWindowDelegate {
    func windowDidResize(_ notification: Notification) {
        resizeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, !self.tab.address.isEmpty else { return }
            self.send(["do": "width"])
        }
        resizeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }
}





final class GlassSurface: NSVisualEffectView {
    init(material: NSVisualEffectView.Material, radius: CGFloat = 0) {
        super.init(frame: .zero)
        self.material = material
        blendingMode = .withinWindow
        state = .active
        appearance = NSAppearance(named: .darkAqua)
        wantsLayer = true
        layer?.cornerRadius = radius
        layer?.masksToBounds = radius > 0
        layer?.borderWidth = radius > 0 ? 1 : 0
        layer?.borderColor = Theme.edge.withAlphaComponent(0.85).cgColor
        clipToBounds()
    }

    required init?(coder: NSCoder) { fatalError("not loaded from a nib") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)


        let height = min(2.0, max(1.0, bounds.height * 0.08))
        let sheen = NSGradient(colors: [NSColor.white.withAlphaComponent(0.12),
                                         NSColor.white.withAlphaComponent(0.0)])
        sheen?.draw(in: NSRect(x: 0, y: 0, width: bounds.width, height: height), angle: 0)
    }
}


final class ProgressBar: NSView {
    private var fraction: CGFloat = 0
    private var timer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
    }
    required init?(coder: NSCoder) { fatalError() }

    func begin() {
        fraction = 0.08
        needsDisplay = true
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.fraction += (0.9 - self.fraction) * 0.08
            self.needsDisplay = true
        }
    }

    func finish() {
        timer?.invalidate()
        timer = nil
        fraction = 1
        needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            self?.fraction = 0
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirty: CGRect) {
        guard fraction > 0 else { return }
        Theme.amber.setFill()
        CGRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height).fill()
    }
}
