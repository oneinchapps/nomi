// Rendert Entwürfe für bearbeitbare Zuordnungen von Artikeln zu Kategorien:
// im Live-Einkauf per Halten umsortieren (zwei Varianten) und die gemerkten Zuordnungen im Zahnrad.
// Aufruf: swift design/shopping/render-category-mapping.swift Nomi/Resources/Fonts design/fonts/DynaPuff.ttf design/shopping/zuordnungen.png
import AppKit
import CoreText
import SwiftUI

let args = CommandLine.arguments
for f in try! FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: args[1]), includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}
CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: args[2]) as CFURL, .process, nil)

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double(hex >> 16 & 255) / 255, green: Double(hex >> 8 & 255) / 255, blue: Double(hex & 255) / 255)
    }
    static let brand = Color(hex: 0xCC335E)
    static let canvas = Color(hex: 0xF7F4EE)
    static let ink = Color(hex: 0x262B28)
    static let inkMuted = Color(hex: 0x6E726F)
    static let hairline = Color(hex: 0xE2DDD3)
    static let mist = Color(hex: 0xDCE6EA)
    static let chip = Color(hex: 0xECE7DD)
    static let surface = Color(hex: 0xFFFDF9)
    static let ochre = Color(hex: 0xF2B33D)
    static let sage = Color(hex: 0x6F8F6A)
}

func sans(_ size: CGFloat, _ weight: String = "Regular") -> Font { .custom("DMSans-\(weight)", size: size) }
func mono(_ size: CGFloat) -> Font { .custom("DMMono-Regular", size: size) }
func heading(_ size: CGFloat) -> Font { .custom(size >= 32 ? "BricolageGrotesque96pt-ExtraBold" : "BricolageGrotesque24pt-Bold", size: size) }

struct Meta: View {
    let text: String
    var color = Color.inkMuted
    var body: some View { Text(text.uppercased()).font(mono(11)).tracking(1.4).foregroundStyle(color) }
}

// MARK: - Bausteine

struct Phone<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(width: 390, height: 800, alignment: .top)
            .background(Color.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 44, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 44, style: .continuous).stroke(Color.ink.opacity(0.85), lineWidth: 6))
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}

struct LiveTop: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(.white.opacity(0.18), in: .circle)
                Spacer()
                Meta(text: "2 von 9", color: .white)
                Image(systemName: "eye").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(.white.opacity(0.18), in: .circle)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Einkaufen").font(heading(22)).foregroundStyle(.white)
                Text("Rewe · Abteilung 1 von 4").font(sans(13)).foregroundStyle(.white.opacity(0.85))
            }
            Capsule().fill(.white.opacity(0.25)).frame(height: 6)
                .overlay(alignment: .leading) { Capsule().fill(.white).frame(width: 80, height: 6) }
        }
        .padding(.horizontal, 22).padding(.top, 58).padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }
}

struct BigRow: View {
    var name: String
    var amount = ""
    var pressed = false
    var body: some View {
        HStack(spacing: 16) {
            Circle().stroke(Color.inkMuted.opacity(0.45), lineWidth: 2.5).frame(width: 32, height: 32)
            Text(name).font(sans(20, "Medium")).foregroundStyle(Color.ink)
            Spacer()
            Text(amount).font(sans(17, "Medium")).foregroundStyle(Color.ink)
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
        .background(pressed ? Color.surface : .clear, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(pressed ? 0.12 : 0), radius: 14, y: 4)
        .scaleEffect(pressed ? 1.03 : 1)
        .overlay(alignment: .bottom) { if !pressed { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 60) } }
    }
}

struct AislePage: View {
    var withCheese = true
    var pressed = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Obst & Gemüse").font(heading(34)).foregroundStyle(Color.ink)
            Meta(text: withCheese ? "3 Dinge" : "2 Dinge").padding(.top, 6).padding(.bottom, 10)
            BigRow(name: "Bananen")
            if withCheese { BigRow(name: "Vesper Käse", amount: "200 g", pressed: pressed) }
            BigRow(name: "Zwiebeln", amount: "3")
        }
        .padding(.horizontal, 14).padding(.top, 22)
    }
}

