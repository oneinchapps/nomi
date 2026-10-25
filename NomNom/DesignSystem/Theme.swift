import SwiftUI
import UIKit

// MARK: - Colors

extension Color {
    /// Markenfarbe „Himbeere“: hinterlegt den Kopfbereich jedes Screens.
    static let brand = Color(light: 0xCC335E, dark: 0xB8284F)
    /// Schrift und Symbole auf der Markenfarbe (Kontrast ≥ 5:1).
    static let onBrand = Color(light: 0xFFFFFF, dark: 0xFFFFFF)

    /// Warmer Papierton, Grundfläche aller Screens.
    static let canvas = Color(light: 0xF7F4EE, dark: 0x161816)
    /// Karten und erhöhte Flächen.
    static let surface = Color(light: 0xFCFAF6, dark: 0x1F2220)
    /// Kühles Blaugrau hinter Bildern und Headern.
    static let mist = Color(light: 0xDCE6EA, dark: 0x1D282C)
    /// Text und primäre Aktionen.
    static let ink = Color(light: 0x262B28, dark: 0xF3EFE7)
    static let inkMuted = Color(light: 0x6E726F, dark: 0xA3A69F)
    static let hairline = Color(light: 0xE6E1D8, dark: 0x2E322F)
    /// Akzent für „Nein“-Swipes und Warnungen.
    static let tomato = Color(light: 0xD9573B, dark: 0xE8704F)
    /// Akzent für „Ja“-Swipes und Matches.
    static let sage = Color(light: 0x6F8F6A, dark: 0x8FB089)

    /// `nonisolated` + `@Sendable`: SwiftUI löst dynamische Farben auch auf seinem Render-Thread auf.
    /// Mit MainActor-Isolation würde die Laufzeitprüfung dort die App beenden.
    nonisolated init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { @Sendable traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    nonisolated convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Typography

extension Font {
    /// Überschriften in Bricolage Grotesque. Ab 32 pt die Display-Variante (96-pt-Optik, ExtraBold),
    /// darunter die Text-Variante (24-pt-Optik), die bei kleinen Größen besser lesbar ist.
    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle, weight: HeadingWeight = .bold) -> Font {
        let name = size >= 32 ? "BricolageGrotesque96pt-ExtraBold" : weight.postScriptName
        return .custom(name, size: size, relativeTo: style)
    }

    enum HeadingWeight {
        case semibold, bold
        var postScriptName: String {
            switch self {
            case .semibold: "BricolageGrotesque24pt-SemiBold"
            case .bold: "BricolageGrotesque24pt-Bold"
            }
        }
    }

    /// Große Headline, z. B. auf dem Willkommensscreen.
    static let display = heading(42, relativeTo: .largeTitle)
    static let titleHeading = heading(30, relativeTo: .title)
    static let cardTitle = heading(23, relativeTo: .title3)
    static let logo = Font.custom("BricolageGrotesque96pt-ExtraBold", size: 28, relativeTo: .title2)

    static let bodySans = Font.custom("DMSans-Regular", size: 17, relativeTo: .body)
    static let bodySansMedium = Font.custom("DMSans-Medium", size: 17, relativeTo: .body)
    static let buttonSans = Font.custom("DMSans-SemiBold", size: 17, relativeTo: .body)
    static let captionSans = Font.custom("DMSans-Regular", size: 14, relativeTo: .footnote)

    /// Kleine Großbuchstaben-Zeilen wie „25 MIN · FÜR ZWEI“.
    static let meta = Font.custom("DMMono-Regular", size: 11, relativeTo: .caption2)
    static let eyebrow = Font.custom("DMMono-Regular", size: 15, relativeTo: .subheadline)
}

// MARK: - Metrics

enum Metrics {
    static let gutter: CGFloat = 24
    static let cardRadius: CGFloat = 22
    static let buttonRadius: CGFloat = 18
}
