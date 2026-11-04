// Rendert Entwürfe für Supermärkte mit eigener Kategorien-Reihenfolge: Einkauf mit Zahnrad
// (zwei Varianten für die Supermarkt-Wahl), Einstellungen und Reihenfolge eines Supermarkts.
// Aufruf: swift design/shopping/render-store-settings.swift Nomi/Resources/Fonts design/fonts/DynaPuff.ttf design/shopping/vorschlaege.png
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
    static let mist = Color(hex: 0xECE7DD)
    static let surface = Color(hex: 0xFFFDF9)
    static let ochre = Color(hex: 0xF2B33D)
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

struct BrandTop: View {
    var title: String
    var count: Int?
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Text("nomi").font(.custom("DynaPuff", size: 30)).fontWeight(.bold).foregroundStyle(.white)
                Spacer()
                // Neu: Zahnrad links vom Profil
                Image(systemName: "gearshape")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 38, height: 38)
                Text("A").font(sans(16, "SemiBold")).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.white.opacity(0.22), in: .circle)
            }
            HStack(spacing: 12) {
                Text(title).font(heading(44)).foregroundStyle(.white)
                if let count {
                    Text("\(count)").font(sans(15, "SemiBold")).foregroundStyle(.white)
                        .frame(width: 30, height: 30).background(.white.opacity(0.22), in: .circle)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.top, 58)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }
}

struct InputRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Was fehlt? z. B. 2 l Milch").font(sans(16)).foregroundStyle(Color.inkMuted.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .padding(.horizontal, 16)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hairline, lineWidth: 1.5))
            Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.canvas)
                .frame(width: 50, height: 50).background(Color.ink, in: .circle)
        }
    }
}

struct Chip: View {
    var text: String
    var icon: String? = "plus"
    var filled = false
    var strong = false
    var body: some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.system(size: 10, weight: .bold)) }
            Text(text)
        }
        .font(sans(13, strong ? "SemiBold" : "Regular"))
        .padding(.horizontal, 12).padding(.vertical, 7)
        .foregroundStyle(filled ? Color.canvas : Color.ink)
        .background(filled ? Color.ink : Color.mist, in: .capsule)
    }
}

struct ItemRow: View {
    var name: String
    var amount = ""
    var body: some View {
        HStack(spacing: 14) {
            Circle().stroke(Color.hairline, lineWidth: 2).frame(width: 22, height: 22)
            Text(name).font(sans(16)).foregroundStyle(Color.ink)
            Spacer()
            Text(amount).font(sans(15, "Medium")).foregroundStyle(Color.ink)
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 36) }
    }
}

struct Group: View {
    var title: String
    var items: [(String, String)]
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Meta(text: title).padding(.top, 16).padding(.bottom, 2)
            ForEach(items, id: \.0) { ItemRow(name: $0.0, amount: $0.1) }
        }
    }
}

let reweList: [(String, [(String, String)])] = [
    ("Obst & Gemüse", [("Bananen", ""), ("Zwiebeln", "3")]),
    ("Backwaren", [("Brötchen", "6")]),
    ("Kühlregal", [("Hafermilch", "1 l"), ("Halloumi", "250 g")]),
    ("Getränke", [("Kombucha", "")]),
]

// MARK: - Bildschirme

/// Variante A: eine Pille mit dem Supermarkt, tippen öffnet ein Menü
struct ListA: View {
    var body: some View {
        Phone {
            VStack(alignment: .leading, spacing: 0) {
                BrandTop(title: "Einkauf", count: 6)
                VStack(alignment: .leading, spacing: 14) {
                    InputRow()
                    HStack(spacing: 8) {
                        Chip(text: "Milch")
                        Chip(text: "Eier")
                        Chip(text: "Brot")
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "storefront").font(.system(size: 12, weight: .semibold))
                        Text("Sortiert für").font(sans(13)).foregroundStyle(Color.inkMuted)
                        Text("Rewe").font(sans(13, "SemiBold"))
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .overlay(Capsule().stroke(Color.hairline, lineWidth: 1.5))
                    .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(reweList, id: \.0) { Group(title: $0.0, items: $0.1) }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18)
            }
        }
    }
}

/// Variante B: alle Supermärkte als Reiter über der Liste
struct ListB: View {
    var body: some View {
        Phone {
            VStack(alignment: .leading, spacing: 0) {
                BrandTop(title: "Einkauf", count: 6)
                VStack(alignment: .leading, spacing: 14) {
                    InputRow()
                    HStack(spacing: 8) {
                        Chip(text: "Milch")
                        Chip(text: "Eier")
                        Chip(text: "Brot")
                    }
                    HStack(spacing: 0) {
                        ForEach(["Rewe", "Aldi", "Markt"], id: \.self) { store in
                            Text(store).font(sans(14, store == "Rewe" ? "SemiBold" : "Regular"))
                                .foregroundStyle(store == "Rewe" ? Color.canvas : Color.ink)
                                .frame(maxWidth: .infinity, minHeight: 34)
                                .background(store == "Rewe" ? Color.ink : .clear, in: .capsule)
                        }
                    }
                    .padding(3)
                    .background(Color.mist, in: .capsule)
                    .padding(.top, 2)
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(reweList, id: \.0) { Group(title: $0.0, items: $0.1) }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18)
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
        VStack(spacing: 0) { content }
            .background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct CardRow: View {
    var icon: String
    var title: String
    var detail = ""
    var check = false
    var last = false
    var tint = Color.ink
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15, weight: .medium)).foregroundStyle(tint).frame(width: 24)
            Text(title).font(sans(16)).foregroundStyle(tint)
            Spacer()
            if check { Image(systemName: "checkmark").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.brand) }
            Text(detail).font(sans(14)).foregroundStyle(Color.inkMuted)
            if tint == Color.ink { Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.hairline) }
        }
        .padding(.horizontal, 16).frame(minHeight: 50)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 52) } }
    }
}

