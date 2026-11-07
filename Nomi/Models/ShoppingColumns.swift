import Foundation

/// Abteilungen auf Spalten verteilen (iPad): Reihenfolge bleibt der Weg durch den Laden – von oben nach
/// unten, dann in die nächste Spalte –, die Spalten werden dabei etwa gleich lang.
enum ShoppingColumns {
    /// `sizes` = Höhe jeder Abteilung (Einträge + Überschrift). Liefert pro Spalte die Indizes der Abteilungen.
    static func split(_ sizes: [Int], into columns: Int) -> [[Int]] {
        guard columns > 1, !sizes.isEmpty else { return [Array(sizes.indices)] }
        let total = sizes.reduce(0, +)
        var result: [[Int]] = [[]]
        var filled = 0
        for (index, size) in sizes.enumerated() {
            let column = result.count - 1
            // Ziel bis zum Ende dieser Spalte; überschritten → neue Spalte, solange noch welche frei sind
            let target = Double(total) * Double(column + 1) / Double(columns)
            let wouldBe = Double(filled + size)
            if !result[column].isEmpty, result.count < columns, wouldBe - target > target - Double(filled) {
                result.append([])
            }
            result[result.count - 1].append(index)
            filled += size
        }
        return result
    }
}