let categories = ["Obst & Gemüse", "Backwaren", "Kühlregal", "Fleisch & Fisch", "Trockenwaren", "Konserven",
                  "Gewürze & Öle", "Tiefkühl", "Getränke", "Drogerie", "Sonstiges", "Bio-Ecke"]

// MARK: - Bildschirme

/// A: System-Dialog wie heute in der Liste
struct DialogA: View {
    var body: some View {
        Phone {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    LiveTop()
                    AislePage(pressed: false)
                    Spacer()
                }
                Color.black.opacity(0.3)
                VStack(spacing: 8) {
                    VStack(spacing: 0) {
                        Text("In welche Abteilung?").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.inkMuted)
                            .frame(maxWidth: .infinity, minHeight: 44)
                        ForEach(categories.dropFirst().prefix(8), id: \.self) { name in
                            Divider()
                            Text(name).font(.system(size: 19)).foregroundStyle(Color(hex: 0x0A84FF))
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        Divider()
                        Text("…").font(.system(size: 19)).foregroundStyle(Color.inkMuted).frame(maxWidth: .infinity, minHeight: 40)
                    }
                    .background(Color(hex: 0xF2F2F4), in: RoundedRectangle(cornerRadius: 14))
                    Text("Abbrechen").font(.system(size: 19, weight: .semibold)).foregroundStyle(Color(hex: 0x0A84FF))
                        .frame(maxWidth: .infinity, minHeight: 54).background(.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 10).padding(.bottom, 26)
            }
        }
    }
}

/// B: eigenes Blatt mit Kategorien als Chips
struct SheetB: View {
    var body: some View {
        Phone {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    LiveTop()
                    AislePage(pressed: true)
                    Spacer()
                }
                Color.black.opacity(0.25)
                VStack(alignment: .leading, spacing: 14) {
                    Capsule().fill(Color.hairline).frame(width: 40, height: 5).frame(maxWidth: .infinity).padding(.top, 8)
                    Meta(text: "Vesper Käse")
                    Text("In welche Abteilung?").font(heading(26)).foregroundStyle(Color.ink)
                    FlowChips(names: categories, current: "Obst & Gemüse", suggested: "Kühlregal")
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles").font(.system(size: 12)).foregroundStyle(Color.ochre)
                        Text("nomi merkt sich das für den nächsten Einkauf.").font(sans(13)).foregroundStyle(Color.inkMuted)
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 22).padding(.bottom, 40)
                .background(Color.canvas, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
            }
        }
    }
}

struct FlowChips: View {
    var names: [String]
    var current: String
    var suggested: String
    var body: some View {
        // Feste Zeilen, weil ImageRenderer kein Layout-Protokoll für Umbrüche braucht
        let rows: [[String]] = [Array(names[0..<3]), Array(names[3..<6]), Array(names[6..<9]), Array(names[9..<12])]
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { name in chip(name) }
                }
            }
        }
    }
    func chip(_ name: String) -> some View {
        let isCurrent = name == current
        let isSuggested = name == suggested
        return HStack(spacing: 5) {
            if isCurrent { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)) }
            Text(name)
        }
        .font(sans(14, isCurrent || isSuggested ? "SemiBold" : "Regular"))
        .padding(.horizontal, 12).padding(.vertical, 9)
        .foregroundStyle(isSuggested ? Color.canvas : Color.ink)
        .background(isSuggested ? Color.ink : (isCurrent ? Color.surface : Color.chip), in: .capsule)
        .overlay(Capsule().stroke(isCurrent ? Color.ink.opacity(0.4) : .clear, lineWidth: 1.5))
    }
}

