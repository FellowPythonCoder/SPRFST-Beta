import Foundation

public final class Parser {
    private var tokens: [Token]
    private var i = 0
    private let file: String
    public private(set) var diagnostics: [Diagnostic] = []

    public init(tokens: [Token], file: String) {
        self.tokens = tokens
        self.file = file
    }

    private var cur: Token { tokens[min(i, tokens.count - 1)] }
    private func check(_ k: TokenKind) -> Bool { cur.kind == k }
    private func checkKw(_ s: String) -> Bool {
        if case .kw(let w) = cur.kind, w == s { return true }
        return false
    }
    @discardableResult
    private func advance() -> Token {
        let t = cur
        if i < tokens.count - 1 { i += 1 }
        return t
    }
    private func match(_ k: TokenKind) -> Bool {
        if check(k) { _ = advance(); return true }
        return false
    }
    private func matchKw(_ s: String) -> Bool {
        if checkKw(s) { _ = advance(); return true }
        return false
    }
    private func expect(_ k: TokenKind, _ msg: String) throws -> Token {
        if check(k) { return advance() }
        throw err(msg)
    }
    private func expectKw(_ s: String) throws {
        if !matchKw(s) { throw err("expected '\(s)'") }
    }
    private func err(_ msg: String) -> ParseError {
        ParseError(diagnostic: Diagnostic(.error, cur.pos, msg))
    }

    public func parseProgram() throws -> Program {
        var uses: [UseDecl] = []
        var keeps: [(String, TypeExpr?, Expr, SourcePos)] = []
        var fns: [FnDecl] = []
        var forms: [FormDecl] = []
        var kinds: [KindDecl] = []
        var pacts: [PactDecl] = []
        var objs: [ObjDecl] = []
        var tests: [FnDecl] = []
        while !check(.eof) {
            let isPub = matchKw("pub")
            if matchKw("use") {
                var path = try expectIdent()
                while match(.dot) { path += "." + (try expectIdent()) }
                uses.append(UseDecl(path: path, pos: cur.pos))
            } else if matchKw("keep") {
                let n = try expectIdent()
                var ty: TypeExpr?
                if match(.colon) { ty = try parseType() }
                try expectAssign()
                let e = try parseExpr()
                keeps.append((n, ty, e, cur.pos))
            } else if checkKw("async") || checkKw("fn") || checkKw("test") {
                let fn = try parseFn()
                var f = fn
                f.isPub = isPub
                if f.isTest { tests.append(f) } else { fns.append(f) }
            } else if matchKw("form") {
                forms.append(try parseForm())
            } else if matchKw("kind") {
                kinds.append(try parseKind())
            } else if matchKw("pact") {
                pacts.append(try parsePact())
            } else if matchKw("obj") {
                objs.append(try parseObj())
            } else if matchKw("type") || matchKw("alias") {
                _ = try expectIdent()
                try expectAssign()
                _ = try parseType()
            } else {
                throw err("unexpected token '\(cur.lexeme)' at top level")
            }
        }
        return Program(file: file, uses: uses, keeps: keeps, fns: fns, forms: forms, kinds: kinds, pacts: pacts, objs: objs, tests: tests)
    }

    private func expectIdent() throws -> String {
        if cur.kind == .ident { return advance().lexeme }
        if case .kw(let w) = cur.kind, w == "self" { _ = advance(); return "self" }
        throw err("expected name")
    }

    private func expectAssign() throws {
        if !match(.assign) { throw err("expected '='") }
    }

    private func parseType() throws -> TypeExpr {
        let name = try expectIdent()
        var args: [TypeExpr] = []
        if match(.lt) {
            repeat { args.append(try parseType()) } while match(.comma)
            _ = match(.gt)
        }
        return TypeExpr(name, args)
    }

    private func parseFn() throws -> FnDecl {
        let pos = cur.pos
        let isAsync = matchKw("async")
        let isTest = matchKw("test")
        if !isTest { try expectKw("fn") }
        else if checkKw("fn") { _ = advance() }
        let name = try expectIdent()
        try expect(.lParen, "expected '('")
        var params: [Param] = []
        if !check(.rParen) {
            repeat {
                let pn = try expectIdent()
                var pt: TypeExpr?
                if match(.colon) { pt = try parseType() }
                params.append(Param(name: pn, type: pt, pos: cur.pos))
            } while match(.comma)
        }
        try expect(.rParen, "expected ')'")
        var ret: TypeExpr?
        if match(.arrow) { ret = try parseType() }
        let body = try parseBlock()
        return FnDecl(name: name, params: params, ret: ret, body: body, isTest: isTest, isPub: false, isAsync: isAsync, pos: pos)
    }

