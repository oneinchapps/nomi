import SwiftUI

// Maße für große Bildschirme (iPad). Auf dem iPhone greifen sie nicht, weil der Platz nie reicht.
// Absichtlich kein eigener Typ „Layout“: der würde SwiftUIs Layout-Protokoll überdecken.
extension Metrics {
    /// Breite der Lesespalte: Text und Formulare werden nicht breiter als das
    static let readableWidth: CGFloat = 680
    /// Ab dieser Breite gibt es eigene Layouts (Raster, zwei Spalten, Wochen-Board)
    static let wideWidth: CGFloat = 900
    /// Woche als Board mit sieben Spalten erst im Querformat; hochkant wären die Spalten zu schmal
    static let boardWidth: CGFloat = 1100
}

extension View {
    /// Inhalt mittig, höchstens `Metrics.readableWidth` breit. Auf dem iPhone ohne Wirkung.
    func readableColumn(_ width: CGFloat = Metrics.readableWidth) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }

    /// Meldet die verfügbare Breite, z. B. um ab `Metrics.wideWidth` auf zwei Spalten zu wechseln.
    /// Breite statt Size-Class: Im Split View ist ein iPad auch mal so schmal wie ein iPhone.
    func trackWidth(_ width: Binding<CGFloat>) -> some View {
        onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width.wrappedValue = $0 }
    }
}
