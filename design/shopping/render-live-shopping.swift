// Rendert Entwürfe für den Live-Einkaufsmodus: Einstieg aus der Liste, drei Richtungen für den Vollbild-Modus
// und den Abschluss. Bildschirm bleibt an, oben nur ein schmaler Kopf, alles dreht sich ums Abhaken.
// Aufruf: swift design/shopping/render-live-shopping.swift Nomi/Resources/Fonts design/fonts/DynaPuff.ttf design/shopping/live-einkaufen.png
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
    static let sage = Color(hex: 0x6F8F6A)
    static let sageLight = Color(hex: 0xDDE8D6)
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

/// Schmaler Kopf im Modus: Schließen, Supermarkt, Fortschritt, wer mit einkauft
struct LiveTop: View {
    var subtitle = "Rewe"
    var done = 5
    var total = 12
    var partner = true
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 36, height: 36).background(.white.opacity(0.18), in: .circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Einkaufen").font(heading(22)).foregroundStyle(.white)
                    Text(subtitle).font(sans(13)).foregroundStyle(.white.opacity(0.8))
                }
                Spacer()
                Meta(text: "\(done) von \(total)", color: .white)
            }
            Capsule().fill(.white.opacity(0.25)).frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { g in Capsule().fill(.white).frame(width: g.size.width * CGFloat(done) / CGFloat(total)) }
                }
            if partner { PresencePill() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }
}

/// „Sam kauft mit“ – nur sichtbar, solange die andere Person auch im Modus ist
struct PresencePill: View {
    var body: some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: 0x9FE3A0)).frame(width: 8, height: 8)
            Text("S").font(sans(11, "SemiBold")).foregroundStyle(.white)
                .frame(width: 22, height: 22).background(.white.opacity(0.25), in: .circle)
            Text("Sam kauft mit").font(sans(13, "Medium")).foregroundStyle(.white)
        }
        .padding(.leading, 10).padding(.trailing, 14).padding(.vertical, 5)
        .background(.white.opacity(0.14), in: .capsule)
    }
}

struct BigRow: View {
    var name: String
    var amount = ""
    var checked = false
    /// Gerade von der anderen Person abgehakt: kurz hervorgehoben
    var byPartner = false
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(checked ? Color.sage : Color.inkMuted.opacity(0.45), lineWidth: 2.5).frame(width: 32, height: 32)
                if checked {
                    Circle().fill(Color.sage).frame(width: 32, height: 32)
                    Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.white)
                }
            }
            Text(name).font(sans(20, "Medium")).foregroundStyle(checked ? Color.inkMuted : Color.ink)
                .strikethrough(checked, color: Color.inkMuted)
            Spacer()
            if byPartner {
                Text("S").font(sans(11, "SemiBold")).foregroundStyle(.white)
                    .frame(width: 22, height: 22).background(Color.sage, in: .circle)
            }
            Text(amount).font(sans(17, "Medium")).foregroundStyle(checked ? Color.inkMuted : Color.ink)
        }
        .padding(.horizontal, 14)
        .frame(height: 60)
        .background(byPartner ? Color.sageLight : .clear, in: RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .bottom) {
            if !byPartner { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 62) }
        }
    }
}

struct BigGroup: View {
    var title: String
    var items: [(String, String)]
    var partnerItem: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Meta(text: title).padding(.top, 18).padding(.bottom, 4).padding(.leading, 14)
            ForEach(items, id: \.0) { item in
                BigRow(name: item.0, amount: item.1, checked: item.0 == partnerItem, byPartner: item.0 == partnerItem)
            }
        }
    }
}

struct CartBar: View {
    var count = 5
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.inkMuted)
            Meta(text: "Im Wagen · \(count)")
            Spacer()
        }
        .padding(.horizontal, 14).padding(.top, 22)
    }
}

// MARK: - Bildschirme