    private func parseForm() throws -> FormDecl {
        let pos = cur.pos
        let name = try expectIdent()
        try expect(.lBrace, "expected '{'")
        var fields: [FieldDecl] = []
        var methods: [FnDecl] = []
        while !check(.rBrace) && !check(.eof) {
            if checkKw("fn") || checkKw("async") {
                methods.append(try parseFn())
            } else {
                let fn = try expectIdent()
                try expect(.colon, "expected ':'")
                let ty = try parseType()
                _ = match(.comma)
                fields.append(FieldDecl(name: fn, type: ty, pos: cur.pos))
            }
        }
        try expect(.rBrace, "expected '}'")
        return FormDecl(name: name, fields: fields, methods: methods, pos: pos)
    }

    private func parseKind() throws -> KindDecl {
        let pos = cur.pos
        let name = try expectIdent()
        try expect(.lBrace, "expected '{'")
        var vars: [KindVariant] = []
        while !check(.rBrace) && !check(.eof) {
            let vn = try expectIdent()
            var assoc: [TypeExpr] = []
            if match(.lParen) {
                if !check(.rParen) {
                    repeat { assoc.append(try parseType()) } while match(.comma)
                }
                try expect(.rParen, "expected ')'")
            }
            _ = match(.comma)
            vars.append(KindVariant(name: vn, assoc: assoc, pos: cur.pos))
        }
        try expect(.rBrace, "expected '}'")
        return KindDecl(name: name, variants: vars, pos: pos)
    }

    private func parsePact() throws -> PactDecl {
        let pos = cur.pos
        let name = try expectIdent()
        try expect(.lBrace, "expected '{'")
        var methods: [(String, [Param], TypeExpr?)] = []
        while !check(.rBrace) && !check(.eof) {
            try expectKw("fn")
            let mn = try expectIdent()
            try expect(.lParen, "expected '('")
            var params: [Param] = []
            if !check(.rParen) {
                repeat {
                    let pn = try expectIdent()
                    var pt: TypeExpr?
                    if match(.colon) { pt = try parseType() }
                    params.append(Param(name: pn, type: pt, pos: cur.pos))
                } while match(.comma)
            }
            try expect(.rParen, "expected ')'")
            var ret: TypeExpr?
            if match(.arrow) { ret = try parseType() }
            methods.append((mn, params, ret))
        }
        try expect(.rBrace, "expected '}'")
        return PactDecl(name: name, methods: methods, pos: pos)
    }

    private func parseObj() throws -> ObjDecl {
        let pos = cur.pos
        let name = try expectIdent()
        var pacts: [String] = []
        if match(.colon) {
            repeat { pacts.append(try expectIdent()) } while match(.comma)
        }
        try expect(.lBrace, "expected '{'")
        var fields: [FieldDecl] = []
        var methods: [FnDecl] = []
        while !check(.rBrace) && !check(.eof) {
            if checkKw("fn") || checkKw("async") {
                methods.append(try parseFn())
            } else if matchKw("hold") || matchKw("keep") {
                let fn = try expectIdent()
                try expect(.colon, "expected ':'")
                let ty = try parseType()
                if match(.assign) { _ = try parseExpr() }
                fields.append(FieldDecl(name: fn, type: ty, pos: cur.pos))
            } else {
                let fn = try expectIdent()
                try expect(.colon, "expected ':'")
                let ty = try parseType()
                _ = match(.comma)
                fields.append(FieldDecl(name: fn, type: ty, pos: cur.pos))
            }
        }
        try expect(.rBrace, "expected '}'")
        return ObjDecl(name: name, pacts: pacts, fields: fields, methods: methods, pos: pos)
    }

    private func parseBlock() throws -> [Stmt] {
        try expect(.lBrace, "expected '{'")
        var stmts: [Stmt] = []
        while !check(.rBrace) && !check(.eof) {
            stmts.append(try parseStmt())
        }
        try expect(.rBrace, "expected '}'")
        return stmts
    }

