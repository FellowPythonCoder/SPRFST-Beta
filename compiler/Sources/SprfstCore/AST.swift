import Foundation

public struct TypeExpr: Sendable {
    public var name: String
    public var args: [TypeExpr]
    public init(_ name: String, _ args: [TypeExpr] = []) {
        self.name = name
        self.args = args
    }
    public var description: String {
        if args.isEmpty { return name }
        return "\(name)<\(args.map(\.description).joined(separator: ", "))>"
    }
}

public struct Param: Sendable {
    public var name: String
    public var type: TypeExpr?
    public var pos: SourcePos
}

public indirect enum Expr: Sendable {
    case int(Int64, SourcePos)
    case num(Double, SourcePos)
    case text(String, SourcePos)
    case bool(Bool, SourcePos)
    case none(SourcePos)
    case ident(String, SourcePos)
    case binary(String, Expr, Expr, SourcePos)
    case unary(String, Expr, SourcePos)
    case call(Expr, [Expr], SourcePos)
    case index(Expr, Expr, SourcePos)
    case member(Expr, String, SourcePos)
    case list([Expr], SourcePos)
    case map([(Expr, Expr)], SourcePos)
    case construct(String, [(String, Expr)], SourcePos)
    case closure([Param], Expr, SourcePos)
    case range(Expr, Expr, Bool, SourcePos)

    public var pos: SourcePos {
        switch self {
        case .int(_, let p), .num(_, let p), .text(_, let p), .bool(_, let p), .none(let p),
             .ident(_, let p), .binary(_, _, _, let p), .unary(_, _, let p), .call(_, _, let p),
             .index(_, _, let p), .member(_, _, let p), .list(_, let p), .map(_, let p),
             .construct(_, _, let p), .closure(_, _, let p), .range(_, _, _, let p):
            return p
        }
    }
}

public indirect enum Stmt: Sendable {
    case hold(String, TypeExpr?, Expr, SourcePos)
    case keep(String, TypeExpr?, Expr, SourcePos)
    case assign(Expr, Expr, SourcePos)
    case expr(Expr)
    case when(Expr, [Stmt], [(Expr, [Stmt])], [Stmt]?, SourcePos)
    case each(String, Expr, [Stmt], SourcePos)
    case loopWhile(Expr, [Stmt], SourcePos)
    case match(Expr, [(String, [String], [Stmt])], SourcePos)
    case give(Expr?, SourcePos)
    case rise(Expr, SourcePos)
    case rescue([Stmt], String, [Stmt], SourcePos)
    case spawn([Stmt], SourcePos)
    case breakS(SourcePos)
    case continueS(SourcePos)
    case show([Expr], SourcePos)
}

public struct FnDecl: Sendable {
    public var name: String
    public var params: [Param]
    public var ret: TypeExpr?
    public var body: [Stmt]
    public var isTest: Bool
    public var isPub: Bool
    public var isAsync: Bool
    public var pos: SourcePos
}

public struct FieldDecl: Sendable {
    public var name: String
    public var type: TypeExpr
    public var pos: SourcePos
}

public struct FormDecl: Sendable {
    public var name: String
    public var fields: [FieldDecl]
    public var methods: [FnDecl]
    public var pos: SourcePos
}

public struct KindVariant: Sendable {
    public var name: String
    public var assoc: [TypeExpr]
    public var pos: SourcePos
}

public struct KindDecl: Sendable {
    public var name: String
    public var variants: [KindVariant]
    public var pos: SourcePos
}

public struct PactDecl: Sendable {
    public var name: String
    public var methods: [(String, [Param], TypeExpr?)]
    public var pos: SourcePos
}

public struct ObjDecl: Sendable {
    public var name: String
    public var pacts: [String]
    public var fields: [FieldDecl]
    public var methods: [FnDecl]
    public var pos: SourcePos
}

public struct UseDecl: Sendable {
    public var path: String
    public var pos: SourcePos
}

public struct Program: Sendable {
    public var file: String
    public var uses: [UseDecl]
    public var keeps: [(String, TypeExpr?, Expr, SourcePos)]
    public var fns: [FnDecl]
    public var forms: [FormDecl]
    public var kinds: [KindDecl]
    public var pacts: [PactDecl]
    public var objs: [ObjDecl]
    public var tests: [FnDecl]
}

public struct ParseError: Error, CustomStringConvertible {
    public var diagnostic: Diagnostic
    public var description: String { diagnostic.formatted() }
}