/// Einstieg: dunkle Pille über der Liste
struct Entry: View {
    var body: some View {
        Phone {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 10) {
                        Text("nomi").font(.custom("DynaPuff", size: 30)).fontWeight(.bold).foregroundStyle(.white)
                        Spacer()
                        Image(systemName: "gearshape").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(.white.opacity(0.18), in: .circle)
                        Text("A").font(sans(16, "SemiBold")).foregroundStyle(.white)
                            .frame(width: 36, height: 36).background(.white.opacity(0.22), in: .circle)
                    }
                    HStack(spacing: 12) {
                        Text("Einkauf").font(heading(44)).foregroundStyle(.white)
                        Text("12").font(sans(15, "SemiBold")).foregroundStyle(.white)
                            .frame(width: 30, height: 30).background(.white.opacity(0.22), in: .circle)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 58).padding(.bottom, 22)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brand, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Text("Was fehlt? z. B. 2 l Milch").font(sans(16)).foregroundStyle(Color.inkMuted.opacity(0.7))
                            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading).padding(.horizontal, 16)
                            .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hairline, lineWidth: 1.5))
                        Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.canvas)
                            .frame(width: 50, height: 50).background(Color.ink, in: .circle)
                    }
                    // Neu: Einstieg in den Modus
                    HStack(spacing: 10) {
                        Image(systemName: "cart.fill").font(.system(size: 16, weight: .semibold))
                        Text("Einkaufen starten").font(sans(17, "SemiBold"))
                    }
                    .foregroundStyle(Color.canvas)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(Color.ink, in: .capsule)
                    .overlay(alignment: .topTrailing) {
                        Text("NEU").font(mono(10)).tracking(1.2).foregroundStyle(Color.ink)
                            .padding(.horizontal, 7).padding(.vertical, 3).background(Color.ochre, in: .capsule).offset(x: -4, y: -8)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(smallList, id: \.0) { group in
                            Meta(text: group.0).padding(.top, 14).padding(.bottom, 2)
                            ForEach(group.1, id: \.self) { name in
                                HStack(spacing: 14) {
                                    Circle().stroke(Color.hairline, lineWidth: 2).frame(width: 22, height: 22)
                                    Text(name).font(sans(16)).foregroundStyle(Color.ink)
                                    Spacer()
                                }
                                .padding(.vertical, 11)
                                .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 36) }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20).padding(.top, 18)
            }
        }
    }
    let smallList: [(String, [String])] = [
        ("Obst & Gemüse", ["Bananen", "Zwiebeln", "Paprika"]),
        ("Kühlregal", ["Hafermilch", "Halloumi", "Joghurt"]),
    ]
}

/// A: alles in einer großen Liste, Weg durch den Laden von oben nach unten
struct LiveA: View {
    var body: some View {
        Phone {
            VStack(alignment: .leading, spacing: 0) {
                LiveTop()
                VStack(alignment: .leading, spacing: 0) {
                    BigGroup(title: "Obst & Gemüse", items: [("Bananen", ""), ("Zwiebeln", "3"), ("Paprika", "2")])
                    BigGroup(title: "Kühlregal", items: [("Hafermilch", "1 l"), ("Halloumi", "250 g"), ("Joghurt", "500 g")], partnerItem: "Halloumi")
                    BigGroup(title: "Getränke", items: [("Kombucha", "")])
                    CartBar()
                }
                .padding(.horizontal, 6)
            }
        }
    }
}

/// B: eine Abteilung pro Seite, wie die Schritte im Kochmodus
struct LiveB: View {
    var body: some View {
        Phone {
            VStack(alignment: .leading, spacing: 0) {
                LiveTop(subtitle: "Abteilung 2 von 5")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Kühlregal").font(heading(34)).foregroundStyle(Color.ink).padding(.leading, 14).padding(.top, 22)
                    Meta(text: "3 Dinge · 1 im Wagen").padding(.leading, 14).padding(.bottom, 6)
                    BigRow(name: "Hafermilch", amount: "1 l")
                    BigRow(name: "Halloumi", amount: "250 g", checked: true, byPartner: true)
                    BigRow(name: "Joghurt", amount: "500 g")
                }
                .padding(.horizontal, 6)
                Spacer()
                HStack {
                    Image(systemName: "chevron.left").font(.system(size: 18, weight: .bold)).foregroundStyle(Color.ink)
                        .frame(width: 54, height: 54).background(Color.mist, in: .circle)
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<5) { i in Capsule().fill(i == 1 ? Color.brand : Color.hairline).frame(width: i == 1 ? 18 : 7, height: 7) }
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 54, height: 54).background(Color.brand, in: .circle)
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
        }
    }
}

