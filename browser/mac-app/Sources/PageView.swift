







import AppKit

protocol PageViewDelegate: AnyObject {
    func pageView(_ view: PageView, didClick link: String)
    func pageView(_ view: PageView, hovering link: String)
}

final class PageView: NSView {
    weak var delegate: PageViewDelegate?

    private(set) var page = Page.blank()
    private var tracking: NSTrackingArea?
    private var hovered = -1
    private var pictures: [String: NSImage] = [:]
    private var asked: Set<String> = []
    private var linkIndices: [Int] = []
    private static let imageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        cache.totalCostLimit = 96 * 1024 * 1024
        return cache
    }()
    var findTerm = "" { didSet { needsDisplay = true } }
    var findMatches: [Int] = []
    var currentMatch = 0
    var loadImages = true

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }


    func show(_ page: Page) {
        self.page = page
        pictures.removeAll(keepingCapacity: true)
        asked.removeAll(keepingCapacity: true)
        hovered = -1
        linkIndices = page.items.indices.filter { !page.items[$0].link.isEmpty }
        setFrameSize(NSSize(width: max(page.width, 320), height: max(page.height, 200)))
        if loadImages { fetchPictures() }
        refreshMatches()
        needsDisplay = true
    }

    var pageText: String {
        var out: [String] = []
        var line = ""
        var at: CGFloat = -1
        for item in page.items where !item.text.isEmpty {
            if item.y != at {
                if !line.isEmpty { out.append(line) }
                line = ""
                at = item.y
            }
            line += (line.isEmpty ? "" : " ") + item.text
        }
        if !line.isEmpty { out.append(line) }
        return out.joined(separator: "\n")
    }


    func refreshMatches() {
        findMatches = []
        guard !findTerm.isEmpty else { return }
        let needle = findTerm.lowercased()
        for (i, item) in page.items.enumerated()
        where !item.text.isEmpty && item.text.lowercased().contains(needle) {
            findMatches.append(i)
        }
        currentMatch = 0
    }

    func stepMatch(_ by: Int) {
        guard !findMatches.isEmpty else { return }
        currentMatch = (currentMatch + by + findMatches.count) % findMatches.count
        let item = page.items[findMatches[currentMatch]]
        scrollToVisible(item.rect.insetBy(dx: -40, dy: -120))
        needsDisplay = true
    }


    override func draw(_ dirty: CGRect) {


        page.background.setFill()
        bounds.intersection(dirty).fill()

        let band = dirty.insetBy(dx: 0, dy: -8)
        for (index, item) in page.items.enumerated() {
            guard item.rect.intersects(band) else { continue }
            switch item.kind {
            case "rect":
                item.colour.setFill()
                item.rect.fill()
            case "rule":
                item.colour.withAlphaComponent(0.45).setFill()
                CGRect(x: item.x, y: item.y, width: item.w, height: max(1, item.h)).fill()
            case "image":
                drawPicture(item)
            default:
                drawWords(item, index: index)
            }
        }
    }

    private func drawWords(_ item: Item, index: Int) {
        guard !item.text.isEmpty else { return }
        let face = font(for: item)
        var colour = item.colour
        if index == hovered, !item.link.isEmpty { colour = Theme.amberLight }

        if !findTerm.isEmpty, item.text.lowercased().contains(findTerm.lowercased()) {
            let here = findMatches.indices.contains(currentMatch) && findMatches[currentMatch] == index
            (here ? Theme.amber : Theme.amber.withAlphaComponent(0.28)).setFill()
            item.rect.insetBy(dx: -2, dy: -1).fill()
            if here { colour = Theme.ink }
        }

        let top = item.y + item.size * 0.78 - face.ascender
        (item.text as NSString).draw(at: CGPoint(x: item.x, y: top),
                                     withAttributes: [.font: face, .foregroundColor: colour])

        if item.underline || (index == hovered && !item.link.isEmpty) {
            colour.withAlphaComponent(index == hovered ? 0.9 : 0.4).setFill()
            CGRect(x: item.x, y: item.y + item.size * 1.02, width: item.w, height: 1).fill()
        }
    }

    private func drawPicture(_ item: Item) {
        if let picture = pictures[item.src] {
            let box = item.rect
            let scale = min(box.width / max(picture.size.width, 1),
                            box.height / max(picture.size.height, 1))
            let size = NSSize(width: picture.size.width * scale, height: picture.size.height * scale)
            let where_ = CGRect(x: box.minX + (box.width - size.width) / 2,
                                y: box.minY + (box.height - size.height) / 2,
                                width: size.width, height: size.height)


            picture.draw(in: where_, from: .zero, operation: .sourceOver, fraction: 1,
                         respectFlipped: true, hints: [.interpolation: NSImageInterpolation.medium])
            return
        }
        item.colour.withAlphaComponent(0.6).setStroke()
        let frame = NSBezierPath(roundedRect: item.rect.insetBy(dx: 0.5, dy: 0.5),
                                 xRadius: 6, yRadius: 6)
        frame.lineWidth = 1
        frame.stroke()
        if !item.text.isEmpty {
            let face = Fonts.ui(11)
            let words = item.text as NSString
            let size = words.size(withAttributes: [.font: face])
            words.draw(at: CGPoint(x: item.rect.midX - size.width / 2,
                                   y: item.rect.midY - size.height / 2),
                       withAttributes: [.font: face, .foregroundColor: page.quiet])
        }
    }

    private var faces: [String: NSFont] = [:]
    private func font(for item: Item) -> NSFont {
        let key = "\(Int(item.size * 10))|\(item.weight)|\(item.italic)|\(item.mono)"
        if let kept = faces[key] { return kept }
        var face: NSFont
        if item.mono {
            face = Fonts.mono(item.size)
        } else {



            let name = item.weight >= 600
                ? (item.italic ? "Helvetica-BoldOblique" : "Helvetica-Bold")
                : (item.italic ? "Helvetica-Oblique" : "Helvetica")
            face = NSFont(name: name, size: item.size)
                ?? NSFont.systemFont(ofSize: item.size,
                                     weight: item.weight >= 600 ? .bold : .regular)
        }
        faces[key] = face
        return face
    }


    private func fetchPictures() {
        let wanted = Set(page.items.filter { $0.kind == "image" && !$0.src.isEmpty }.map { $0.src })
        for address in wanted where !asked.contains(address) {
            guard let url = URL(string: address), url.scheme == "http" || url.scheme == "https"
            else { continue }
            asked.insert(address)
            let key = address as NSString
            if let cached = Self.imageCache.object(forKey: key) {
                pictures[address] = cached
                continue
            }
            var request = URLRequest(url: url, timeoutInterval: 12)
            request.setValue("SPRFST/0.1", forHTTPHeaderField: "User-Agent")
            URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
                guard let data = data, data.count < 12_000_000,
                      let picture = NSImage(data: data) else { return }
                Self.imageCache.setObject(picture, forKey: key, cost: data.count)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.pictures[address] = picture
                    self.needsDisplay = true
                }
            }.resume()
        }
    }


    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let old = tracking { removeTrackingArea(old) }
        let area = NSTrackingArea(rect: bounds,
                                  options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    private func item(at point: CGPoint) -> Int {



        for index in linkIndices.reversed()
        where page.items[index].rect.insetBy(dx: -1, dy: -2).contains(point) {
            return index
        }
        return -1
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let found = item(at: point)
        if found != hovered {
            hovered = found
            delegate?.pageView(self, hovering: found >= 0 ? page.items[found].link : "")
            if found >= 0 { NSCursor.pointingHand.set() } else { NSCursor.arrow.set() }
            needsDisplay = true
        }
    }

    override func mouseExited(with event: NSEvent) {
        hovered = -1
        NSCursor.arrow.set()
        delegate?.pageView(self, hovering: "")
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let found = item(at: point)
        guard found >= 0 else { return }
        delegate?.pageView(self, didClick: page.items[found].link)
    }

    override func resetCursorRects() {
        super.resetCursorRects()
        for index in linkIndices {
            addCursorRect(page.items[index].rect, cursor: .pointingHand)
        }
    }
}
