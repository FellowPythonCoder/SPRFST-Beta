








import AppKit


struct Item {
    var kind = "text"
    var x: CGFloat = 0
    var y: CGFloat = 0
    var w: CGFloat = 0
    var h: CGFloat = 0
    var text = ""
    var colour: NSColor = .white
    var size: CGFloat = 16
    var weight = 400
    var italic = false
    var underline = false
    var mono = false
    var radius: CGFloat = 0
    var borderWidth: CGFloat = 0
    var borderColour: NSColor?
    var link = ""
    var src = ""

    var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
}

struct Page {
    var ok = true
    var address = ""
    var title = ""
    var status = 0
    var error = ""
    var items: [Item] = []
    var height: CGFloat = 0
    var width: CGFloat = 860
    var background: NSColor = Theme.ink
    var text: NSColor = Theme.text
    var quiet: NSColor = Theme.muted
    var secure = false
    var cached = false
    var reading = false
    var ms = 0
    var fetchMs = 0
    var parseMs = 0
    var styleMs = 0
    var layoutMs = 0
    var bytes = 0
    var words = 0
    var blocked = 0
    var hidden = 0
    var requests = 0
    var rules = 0
    var canBack = false
    var canForward = false
    var headings: [String] = []

    static func blank() -> Page { Page() }
}


final class Engine {
    static let shared = Engine()

    private var task: Process?
    private var toEngine: FileHandle?
    private var fromEngine: FileHandle?
    private let queue = DispatchQueue(label: "ai.sprfst.browser.engine")
    private var buffer = Data()
    private(set) var rules = 0

    private var greeting: String?
    private(set) var running = false
    var onTrouble: ((String) -> Void)?


    private var paths: (binary: String, entry: String, home: String)? {
        guard let resources = Bundle.main.resourceURL else { return nil }
        let binary = resources.appendingPathComponent("bin/sprfst").path
        let entry = resources.appendingPathComponent("engine/main.spf").path
        let home = resources.appendingPathComponent("engine").path
        if FileManager.default.isExecutableFile(atPath: binary),
           FileManager.default.fileExists(atPath: entry) {
            return (binary, entry, home)
        }

        var here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        for _ in 0..<6 {
            let b = here.appendingPathComponent("build/bin/sprfst").path
            let e = here.appendingPathComponent("browser/engine/main.spf").path
            if FileManager.default.isExecutableFile(atPath: b),
               FileManager.default.fileExists(atPath: e) {
                return (b, e, here.appendingPathComponent("browser/privacy-rules").path)
            }
            here = here.deletingLastPathComponent()
        }
        return nil
    }

