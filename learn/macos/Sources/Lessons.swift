// =====================================================================
//  The bridge to the tour.
//
//  learn/tour.spf holds every lesson, every check and every point. It
//  is started once as a child process and spoken to one JSON line at a
//  time. This file turns those lines into values and nothing more: no
//  lesson text, no scoring and no idea of what a right answer looks
//  like lives on this side, so the window and the terminal can never
//  disagree about how far you have got.
// =====================================================================
import AppKit

struct Standing {
    var points = 0
    var rank = "Newcomer"
    var finished = 0
    var lessons = 26
    var most = 2600

    var fraction: Double {
        most > 0 ? Double(points) / Double(most) : 0
    }
}

struct Card {
    var n = 1
    var id = ""
    var stage = ""
    var title = ""
    var done = false
    var hinted = false
    var shown = false
    var worth = 0
}

struct Lesson {
    var n = 1
    var id = ""
    var stage = ""
    var title = ""
    var teach: [String] = []
    var example: [String] = []
    var brief: [String] = []
    var code = ""
    var expect: [String] = []
    var file = ""
    var side = ""
    var sideFile = ""
    var sideCode = ""
    var done = false
    var hinted = false
    var shown = false
}

struct Verdict {
    var passed = false
    var broken = false
    var output: [String] = []
    var expected: [String] = []
    var differs = 1
    var awarded = 0
    var firstTime = false
}

final class Tour {
    static let shared = Tour()

    private var task: Process?
    private var toEngine: FileHandle?
    private var fromEngine: FileHandle?
    private let queue = DispatchQueue(label: "ai.sprfst.tour.engine")
    private var buffer = Data()
    private var greeting: String?

    private(set) var running = false
    private(set) var count = 26
    private(set) var home = ""
    var onTrouble: ((String) -> Void)?

    // Inside the application the interpreter and the lessons travel in
    // Resources. Running from a checkout they are up the tree.
    private var paths: (binary: String, entry: String)? {
        if let resources = Bundle.main.resourceURL {
            let binary = resources.appendingPathComponent("bin/sprfst").path
            let entry = resources.appendingPathComponent("lessons/tour.spf").path
            if FileManager.default.isExecutableFile(atPath: binary),
               FileManager.default.fileExists(atPath: entry) {
                return (binary, entry)
            }
        }
        var here = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        for _ in 0..<6 {
            let binary = here.appendingPathComponent("build/bin/sprfst").path
            let entry = here.appendingPathComponent("learn/tour.spf").path
            if FileManager.default.isExecutableFile(atPath: binary),
               FileManager.default.fileExists(atPath: entry) {
                return (binary, entry)
            }
            here = here.deletingLastPathComponent()
        }
        return nil
    }

