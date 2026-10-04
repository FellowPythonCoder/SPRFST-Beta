import Foundation

public struct SourcePos: Equatable, Sendable {
    public var file: String
    public var line: Int
    public var column: Int
    public init(file: String, line: Int, column: Int) {
        self.file = file
        self.line = line
        self.column = column
    }
}

public struct Diagnostic: Equatable, Sendable {
    public enum Severity: String, Sendable { case note, warning, error }
    public var severity: Severity
    public var pos: SourcePos
    public var message: String
    public var hint: String?
    public init(_ severity: Severity, _ pos: SourcePos, _ message: String, hint: String? = nil) {
        self.severity = severity
        self.pos = pos
        self.message = message
        self.hint = hint
    }

    public func formatted(source: String? = nil) -> String {
        var out = "\(pos.file):\(pos.line):\(pos.column): \(severity.rawValue): \(message)\n"
        if let source {
            let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
            if pos.line > 0 && pos.line <= lines.count {
                let text = String(lines[pos.line - 1])
                out += "  \(text)\n"
                out += "  " + String(repeating: " ", count: max(0, pos.column - 1)) + "^\n"
            }
        }
        if let hint { out += "  hint: \(hint)\n" }
        return out
    }
}

public enum TokenKind: Equatable, Sendable {
    case ident, int, num, text
    case lParen, rParen, lBrace, rBrace, lBrack, rBrack
    case comma, colon, semicolon, dot, hash
    case plus, minus, star, slash, percent
    case eq, eqeq, neq, lt, gt, lte, gte
    case andAnd, orOr, not, assign
    case arrow, fatArrow, range, rangeInc
    case kw(String)
    case eof
}

public struct Token: Equatable, Sendable {
    public var kind: TokenKind
    public var lexeme: String
    public var pos: SourcePos
}

public enum Lexer {
    private static let keywords: Set<String> = [
        "fn", "give", "hold", "keep", "form", "obj", "pact", "kind",
        "when", "orwhen", "else", "each", "in", "while", "match",
        "use", "mod", "as", "spawn", "await", "async", "task", "chan",
        "unsafe", "test", "bench", "comptime", "show", "rise", "rescue",
        "own", "ref", "mut", "true", "false", "none", "and", "or", "not",
        "break", "continue", "self", "pub", "priv", "type", "alias",
        "impl", "where", "is", "defer", "from", "with", "return"
    ]

    public static func tokenize(_ source: String, file: String) -> [Token] {
        var tokens: [Token] = []
        let chars = Array(source)
        var i = 0
        var line = 1
        var col = 1

        func peek(_ n: Int = 0) -> Character? {
            let j = i + n
            return j < chars.count ? chars[j] : nil
        }
        func adv() -> Character {
            let c = chars[i]
            i += 1
            if c == "\n" { line += 1; col = 1 } else { col += 1 }
            return c
        }
        func add(_ kind: TokenKind, _ lex: String, _ p: SourcePos) {
            tokens.append(Token(kind: kind, lexeme: lex, pos: p))
        }

        while i < chars.count {
            let p = SourcePos(file: file, line: line, column: col)
            let c = peek()!
            if c == " " || c == "\t" || c == "\r" { _ = adv(); continue }
            if c == "\n" { _ = adv(); continue }
            if c == "/" && peek(1) == "/" {
                while peek() != nil && peek() != "\n" { _ = adv() }
                continue
            }
            if c == "/" && peek(1) == "*" {
                _ = adv(); _ = adv()
                while peek() != nil && !(peek() == "*" && peek(1) == "/") { _ = adv() }
                if peek() != nil { _ = adv(); _ = adv() }
                continue
            }
            if c == "\"" {
                _ = adv()
                var s = ""
                while let ch = peek(), ch != "\"" {
                    if ch == "\\" {
                        _ = adv()
                        let e = peek() ?? " "
                        _ = adv()
                        switch e {
                        case "n": s.append("\n")
                        case "t": s.append("\t")
                        case "r": s.append("\r")
                        case "\"": s.append("\"")
                        case "\\": s.append("\\")
                        default: s.append(e)
                        }
                    } else {
                        s.append(adv())
                    }
                }
                if peek() == "\"" { _ = adv() }
                add(.text, s, p)
                continue
            }
            if c.isLetter || c == "_" {
                var s = ""
                while let ch = peek(), ch.isLetter || ch.isNumber || ch == "_" { s.append(adv()) }
                if Self.keywords.contains(s) {
                    add(.kw(s), s, p)
                } else {
                    add(.ident, s, p)
                }
                continue
            }
            if c.isNumber {
                var s = ""
                var isNum = false
                while let ch = peek(), ch.isNumber { s.append(adv()) }
                if peek() == "." && peek(1)?.isNumber == true {
                    isNum = true
                    s.append(adv())
                    while let ch = peek(), ch.isNumber { s.append(adv()) }
                }
                add(isNum ? .num : .int, s, p)
                continue
            }
            let two = String([c, peek(1) ?? " "])
            switch two {
            case "==": _ = adv(); _ = adv(); add(.eqeq, two, p); continue
            case "!=": _ = adv(); _ = adv(); add(.neq, two, p); continue
            case "<=": _ = adv(); _ = adv(); add(.lte, two, p); continue
            case ">=": _ = adv(); _ = adv(); add(.gte, two, p); continue
            case "->": _ = adv(); _ = adv(); add(.arrow, two, p); continue
            case "=>": _ = adv(); _ = adv(); add(.fatArrow, two, p); continue
            case "..":
                _ = adv(); _ = adv()
                if peek() == "." { _ = adv(); add(.rangeInc, "...", p) }
                else { add(.range, "..", p) }
                continue
            case "&&": _ = adv(); _ = adv(); add(.andAnd, two, p); continue
            case "||": _ = adv(); _ = adv(); add(.orOr, two, p); continue
            default: break
            }
            _ = adv()
            switch c {
            case "(": add(.lParen, "(", p)
            case ")": add(.rParen, ")", p)
            case "{": add(.lBrace, "{", p)
            case "}": add(.rBrace, "}", p)
            case "[": add(.lBrack, "[", p)
            case "]": add(.rBrack, "]", p)
            case ",": add(.comma, ",", p)
            case ":": add(.colon, ":", p)
            case ";": add(.semicolon, ";", p)
            case ".": add(.dot, ".", p)
            case "#": add(.hash, "#", p)
            case "+": add(.plus, "+", p)
            case "-": add(.minus, "-", p)
            case "*": add(.star, "*", p)
            case "/": add(.slash, "/", p)
            case "%": add(.percent, "%", p)
            case "=": add(.assign, "=", p)
            case "<": add(.lt, "<", p)
            case ">": add(.gt, ">", p)
            case "!": add(.not, "!", p)
            default:
                add(.ident, String(c), p)
            }
        }
        tokens.append(Token(kind: .eof, lexeme: "", pos: SourcePos(file: file, line: line, column: col)))
        return tokens
    }
}