    private func parseStmt() throws -> Stmt {
        let pos = cur.pos
        if matchKw("hold") {
            let n = try expectIdent()
            var ty: TypeExpr?
            if match(.colon) { ty = try parseType() }
            try expectAssign()
            return .hold(n, ty, try parseExpr(), pos)
        }
        if matchKw("keep") {
            let n = try expectIdent()
            var ty: TypeExpr?
            if match(.colon) { ty = try parseType() }
            try expectAssign()
            return .keep(n, ty, try parseExpr(), pos)
        }
        if matchKw("when") {
            let c = try parseExpr()
            let body = try parseBlock()
            var orws: [(Expr, [Stmt])] = []
            while matchKw("orwhen") {
                let oc = try parseExpr()
                orws.append((oc, try parseBlock()))
            }
            var el: [Stmt]?
            if matchKw("else") { el = try parseBlock() }
            return .when(c, body, orws, el, pos)
        }
        if matchKw("each") {
            let n = try expectIdent()
            try expectKw("in")
            let e = try parseExpr()
            return .each(n, e, try parseBlock(), pos)
        }
        if matchKw("while") {
            return .loopWhile(try parseExpr(), try parseBlock(), pos)
        }
        if matchKw("match") {
            let e = try parseExpr()
            try expect(.lBrace, "expected '{'")
            var arms: [(String, [String], [Stmt])] = []
            while !check(.rBrace) && !check(.eof) {
                var label = "_"
                if cur.kind == .ident || checkKw("_") == false {
                    if cur.kind == .ident {
                        let a = advance().lexeme
                        if match(.dot) {
                            label = a + "." + (try expectIdent())
                        } else {
                            label = a
                        }
                    } else if cur.lexeme == "_" {
                        _ = advance()
                        label = "_"
                    }
                }
                var binds: [String] = []
                if match(.lParen) {
                    if !check(.rParen) {
                        repeat { binds.append(try expectIdent()) } while match(.comma)
                    }
                    try expect(.rParen, "expected ')'")
                }
                _ = match(.fatArrow) || match(.arrow)
                let body: [Stmt]
                if check(.lBrace) { body = try parseBlock() }
                else { body = [.expr(try parseExpr())] }
                _ = match(.comma)
                arms.append((label, binds, body))
            }
            try expect(.rBrace, "expected '}'")
            return .match(e, arms, pos)
        }
        if matchKw("give") || matchKw("return") {
            if check(.rBrace) { return .give(nil, pos) }
            return .give(try parseExpr(), pos)
        }
        if matchKw("rise") { return .rise(try parseExpr(), pos) }
        if matchKw("rescue") {
            let body = try parseBlock()
            let n = matchKw("with") ? (try expectIdent()) : "err"
            return .rescue(body, n, try parseBlock(), pos)
        }
        if matchKw("spawn") { return .spawn(try parseBlock(), pos) }
        if matchKw("break") { return .breakS(pos) }
        if matchKw("continue") { return .continueS(pos) }
        if matchKw("show") {
            try expect(.lParen, "expected '('")
            var args: [Expr] = []
            if !check(.rParen) {
                repeat { args.append(try parseExpr()) } while match(.comma)
            }
            try expect(.rParen, "expected ')'")
            return .show(args, pos)
        }
        let e = try parseExpr()
        if match(.assign) {
            return .assign(e, try parseExpr(), pos)
        }
        return .expr(e)
    }

    private func parseExpr() throws -> Expr { try parseOr() }

