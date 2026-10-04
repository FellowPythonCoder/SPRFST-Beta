import XCTest
import SprfstCore

final class SprfstCoreTests: XCTestCase {
    func testLexAndParseHello() throws {
        let src = """
        fn greet(name: Text) -> Text {
            give "Hello, " + name
        }
        fn main() {
            show(greet("SPRFST"))
        }
        """
        let p = try FrontEnd.parse(source: src, file: "t.spf")
        XCTAssertEqual(p.fns.count, 2)
        XCTAssertEqual(p.fns[0].name, "greet")
    }

    func testWhenEachForm() throws {
        let src = """
        form Point {
            x: Int
            y: Int
        }
        fn main() {
            hold p: Point = Point { x: 2, y: 3 }
            hold s: Int = 0
            each i in 0..4 {
                s = s + i
            }
            when s > 0 {
                show(s)
            } else {
                show(0)
            }
        }
        """
        let p = try FrontEnd.parse(source: src, file: "t.spf")
        XCTAssertEqual(p.forms.count, 1)
        let tc = TypeChecker()
        tc.check(p)
        XCTAssertFalse(tc.diagnostics.contains(where: { $0.severity == .error }))
    }
}