struct Settings: View {
    var body: some View {
        Phone {
            VStack(spacing: 0) {
                Color.ink.opacity(0.35).frame(height: 44)
                VStack(alignment: .leading, spacing: 10) {
                    SheetHeader(title: "Einkaufen")
                    Meta(text: "Supermärkte").padding(.horizontal, 36).padding(.top, 6)
                    Card {
                        CardRow(icon: "storefront", title: "Rewe", detail: "aktiv", check: true)
                        CardRow(icon: "storefront", title: "Aldi")
                        CardRow(icon: "leaf", title: "Wochenmarkt")
                        CardRow(icon: "plus", title: "Supermarkt hinzufügen", last: true, tint: .brand)
                    }
                    .padding(.horizontal, 20)
                    Text("Jeder Supermarkt hat seine eigene Reihenfolge. Welchen ihr gerade nutzt, wählt ihr direkt über der Liste.")
                        .font(sans(12)).foregroundStyle(Color.inkMuted).padding(.horizontal, 36)

                    Meta(text: "Kategorien").padding(.horizontal, 36).padding(.top, 12)
                    Card {
                        CardRow(icon: "square.grid.2x2", title: "Kategorien bearbeiten", detail: "12")
                        CardRow(icon: "pin", title: "Standardartikel", detail: "3", last: true)
                    }
                    .padding(.horizontal, 20)
                    Text("Umbenennen und eigene Kategorien gelten für alle Supermärkte.")
                        .font(sans(12)).foregroundStyle(Color.inkMuted).padding(.horizontal, 36)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.canvas, in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
            }
            .background(Color.ink.opacity(0.35))
        }
    }
}

struct Order: View {
    let rows: [(String, Bool)] = [
        ("Obst & Gemüse", false), ("Backwaren", false), ("Bio-Ecke", true), ("Kühlregal", false),
        ("Fleisch & Fisch", false), ("Trockenwaren", false), ("Konserven & Gläser", false),
        ("Gewürze & Öle", false), ("Tiefkühl", false), ("Getränke", false), ("Drogerie", false), ("Sonstiges", false),
    ]
    var body: some View {
        Phone {
            VStack(spacing: 0) {
                Color.ink.opacity(0.35).frame(height: 44)
                VStack(alignment: .leading, spacing: 10) {
                    SheetHeader(title: "Rewe", back: "Einkaufen")
                    Text("So, wie ihr durch den Laden lauft. Zum Verschieben halten und ziehen.")
                        .font(sans(13)).foregroundStyle(Color.inkMuted).padding(.horizontal, 24)
                    Card {
                        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                            HStack(spacing: 12) {
                                Text("\(index + 1)").font(mono(12)).foregroundStyle(Color.inkMuted).frame(width: 20)
                                Text(row.0).font(sans(15)).foregroundStyle(Color.ink)
                                if row.1 { Meta(text: "eigene", color: .brand) }
                                Spacer()
                                Image(systemName: "line.3.horizontal").font(.system(size: 15)).foregroundStyle(Color.inkMuted)
                            }
                            .padding(.horizontal, 16).frame(minHeight: 41)
                            .background(index == 2 ? Color.mist : .clear)
                            .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 48) }
                        }
                    }
                    .padding(.horizontal, 20)
                    HStack(spacing: 18) {
                        Label("Umbenennen", systemImage: "pencil")
                        Label("Löschen", systemImage: "trash")
                    }
                    .font(sans(12)).foregroundStyle(Color.inkMuted).padding(.horizontal, 36)
                    Text("Wischen nach links bei einer Kategorie")
                        .font(sans(11)).foregroundStyle(Color.inkMuted.opacity(0.8)).padding(.horizontal, 36).padding(.top, -6)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.canvas, in: UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22))
            }
            .background(Color.ink.opacity(0.35))
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
                    .background(highlight ? Color.brand : Color.mist, in: .capsule)
                Text(title).font(heading(22)).foregroundStyle(Color.ink)
            }
            Text(text).font(sans(14)).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 390, alignment: .leading)
    }
}

struct Sheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Supermärkte & Kategorien").font(heading(40)).foregroundStyle(Color.ink)
                Text("Zahnrad oben rechts → Einstellungen fürs Einkaufen. Jeder Supermarkt hat seine eigene Reihenfolge der Kategorien.")
                    .font(sans(17)).foregroundStyle(Color.inkMuted)
            }
            HStack(alignment: .top, spacing: 48) {
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "A", title: "Supermarkt als Pille", text: "Eine Zeile „Sortiert für Rewe ▾“ über der Liste, tippen wechselt. Bleibt klein, auch mit vielen Supermärkten.", highlight: true)
                    ListA()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "B", title: "Supermärkte als Reiter", text: "Alle Supermärkte nebeneinander, ein Tipp wechselt. Schneller, aber ab vier Läden wird es eng.")
                    ListB()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "Zahnrad", title: "Einstellungen", text: "Supermärkte anlegen, umbenennen, löschen. Kategorien und Standardartikel an einem Ort.")
                    Settings()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "Rewe", title: "Reihenfolge", text: "Kategorien per Halten und Ziehen sortieren. Eigene Kategorien wie „Bio-Ecke“ kommen dazu.")
                    Order()
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "star.fill").foregroundStyle(Color.ochre)
                Text("Empfehlung: Variante A – die Liste bleibt ruhig, und wer nur einen Supermarkt hat, sieht kaum etwas Neues.")
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