    private func parseOr() throws -> Expr {
        var e = try parseAnd()
        while matchKw("or") || match(.orOr) {
            let r = try parseAnd()
            e = .binary("or", e, r, e.pos)
        }
        return e
    }
    private func parseAnd() throws -> Expr {
        var e = try parseEq()
        while matchKw("and") || match(.andAnd) {
            let r = try parseEq()
            e = .binary("and", e, r, e.pos)
        }
        return e
    }
    private func parseEq() throws -> Expr {
        var e = try parseCmp()
        while true {
            if match(.eqeq) { e = .binary("==", e, try parseCmp(), e.pos) }
            else if match(.neq) { e = .binary("!=", e, try parseCmp(), e.pos) }
            else { break }
        }
        return e
    }
    private func parseCmp() throws -> Expr {
        var e = try parseRange()
        while true {
            if match(.lt) { e = .binary("<", e, try parseRange(), e.pos) }
            else if match(.gt) { e = .binary(">", e, try parseRange(), e.pos) }
            else if match(.lte) { e = .binary("<=", e, try parseRange(), e.pos) }
            else if match(.gte) { e = .binary(">=", e, try parseRange(), e.pos) }
            else { break }
        }
        return e
    }
    private func parseRange() throws -> Expr {
        var e = try parseAdd()
        if match(.range) { e = .range(e, try parseAdd(), false, e.pos) }
        else if match(.rangeInc) { e = .range(e, try parseAdd(), true, e.pos) }
        return e
    }
    private func parseAdd() throws -> Expr {
        var e = try parseMul()
        while true {
            if match(.plus) { e = .binary("+", e, try parseMul(), e.pos) }
            else if match(.minus) { e = .binary("-", e, try parseMul(), e.pos) }
            else { break }
        }
        return e
    }
    private func parseMul() throws -> Expr {
        var e = try parseUnary()
        while true {
            if match(.star) { e = .binary("*", e, try parseUnary(), e.pos) }
            else if match(.slash) { e = .binary("/", e, try parseUnary(), e.pos) }
            else if match(.percent) { e = .binary("%", e, try parseUnary(), e.pos) }
            else { break }
        }
        return e
    }
    private func parseUnary() throws -> Expr {
        if matchKw("not") || match(.not) { return .unary("!", try parseUnary(), cur.pos) }
        if match(.minus) { return .unary("-", try parseUnary(), cur.pos) }
        return try parsePost()
    }
    private func parsePost() throws -> Expr {
        var e = try parsePrimary()
        while true {
            if match(.lParen) {
                var args: [Expr] = []
                if !check(.rParen) {
                    repeat { args.append(try parseExpr()) } while match(.comma)
                }
                try expect(.rParen, "expected ')'")
                e = .call(e, args, e.pos)
            } else if match(.lBrack) {
                let ix = try parseExpr()
                try expect(.rBrack, "expected ']'")
                e = .index(e, ix, e.pos)
            } else if match(.dot) {
                let n = try expectIdent()
                e = .member(e, n, e.pos)
            } else { break }
        }
        return e
    }
    private func parsePrimary() throws -> Expr {
        let pos = cur.pos
        if matchKw("true") { return .bool(true, pos) }
        if matchKw("false") { return .bool(false, pos) }
        if matchKw("none") { return .none(pos) }
        if cur.kind == .int {
            let t = advance()
            return .int(Int64(t.lexeme) ?? 0, pos)
        }
        if cur.kind == .num {
            let t = advance()
            return .num(Double(t.lexeme) ?? 0, pos)
        }
        if cur.kind == .text {
            return .text(advance().lexeme, pos)
        }
        if match(.lBrack) {
            var xs: [Expr] = []
            if !check(.rBrack) {
                repeat { xs.append(try parseExpr()) } while match(.comma)
            }
            try expect(.rBrack, "expected ']'")
            return .list(xs, pos)
        }
        if match(.hash) {
            try expect(.lBrace, "expected '{'")
            var pairs: [(Expr, Expr)] = []
            while !check(.rBrace) && !check(.eof) {
                let k = try parseExpr()
                try expect(.colon, "expected ':'")
                let v = try parseExpr()
                pairs.append((k, v))
                _ = match(.comma)
            }
            try expect(.rBrace, "expected '}'")
            return .map(pairs, pos)
        }
        if match(.lParen) {
            let e = try parseExpr()
            try expect(.rParen, "expected ')'")
            return e
        }
        if cur.kind == .ident {
            let name = advance().lexeme
            if check(.lBrace) && looksLikeConstruct() {
                _ = advance()
                var fields: [(String, Expr)] = []
                while !check(.rBrace) && !check(.eof) {
                    let fn = try expectIdent()
                    try expect(.colon, "expected ':'")
                    fields.append((fn, try parseExpr()))
                    _ = match(.comma)
                }
                try expect(.rBrace, "expected '}'")
                return .construct(name, fields, pos)
            }
            return .ident(name, pos)
        }
        if match(.orOr) {
            // empty closure params ||
            let body = try parseExpr()
            return .closure([], body, pos)
        }
        throw err("expected expression")
    }

    private func looksLikeConstruct() -> Bool {
        // `{ ident :` after a type name
        guard i + 1 < tokens.count else { return false }
        let a = tokens[i]     // {
        let b = tokens[min(i + 1, tokens.count - 1)]
        let c = tokens[min(i + 2, tokens.count - 1)]
        return a.kind == .lBrace && b.kind == .ident && c.kind == .colon
    }
}

public enum FrontEnd {
    public static func parse(source: String, file: String) throws -> Program {
        let tokens = Lexer.tokenize(source, file: file)
        return try Parser(tokens: tokens, file: file).parseProgram()
    }
}