/// Nach dem Umsortieren: Hinweis, wohin es ging
struct Moved: View {
    var body: some View {
        Phone {
            VStack(spacing: 0) {
                LiveTop()
                AislePage(withCheese: false)
                Spacer()
                HStack(spacing: 12) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.ochre)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vesper Käse → Kühlregal").font(sans(15, "SemiBold")).foregroundStyle(Color.canvas)
                        Text("Gemerkt für euren Haushalt").font(sans(13)).foregroundStyle(Color.canvas.opacity(0.7))
                    }
                    Spacer()
                    Text("Hinspringen").font(sans(14, "SemiBold")).foregroundStyle(Color.canvas)
                        .padding(.horizontal, 12).padding(.vertical, 7).background(Color.canvas.opacity(0.16), in: .capsule)
                }
                .padding(14)
                .background(Color.ink, in: RoundedRectangle(cornerRadius: 18))
                .padding(.horizontal, 16).padding(.bottom, 24)
                HStack {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.ink)
                        .frame(width: 54, height: 54).background(Color.mist, in: .circle).opacity(0)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<4) { i in Capsule().fill(i == 0 ? Color.brand : Color.hairline).frame(width: i == 0 ? 18 : 7, height: 7) }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 54, height: 54).background(Color.brand, in: .circle)
                }
                .padding(.horizontal, 24).padding(.bottom, 36)
            }
        }
    }
}

struct SheetHeader: View {
    var title: String
    var back: String?
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color.hairline).frame(width: 40, height: 5).padding(.top, 8)
            HStack {
                if let back {
                    HStack(spacing: 4) { Image(systemName: "chevron.left"); Text(back) }.font(sans(16)).foregroundStyle(Color.brand)
                } else {
                    Text("").frame(width: 60)
                }
                Spacer()
                Text(title).font(sans(17, "SemiBold")).foregroundStyle(Color.ink)
                Spacer()
                Text("Fertig").font(sans(16, "SemiBold")).foregroundStyle(Color.brand)
            }
            .padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 10)
        }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(spacing: 0) { content }.background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct CardRow: View {
    var icon: String?
    var title: String
    var detail = ""
    var last = false
    var tint = Color.ink
    var isNew = false
    var body: some View {
        HStack(spacing: 12) {
            if let icon { Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(tint).frame(width: 24) }
            Text(title).font(sans(16)).foregroundStyle(tint)
            if isNew {
                Text("NEU").font(mono(10)).tracking(1.2).foregroundStyle(Color.ink)
                    .padding(.horizontal, 7).padding(.vertical, 3).background(Color.ochre, in: .capsule)
            }
            Spacer()
            Text(detail).font(sans(14)).foregroundStyle(Color.inkMuted)
            if tint == Color.ink { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.hairline) }
        }
        .padding(.horizontal, 16).frame(minHeight: 50)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, icon == nil ? 16 : 52) } }
    }
}

struct SheetFrame<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        Phone {
            VStack(spacing: 0) {
                Color.ink.opacity(0.35).frame(height: 44)
                VStack(alignment: .leading, spacing: 10) { content }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(Color.canvas, in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
            }
            .background(Color.ink.opacity(0.35))
        }
    }
}

struct Settings: View {
    var body: some View {
        SheetFrame {
            SheetHeader(title: "Einkaufen")
            Meta(text: "Supermärkte").padding(.horizontal, 36).padding(.top, 6)
            Card {
                CardRow(icon: "storefront", title: "Rewe", detail: "aktiv")
                CardRow(icon: "plus", title: "Supermarkt hinzufügen", last: true, tint: .brand)
            }
            .padding(.horizontal, 20)
            Meta(text: "Kategorien").padding(.horizontal, 36).padding(.top, 12)
            Card {
                CardRow(icon: "square.grid.2x2", title: "Kategorien bearbeiten", detail: "12")
                CardRow(icon: "arrow.triangle.branch", title: "Zuordnungen", detail: "7", isNew: true)
                CardRow(icon: "pin", title: "Standardartikel", detail: "3", last: true)
            }
            .padding(.horizontal, 20)
            Text("Zuordnungen: welcher Artikel in welcher Kategorie landet. nomi merkt sie sich, wenn ihr umsortiert.")
                .font(sans(12)).foregroundStyle(Color.inkMuted).padding(.horizontal, 36)
        }
    }
}