    @discardableResult
    func start() -> Bool {
        guard task == nil else { return true }
        guard let found = paths else {
            onTrouble?("the lessons are missing from this application")
            return false
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: found.binary)
        process.arguments = ["run", found.entry, "--", "--serve"]
        var environment = ProcessInfo.processInfo.environment
        environment["SPRFST_BIN"] = found.binary
        environment["SPRFST_HOME"] = Bundle.main.resourceURL?.path ?? ""
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
                self?.onTrouble?("the lessons stopped")
            }
        }
        do { try process.run() } catch {
            onTrouble?("the lessons would not start: \(error.localizedDescription)")
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
        if waited.wait(timeout: .now() + 8) == .timedOut {
            onTrouble?("the lessons did not answer when they started")
            return false
        }
        guard let line = greeting, let shape = decode(line),
              shape["ok"] as? Bool == true else {
            onTrouble?("the lessons started but said nothing we understood")
            return false
        }
        count = shape["lessons"] as? Int ?? 26
        home = shape["home"] as? String ?? ""
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

    // ------------------------------------------------------------ asking
    private func ask(_ request: [String: Any], then hand: @escaping ([String: Any]) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let answer = self.exchange(request)
            DispatchQueue.main.async { hand(answer) }
        }
    }

    private func exchange(_ request: [String: Any]) -> [String: Any] {
        guard let body = try? JSONSerialization.data(withJSONObject: request),
              let handle = toEngine else { return [:] }
        var line = body
        line.append(0x0A)
        do { try handle.write(contentsOf: line) } catch { return [:] }
        guard let reply = readLine(), let shape = decode(reply) else { return [:] }
        return shape
    }

    private func readLine() -> String? {
        while true {
            if let stop = buffer.firstIndex(of: 0x0A) {
                let slice = buffer.subdata(in: buffer.startIndex..<stop)
                buffer.removeSubrange(buffer.startIndex...stop)
                return String(data: slice, encoding: .utf8)
            }
            guard let chunk = try? fromEngine?.read(upToCount: 1 << 16), let got = chunk,
                  !got.isEmpty else { return nil }
            buffer.append(got)
        }
    }

    private func decode(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let shape = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return shape
    }

    // ------------------------------------------------------- the requests
    private func standing(_ shape: [String: Any]) -> Standing {
        var out = Standing()
        guard let s = shape["standing"] as? [String: Any] else { return out }
        out.points = s["points"] as? Int ?? 0
        out.rank = s["rank"] as? String ?? "Newcomer"
        out.finished = s["finished"] as? Int ?? 0
        out.lessons = s["lessons"] as? Int ?? 26
        out.most = s["most"] as? Int ?? 2600
        return out
    }

    private func texts(_ value: Any?) -> [String] {
        (value as? [Any])?.compactMap { $0 as? String } ?? []
    }

    func list(_ hand: @escaping ([Card], Standing) -> Void) {
        ask(["do": "list"]) { [weak self] shape in
            guard let self = self else { return }
            var cards: [Card] = []
            for raw in (shape["items"] as? [Any] ?? []) {
                guard let one = raw as? [String: Any] else { continue }
                var card = Card()
                card.n = one["n"] as? Int ?? 0
                card.id = one["id"] as? String ?? ""
                card.stage = one["stage"] as? String ?? ""
                card.title = one["title"] as? String ?? ""
                card.done = one["done"] as? Bool ?? false
                card.hinted = one["hinted"] as? Bool ?? false
                card.shown = one["shown"] as? Bool ?? false
                card.worth = one["worth"] as? Int ?? 0
                cards.append(card)
            }
            hand(cards, self.standing(shape))
        }
    }

    func open(_ n: Int, _ hand: @escaping (Lesson, Standing) -> Void) {
        ask(["do": "open", "n": n]) { [weak self] shape in
            guard let self = self else { return }
            var one = Lesson()
            one.n = shape["n"] as? Int ?? n
            one.id = shape["id"] as? String ?? ""
            one.stage = shape["stage"] as? String ?? ""
            one.title = shape["title"] as? String ?? ""
            one.teach = self.texts(shape["teach"])
            one.example = self.texts(shape["example"])
            one.brief = self.texts(shape["brief"])
            one.code = shape["code"] as? String ?? ""
            one.expect = self.texts(shape["expect"])
            one.file = shape["file"] as? String ?? ""
            one.side = shape["side"] as? String ?? ""
            one.sideFile = shape["side_file"] as? String ?? ""
            one.sideCode = shape["side_code"] as? String ?? ""
            one.done = shape["done"] as? Bool ?? false
            one.hinted = shape["hinted"] as? Bool ?? false
            one.shown = shape["shown"] as? Bool ?? false
            hand(one, self.standing(shape))
        }
    }

    func check(_ n: Int, code: String, side: String,
               _ hand: @escaping (Verdict, Standing) -> Void) {
        var request: [String: Any] = ["do": "check", "n": n, "code": code]
        if !side.isEmpty { request["side_code"] = side }
        ask(request) { [weak self] shape in
            guard let self = self else { return }
            var verdict = Verdict()
            verdict.passed = shape["passed"] as? Bool ?? false
            verdict.broken = shape["broken"] as? Bool ?? false
            verdict.output = self.texts(shape["output"])
            verdict.expected = self.texts(shape["expected"])
            verdict.differs = shape["differs"] as? Int ?? 1
            verdict.awarded = shape["awarded"] as? Int ?? 0
            verdict.firstTime = shape["first_time"] as? Bool ?? false
            hand(verdict, self.standing(shape))
        }
    }

    func run(_ n: Int, code: String, side: String, _ hand: @escaping ([String]) -> Void) {
        var request: [String: Any] = ["do": "run", "n": n, "code": code]
        if !side.isEmpty { request["side_code"] = side }
        ask(request) { [weak self] shape in
            hand(self?.texts(shape["output"]) ?? [])
        }
    }

    func save(_ n: Int, code: String, side: String) {
        var request: [String: Any] = ["do": "save", "n": n, "code": code]
        if !side.isEmpty { request["side_code"] = side }
        ask(request) { _ in }
    }

    func hint(_ n: Int, _ hand: @escaping (String, Standing) -> Void) {
        ask(["do": "hint", "n": n]) { [weak self] shape in
            guard let self = self else { return }
            hand(shape["hint"] as? String ?? "", self.standing(shape))
        }
    }

    func answer(_ n: Int, _ hand: @escaping ([String], Standing) -> Void) {
        ask(["do": "answer", "n": n]) { [weak self] shape in
            guard let self = self else { return }
            hand(self.texts(shape["answer"]), self.standing(shape))
        }
    }

    func forget(_ hand: @escaping (Standing) -> Void) {
        ask(["do": "forget"]) { [weak self] shape in
            guard let self = self else { return }
            hand(self.standing(shape))
        }
    }
}
