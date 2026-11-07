import Testing
@testable import nomi

struct ShoppingColumnsTests {
    @Test func behaeltReihenfolgeUndGleichtAus() {
        let columns = ShoppingColumns.split([5, 3, 4, 3, 3], into: 3)
        #expect(columns.flatMap { $0 } == [0, 1, 2, 3, 4])
        #expect(columns.count == 3)
        let heights = columns.map { $0.map { [5, 3, 4, 3, 3][$0] }.reduce(0, +) }
        #expect(heights.max()! - heights.min()! <= 3)
    }

    @Test func wenigeAbteilungenFuellenNichtAlleSpalten() {
        #expect(ShoppingColumns.split([4], into: 3) == [[0]])
        #expect(ShoppingColumns.split([2, 2], into: 3) == [[0], [1]])
    }

    @Test func eineSpalteOderLeer() {
        #expect(ShoppingColumns.split([1, 2, 3], into: 1) == [[0, 1, 2]])
        #expect(ShoppingColumns.split([], into: 3) == [[]])
    }
}