    @discardableResult
    func start() -> Bool {
        guard task == nil else { return true }
        guard let found = paths else {
            onTrouble?("the engine is missing from this application")
            return false
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: found.binary)
        process.arguments = ["run", found.entry, "--", "--serve"]
        var environment = ProcessInfo.processInfo.environment
        environment["SPRFST_BROWSER_HOME"] = found.home
        environment["SPRFST_HOME"] = Bundle.main.resourceURL?.path ?? found.home
        environment["SPRFST_UI"] = "none"
        process.environment = environment

        let input = Pipe(), output = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.running = false
                self?.task = nil
                self?.onTrouble?("the engine stopped")
            }
        }
        do { try process.run() } catch {
            onTrouble?("the engine would not start: \(error.localizedDescription)")
            return false
        }
        task = process
        toEngine = input.fileHandleForWriting
        fromEngine = output.fileHandleForReading
        running = true




        let waited = DispatchSemaphore(value: 0)
        queue.async { [weak self] in
            self?.greeting = self?.readLine()
            waited.signal()
        }
        if waited.wait(timeout: .now() + 5) == .timedOut {
            onTrouble?("the engine did not answer when it started")
            return false
        }
        guard let line = greeting, let shape = decode(line), shape["ok"] as? Bool == true else {
            onTrouble?("the engine started but said nothing we understood")
            return false
        }
        rules = shape["rules"] as? Int ?? 0
        return true
    }

    func stop() {
        guard let process = task else { return }
        task = nil
        running = false
        try? toEngine?.write(contentsOf: Data("{\"do\":\"bye\"}\n".utf8))
        process.terminationHandler = nil
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
            if process.isRunning { process.terminate() }
        }
    }



    func ask(_ request: [String: Any], then hand: @escaping (Page) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let answer = self.exchange(request)
            DispatchQueue.main.async { hand(answer) }
        }
    }

    private func exchange(_ request: [String: Any]) -> Page {
        if task == nil {
            var failed = Page()
            failed.ok = false
            failed.error = "the engine is not running"
            return failed
        }
        guard let line = try? JSONSerialization.data(withJSONObject: request),
              let handle = toEngine else {
            var failed = Page(); failed.ok = false; failed.error = "bad request"
            return failed
        }
        do {
            try handle.write(contentsOf: line)
            try handle.write(contentsOf: Data("\n".utf8))
        } catch {
            var failed = Page(); failed.ok = false; failed.error = "the engine closed"
            return failed
        }
        guard let reply = readLine(), let shape = decode(reply) else {
            var failed = Page(); failed.ok = false; failed.error = "no answer from the engine"
            return failed
        }
        return Engine.page(from: shape)
    }


    private func readLine() -> String? {
        guard let handle = fromEngine else { return nil }
        while true {
            if let stop = buffer.firstIndex(of: 0x0A) {
                let line = buffer.subdata(in: buffer.startIndex..<stop)
                buffer.removeSubrange(buffer.startIndex...stop)
                return String(data: line, encoding: .utf8)
            }
            let chunk = handle.availableData
            if chunk.isEmpty { return nil }
            buffer.append(chunk)
        }
    }

    private func decode(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let shape = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return shape
    }


    static func page(from shape: [String: Any]) -> Page {
        var page = Page()
        page.ok = shape["ok"] as? Bool ?? false
        page.address = shape["address"] as? String ?? ""
        page.title = shape["title"] as? String ?? ""
        page.status = shape["status"] as? Int ?? 0
        page.error = shape["error"] as? String ?? ""
        page.height = CGFloat(shape["height"] as? Double ?? 0)
        page.width = CGFloat(shape["width"] as? Double ?? 860)
        page.background = colour(shape["background"]) ?? Theme.ink
        page.text = colour(shape["text"]) ?? Theme.text
        page.quiet = colour(shape["quiet"]) ?? Theme.muted
        page.secure = shape["secure"] as? Bool ?? false
        page.cached = shape["cached"] as? Bool ?? false
        page.reading = shape["reading"] as? Bool ?? false
        page.ms = shape["ms"] as? Int ?? 0
        page.fetchMs = shape["fetch_ms"] as? Int ?? 0
        page.parseMs = shape["parse_ms"] as? Int ?? 0
        page.styleMs = shape["style_ms"] as? Int ?? 0
        page.layoutMs = shape["layout_ms"] as? Int ?? 0
        page.bytes = shape["bytes"] as? Int ?? 0
        page.words = shape["words"] as? Int ?? 0
        page.blocked = shape["blocked"] as? Int ?? 0
        page.hidden = shape["hidden"] as? Int ?? 0
        page.requests = shape["requests"] as? Int ?? 0
        page.rules = shape["rules"] as? Int ?? 0
        page.canBack = shape["back"] as? Bool ?? false
        page.canForward = shape["forward"] as? Bool ?? false
        page.headings = shape["headings"] as? [String] ?? []

        let raw = shape["items"] as? [[String: Any]] ?? []
        page.items.reserveCapacity(raw.count)
        for one in raw {
            var item = Item()
            item.kind = one["k"] as? String ?? "text"
            item.x = CGFloat(one["x"] as? Double ?? 0)
            item.y = CGFloat(one["y"] as? Double ?? 0)
            item.w = CGFloat(one["w"] as? Double ?? 0)
            item.h = CGFloat(one["h"] as? Double ?? 0)
            item.text = one["t"] as? String ?? ""
            item.colour = colour(one["c"]) ?? page.text
            item.size = CGFloat(one["s"] as? Double ?? 16)
            item.weight = one["b"] as? Int ?? 400
            item.italic = one["i"] as? Bool ?? false
            item.underline = one["u"] as? Bool ?? false
            item.mono = one["m"] as? Bool ?? false
            item.radius = CGFloat(one["r"] as? Double ?? 0)
            item.borderWidth = CGFloat(one["bw"] as? Double ?? 0)
            item.borderColour = colour(one["bc"])
            item.link = one["l"] as? String ?? ""
            item.src = one["src"] as? String ?? ""
            page.items.append(item)
        }
        return page
    }

    private static func colour(_ value: Any?) -> NSColor? {
        guard let packed = value as? Int, packed >= 0 else { return nil }
        return NSColor(srgbRed: CGFloat((packed >> 16) & 0xFF) / 255.0,
                       green: CGFloat((packed >> 8) & 0xFF) / 255.0,
                       blue: CGFloat(packed & 0xFF) / 255.0,
                       alpha: 1)
    }
}
