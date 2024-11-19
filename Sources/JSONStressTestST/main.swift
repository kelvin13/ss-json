import Foundation
import JSON
import Testing

@Suite
enum Main
{
    @Test
    static func main() throws
    {
        let file:Data = try Data.init(
            contentsOf: URL.init(fileURLWithPath: "Test Inputs/Swift.symbols.json"))

        let json:JSON = JSON.init(utf8: [UInt8].init(file)[...])
        let object:JSON.Object = try .init(parsing: json)

        print(object.fields.map(\.0))
    }
}