/// C: große Kacheln, zwei Spalten
struct LiveC: View {
    let tiles: [(String, String, Bool)] = [
        ("Bananen", "", false), ("Zwiebeln", "3", false), ("Paprika", "2", false), ("Hafermilch", "1 l", false),
        ("Halloumi", "250 g", true), ("Joghurt", "500 g", false), ("Kombucha", "", false), ("Brötchen", "6", false),
    ]
    var body: some View {
        Phone {
            VStack(alignment: .leading, spacing: 0) {
                LiveTop()
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(tiles, id: \.0) { tile in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(tile.1.isEmpty ? " " : tile.1).font(sans(14, "Medium")).foregroundStyle(Color.inkMuted)
                                Spacer()
                                if tile.2 {
                                    Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Color.sage)
                                }
                            }
                            Spacer()
                            Text(tile.0).font(sans(19, "SemiBold")).foregroundStyle(tile.2 ? Color.inkMuted : Color.ink)
                                .strikethrough(tile.2, color: Color.inkMuted)
                        }
                        .padding(14)
                        .frame(height: 104)
                        .background(tile.2 ? Color.sageLight : Color.surface, in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(tile.2 ? .clear : Color.hairline, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 20).padding(.top, 20)
            }
        }
    }
}

/// Abschluss (für alle Richtungen gleich)
struct Done: View {
    var body: some View {
        Phone {
            VStack(spacing: 0) {
                LiveTop(done: 12, total: 12, partner: false)
                Spacer()
                ZStack {
                    Circle().fill(Color.sageLight).frame(width: 150, height: 150)
                    Image(systemName: "basket.fill").font(.system(size: 58)).foregroundStyle(Color.sage)
                }
                Text("Alles im Wagen!").font(heading(34)).foregroundStyle(Color.ink).padding(.top, 26)
                Text("12 Dinge, Sam hat 5 davon geholt.").font(sans(17)).foregroundStyle(Color.inkMuted).padding(.top, 6)
                Spacer()
                VStack(spacing: 12) {
                    Text("Fertig, Liste leeren").font(sans(17, "SemiBold")).foregroundStyle(Color.canvas)
                        .frame(maxWidth: .infinity, minHeight: 54).background(Color.ink, in: .capsule)
                    Text("Liste behalten").font(sans(17, "SemiBold")).foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 54).overlay(Capsule().stroke(Color.ink, lineWidth: 1.5))
                }
                .padding(.horizontal, 24).padding(.bottom, 40)
            }
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
        .frame(width: 390, height: 92, alignment: .topLeading)
    }
}

struct Sheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 34) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Live einkaufen").font(heading(40)).foregroundStyle(Color.ink)
                Text("Vollbild wie beim Kochen: Bildschirm bleibt an, oben nur ein schmaler Kopf. Abhaken der anderen Person erscheint sofort und leuchtet kurz grün mit ihrem Kürzel.")
                    .font(sans(17)).foregroundStyle(Color.inkMuted)
            }
            HStack(alignment: .top, spacing: 48) {
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "Einstieg", title: "Einkaufen starten", text: "Dunkle Pille unter dem Eingabefeld, erscheint nur, wenn etwas auf der Liste steht.")
                    Entry()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "A", title: "Eine große Liste", text: "Wie die Liste, nur größer: 60 pt hohe Zeilen, Abteilungen in der Reihenfolge des Supermarkts. Abgehaktes rutscht nach unten in „Im Wagen“.", highlight: true)
                    LiveA()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "B", title: "Abteilung für Abteilung", text: "Eine Seite pro Abteilung, Wischen wie im Kochmodus. Sehr ruhig, aber man muss blättern, wenn man im Laden springt.")
                    LiveB()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "C", title: "Kacheln", text: "Riesige Tippflächen in zwei Spalten. Gut mit einer Hand, aber lange Namen werden eng und die Abteilungen fehlen.")
                    LiveC()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "Ende", title: "Alles im Wagen", text: "Wenn nichts mehr offen ist: kurzer Jubel, dann Liste leeren oder behalten.")
                    Done()
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "star.fill").foregroundStyle(Color.ochre)
                Text("Empfehlung: A – im Laden springt man zwischen Abteilungen, eine durchgehende Liste verzeiht das, und sie fühlt sich an wie die gewohnte Einkaufsliste.")
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