struct Mappings: View {
    let groups: [(String, [String])] = [
        ("Kühlregal", ["Vesper Käse", "Hafermilch", "Kombucha"]),
        ("Backwaren", ["Laugenbrezel"]),
        ("Bio-Ecke", ["Tofu", "Tempeh"]),
        ("Drogerie", ["Backpapier"]),
    ]
    var body: some View {
        SheetFrame {
            SheetHeader(title: "Zuordnungen", back: "Einkaufen")
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(Color.inkMuted)
                Text("Artikel suchen").font(sans(15)).foregroundStyle(Color.inkMuted.opacity(0.7))
                Spacer()
            }
            .padding(.horizontal, 14).frame(height: 40)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 20)
            ForEach(groups, id: \.0) { group in
                Meta(text: group.0).padding(.horizontal, 36).padding(.top, 6)
                Card {
                    ForEach(Array(group.1.enumerated()), id: \.offset) { index, name in
                        CardRow(icon: nil, title: name, detail: name == "Vesper Käse" ? "eben geändert" : "", last: index == group.1.count - 1)
                    }
                }
                .padding(.horizontal, 20)
            }
            Card { CardRow(icon: "plus", title: "Zuordnung hinzufügen", last: true, tint: .brand) }
                .padding(.horizontal, 20).padding(.top, 6)
            Text("Tippen ändert die Kategorie, nach links wischen vergisst die Zuordnung.")
                .font(sans(12)).foregroundStyle(Color.inkMuted).padding(.horizontal, 36)
        }
    }
}

struct Caption: View {
    var tag: String
    var title: String
    var text: String
    var highlight = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(tag).font(mono(13)).foregroundStyle(highlight ? Color.canvas : Color.ink)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(highlight ? Color.brand : Color.chip, in: .capsule)
                Text(title).font(heading(22)).foregroundStyle(Color.ink)
            }
            Text(text).font(sans(14)).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 390, height: 92, alignment: .topLeading)
    }
}

struct Sheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Zuordnungen bearbeiten").font(heading(40)).foregroundStyle(Color.ink)
                Text("Falsch einsortiert? Im Laden halten und umsortieren, im Zahnrad alles Gemerkte sehen und aufräumen.")
                    .font(sans(17)).foregroundStyle(Color.inkMuted)
            }
            HStack(alignment: .top, spacing: 48) {
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "1A", title: "Halten → Dialog", text: "Wie heute in der Liste: System-Dialog mit allen Kategorien. Vertraut, aber lang und ohne Markierung, wo der Artikel gerade liegt.")
                    DialogA()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "1B", title: "Halten → Chips", text: "Eigenes Blatt: alle Kategorien auf einen Blick, aktuelle mit Haken, nomis Vorschlag dunkel. Ein Tipp, fertig.", highlight: true)
                    SheetB()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "1", title: "Danach", text: "Der Artikel wandert auf die Seite seiner Abteilung. Kurzer Hinweis, wohin, mit „Hinspringen“.")
                    Moved()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "2", title: "Zahnrad: Zuordnungen", text: "Neue Zeile unter „Kategorien bearbeiten“, mit Anzahl der gemerkten Artikel.")
                    Settings()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "2", title: "Alles Gemerkte", text: "Nach Kategorie gruppiert, mit Suche. Tippen ändert, Wischen vergisst, „+“ legt eine Zuordnung vorab an.")
                    Mappings()
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "star.fill").foregroundStyle(Color.ochre)
                Text("Empfehlung: 1B – im Laden hat man eine Hand frei, große Chips treffen sich leichter als eine lange Liste, und man sieht, wo der Artikel gerade liegt. Dasselbe Blatt ersetzt dann auch den Dialog in der Liste.")
                    .font(sans(17, "Medium")).foregroundStyle(Color.ink)
            }
        }
        .padding(56)
        .background(Color(hex: 0xEFEBE3))
    }
}

// ImageRenderer gehört zum Main-Actor; Skript-Code läuft auf dem Hauptthread
MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: Sheet())
    renderer.scale = 1.5
    guard let image = renderer.cgImage else { fatalError("Rendern fehlgeschlagen") }
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[3]))
    print("geschrieben: \(args[3])")
}
