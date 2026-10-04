import Foundation

public struct OptimizeResult {
    public var folded: Int
    public var program: Program
}

public enum Optimizer {
    public static func optimize(_ program: Program) -> OptimizeResult {
        var folded = 0
        func fold(_ e: Expr) -> Expr {
            switch e {
            case .binary(let op, let l, let r, let p):
                let L = fold(l), R = fold(r)
                if case .int(let a, _) = L, case .int(let b, _) = R {
                    folded += 1
                    switch op {
                    case "+": return .int(a &+ b, p)
                    case "-": return .int(a &- b, p)
                    case "*": return .int(a &* b, p)
                    case "/": return .int(b == 0 ? 0 : a / b, p)
                    case "%": return .int(b == 0 ? 0 : a % b, p)
                    case "==": return .bool(a == b, p)
                    case "!=": return .bool(a != b, p)
                    case "<": return .bool(a < b, p)
                    case ">": return .bool(a > b, p)
                    case "<=": return .bool(a <= b, p)
                    case ">=": return .bool(a >= b, p)
                    default: break
                    }
                }
                return .binary(op, L, R, p)
            case .unary(let op, let x, let p):
                let X = fold(x)
                if op == "-", case .int(let v, _) = X { folded += 1; return .int(-v, p) }
                return .unary(op, X, p)
            case .call(let c, let args, let p):
                return .call(fold(c), args.map(fold), p)
            case .list(let xs, let p): return .list(xs.map(fold), p)
            default: return e
            }
        }
        func foldStmt(_ s: Stmt) -> Stmt {
            switch s {
            case .hold(let n, let t, let e, let p): return .hold(n, t, fold(e), p)
            case .keep(let n, let t, let e, let p): return .keep(n, t, fold(e), p)
            case .assign(let t, let e, let p): return .assign(fold(t), fold(e), p)
            case .expr(let e): return .expr(fold(e))
            case .give(let e, let p): return .give(e.map(fold), p)
            case .show(let a, let p): return .show(a.map(fold), p)
            default: return s
            }
        }
        var p = program
        p.fns = p.fns.map { fn in
            var f = fn
            f.body = f.body.map(foldStmt)
            return f
        }
        return OptimizeResult(folded: folded, program: p)
    }
}

public struct IRModule {
    public var name: String
    public var functions: [String]
    public var forms: [String]
}

public enum IRLower {
    public static func lower(_ program: Program) -> IRModule {
        IRModule(
            name: program.file,
            functions: program.fns.map(\.name),
            forms: program.forms.map(\.name)
        )
    }
}
