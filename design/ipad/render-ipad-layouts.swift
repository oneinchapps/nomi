// Rendert Entwürfe für nomi auf dem iPad (Querformat, 1180 × 820 pt):
// A: alles in einer mittigen Lesespalte, B: eigene iPad-Layouts (Raster, zwei Spalten, Wochen-Board).
// Aufruf: swift design/ipad/render-ipad-layouts.swift Nomi/Resources/Fonts design/fonts/DynaPuff.ttf design/ipad/vorschlaege.png
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
    static let tile1 = Color(hex: 0xF7E2B8)
    static let tile2 = Color(hex: 0xDDE8D6)
    static let tile3 = Color(hex: 0xF4D3DC)
    static let tile4 = Color(hex: 0xD9E6EE)
}

func sans(_ size: CGFloat, _ weight: String = "Regular") -> Font { .custom("DMSans-\(weight)", size: size) }
func mono(_ size: CGFloat) -> Font { .custom("DMMono-Regular", size: size) }
func heading(_ size: CGFloat) -> Font { .custom(size >= 32 ? "BricolageGrotesque96pt-ExtraBold" : "BricolageGrotesque24pt-Bold", size: size) }

struct Meta: View {
    let text: String
    var color = Color.inkMuted
    var body: some View { Text(text.uppercased()).font(mono(12)).tracking(1.4).foregroundStyle(color) }
}

// MARK: - Rahmen

/// iPad quer, mit der Tab-Kapsel von iOS 26 oben
struct IPad<Content: View>: View {
    var title: String
    var active: String
    var count: Int?
    var trailing: AnyView = AnyView(EmptyView())
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("nomi").font(.custom("DynaPuff", size: 34)).fontWeight(.bold).foregroundStyle(.white)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(["nomi", "Heute", "Woche", "Rezepte", "Einkauf"], id: \.self) { tab in
                            Text(tab).font(sans(16, "Medium"))
                                .foregroundStyle(tab == active ? Color.brand : Color.ink)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(tab == active ? Color.brand.opacity(0.14) : .clear, in: .capsule)
                        }
                    }
                    .padding(4)
                    .background(.white.opacity(0.9), in: .capsule)
                    Spacer()
                    Text("A").font(sans(16, "SemiBold")).foregroundStyle(.white)
                        .frame(width: 38, height: 38).background(.white.opacity(0.22), in: .circle)
                }
                HStack(spacing: 14) {
                    Text(title).font(heading(46)).foregroundStyle(.white)
                    if let count {
                        Text("\(count)").font(.custom("DMMono-Medium", size: 16)).foregroundStyle(.white)
                            .frame(minWidth: 34, minHeight: 34).background(.white.opacity(0.2), in: .capsule)
                    }
                    Spacer()
                    trailing
                }
            }
            .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 24)
            .background(Color.brand, in: UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
            content.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 1180, height: 820)
        .background(Color.canvas)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(Color.ink.opacity(0.85), lineWidth: 10))
    }
}

/// Vollbild ohne Tab-Kapsel (Kochmodus)
struct IPadPlain<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .frame(width: 1180, height: 820, alignment: .top)
            .background(Color.canvas)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 36, style: .continuous).stroke(Color.ink.opacity(0.85), lineWidth: 10))
    }
}

// MARK: - Bausteine

struct ItemRow: View {
    var name: String
    var amount = ""
    var big = false
    var body: some View {
        HStack(spacing: 14) {
            Circle().stroke(Color.hairline, lineWidth: 2).frame(width: big ? 26 : 22, height: big ? 26 : 22)
            Text(name).font(sans(big ? 18 : 16)).foregroundStyle(Color.ink)
            Spacer()
            Text(amount).font(sans(big ? 17 : 15, "Medium")).foregroundStyle(Color.ink)
        }
        .padding(.vertical, big ? 13 : 11)
        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 36) }
    }
}

struct InputRow: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("Was fehlt? z. B. 2 l Milch").font(sans(16)).foregroundStyle(Color.inkMuted.opacity(0.7))
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading).padding(.horizontal, 16)
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.hairline, lineWidth: 1.5))
            Image(systemName: "plus").font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.canvas)
                .frame(width: 50, height: 50).background(Color.ink, in: .circle)
        }
    }
}

struct Group2: View {
    var title: String
    var items: [(String, String)]
    var big = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Meta(text: title).padding(.top, 16).padding(.bottom, 2)
            ForEach(items, id: \.0) { ItemRow(name: $0.0, amount: $0.1, big: big) }
        }
    }
}

let shopping: [(String, [(String, String)])] = [
    ("Obst & Gemüse", [("Bananen", ""), ("Zwiebeln", "3"), ("Paprika", "2"), ("Zitronen", "2")]),
    ("Backwaren", [("Brötchen", "6"), ("Tortillas", "8")]),
    ("Kühlregal", [("Hafermilch", "1 l"), ("Halloumi", "250 g"), ("Joghurt", "500 g")]),
    ("Trockenwaren", [("Spaghetti", "500 g"), ("Reis", "1 kg")]),
    ("Getränke", [("Kombucha", ""), ("Sprudel", "6")]),
]

struct RecipeTile: View {
    var title: String
    var meta: String
    var tint: Color
    var icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 18).fill(tint).frame(height: 150)
                .overlay(Image(systemName: icon).font(.system(size: 44, weight: .light)).foregroundStyle(Color.ink.opacity(0.7)))
            Meta(text: meta)
            Text(title).font(heading(20)).foregroundStyle(Color.ink).lineLimit(2)
        }
    }
}

let recipes: [(String, String, Color, String)] = [
    ("Halloumi-Tacos", "20 min · für zwei", .tile1, "takeoutbag.and.cup.and.straw"),
    ("Chili-Nudeln", "20 min · für zwei", .tile3, "flame"),
    ("Shakshuka", "30 min · für zwei", .tile2, "frying.pan"),
    ("Ofengemüse mit Feta", "35 min · für zwei", .tile4, "carrot"),
    ("Linsen-Dal", "30 min · für vier", .tile1, "leaf"),
    ("Pesto-Pasta", "15 min · für zwei", .tile2, "fork.knife"),
    ("Kürbissuppe", "40 min · für vier", .tile3, "cup.and.saucer"),
    ("Bowl mit Tofu", "25 min · für zwei", .tile4, "takeoutbag.and.cup.and.straw"),
]

// MARK: - A · Lesespalte

struct ColumnShopping: View {
    var body: some View {
        IPad(title: "Einkauf", active: "Einkauf", count: 13) {
            VStack(alignment: .leading, spacing: 10) {
                InputRow()
                ForEach(shopping.prefix(3), id: \.0) { Group2(title: $0.0, items: $0.1) }
            }
            .frame(width: 640).padding(.top, 24)
            .overlay(alignment: .leading) { Rectangle().fill(Color.brand.opacity(0.0)).frame(width: 1) }
        }
        .overlay { ColumnMarks() }
    }
}

/// Markiert die Lesespalte im Entwurf
struct ColumnMarks: View {
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            Rectangle().strokeBorder(Color.brand.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [8, 6])).frame(width: 660)
            Spacer()
        }
        .padding(.top, 190).padding(.bottom, 20)
    }
}

struct ColumnRecipe: View {
    var body: some View {
        IPad(title: "Rezepte", active: "Rezepte", count: 8) {
            VStack(alignment: .leading, spacing: 12) {
                Meta(text: "Neu in eurer Sammlung")
                HStack(spacing: 14) {
                    ForEach(recipes.prefix(3), id: \.0) { r in RecipeTile(title: r.0, meta: r.1, tint: r.2, icon: r.3).frame(width: 196) }
                }
                VStack(spacing: 0) {
                    ForEach(["In 30 Minuten", "Lange nicht gekocht", "Alle Rezepte"], id: \.self) { t in
                        HStack { Text(t).font(sans(16)); Spacer(); Image(systemName: "chevron.right").foregroundStyle(Color.hairline) }
                            .padding(.horizontal, 16).frame(height: 48)
                    }
                }
                .background(Color.surface, in: RoundedRectangle(cornerRadius: 16))
            }
            .frame(width: 640).padding(.top, 24)
        }
        .overlay { ColumnMarks() }
    }
}

// MARK: - B · iPad-Layouts

struct GridRecipes: View {
    var body: some View {
        IPad(title: "Rezepte", active: "Rezepte", count: 8) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(["Alle", "Schnell", "Vegetarisch", "Pasta", "Suppen", "Lange nicht gekocht"], id: \.self) { chip in
                        Text(chip).font(sans(15, chip == "Alle" ? "SemiBold" : "Regular"))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .foregroundStyle(chip == "Alle" ? Color.canvas : Color.ink)
                            .background(chip == "Alle" ? Color.ink : Color.chip, in: .capsule)
                    }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 22), count: 4), spacing: 22) {
                    ForEach(recipes, id: \.0) { r in RecipeTile(title: r.0, meta: r.1, tint: r.2, icon: r.3) }
                }
            }
            .padding(.horizontal, 32).padding(.top, 22)
        }
    }
}

struct SplitRecipe: View {
    var body: some View {
        IPadPlain {
            HStack(alignment: .top, spacing: 0) {
                // Links: Bild, Kopf, Zutaten – bleibt stehen
                VStack(alignment: .leading, spacing: 14) {
                    RoundedRectangle(cornerRadius: 26).fill(Color.tile1).frame(height: 230)
                        .overlay(Image(systemName: "takeoutbag.and.cup.and.straw").font(.system(size: 70, weight: .light)).foregroundStyle(Color.ink.opacity(0.7)))
                    Meta(text: "20 min · für zwei")
                    Text("Halloumi-Tacos").font(heading(36)).foregroundStyle(Color.ink)
                    HStack {
                        Meta(text: "Portionen"); Spacer()
                        Image(systemName: "minus.circle.fill").foregroundStyle(Color.mist)
                        Text("2").font(sans(18, "SemiBold"))
                        Image(systemName: "plus.circle.fill").foregroundStyle(Color.mist)
                    }
                    .font(.system(size: 26)).padding(.horizontal, 14).frame(height: 48)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
                    Text("Zutaten").font(heading(22)).padding(.top, 4)
                    ForEach([("250 g", "Halloumi"), ("8", "kleine Tortillas"), ("2 EL", "Olivenöl"), ("1", "Limette")], id: \.1) { i in
                        HStack(spacing: 14) { Text(i.0).font(sans(16, "Medium")).frame(width: 60, alignment: .trailing); Text(i.1).font(sans(16)) }
                    }
                }
                .padding(32).frame(width: 440)
                .background(Color.surface)
                // Rechts: Schritte und Aktionen
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Label("Einkaufen", systemImage: "basket").font(sans(16, "Medium")).frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(Capsule().stroke(Color.hairline, lineWidth: 1.5))
                        Label("Einplanen", systemImage: "calendar").font(sans(16, "Medium")).frame(maxWidth: .infinity, minHeight: 48)
                            .overlay(Capsule().stroke(Color.hairline, lineWidth: 1.5))
                    }
                    Text("Jetzt kochen").font(sans(18, "SemiBold")).foregroundStyle(Color.canvas)
                        .frame(maxWidth: .infinity, minHeight: 56).background(Color.ink, in: RoundedRectangle(cornerRadius: 18))
                    Text("Zubereitung").font(heading(26)).padding(.top, 10)
                    ForEach(Array(["Halloumi in Scheiben schneiden und in Olivenöl goldbraun braten.",
                                   "Tortillas in einer trockenen Pfanne kurz erwärmen.",
                                   "Mit Halloumi belegen, Limette darüber träufeln, sofort essen."].enumerated()), id: \.offset) { i, s in
                        HStack(alignment: .top, spacing: 14) {
                            Text("\(i + 1)").font(heading(22)).foregroundStyle(Color.brand)
                            Text(s).font(sans(18)).foregroundStyle(Color.ink)
                        }
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.surface, in: RoundedRectangle(cornerRadius: 18))
                    }
                }
                .padding(32)
            }
        }
    }
}

struct WeekBoard: View {
    let days: [(String, String, [(String, String, Color)])] = [
        ("Mo", "2", [("Shakshuka", "Abend", .tile2)]), ("Di", "3", []), ("Mi", "4", [("Linsen-Dal", "Mittag", .tile1), ("Pesto-Pasta", "Abend", .tile2)]),
        ("Do", "5", []), ("Fr", "6", [("Halloumi-Tacos", "Abend", .tile1)]), ("Sa", "7", [("Kürbissuppe", "Mittag", .tile3)]), ("So", "8", []),
    ]
    var body: some View {
        IPad(title: "Diese Woche", active: "Woche", trailing: AnyView(HStack(spacing: 10) {
            ForEach(["chevron.left", "chevron.right"], id: \.self) { Image(systemName: $0).font(.system(size: 15, weight: .bold)).foregroundStyle(.white).frame(width: 38, height: 38).background(.white.opacity(0.2), in: .circle) }
        })) {
            VStack(spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(days, id: \.0) { day in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Meta(text: day.0)
                                Text(day.1).font(heading(24)).foregroundStyle(day.1 == "7" ? .white : Color.ink)
                                    .frame(width: 38, height: 38).background(day.1 == "7" ? Color.brand : .clear, in: .circle)
                            }
                            ForEach(day.2, id: \.0) { meal in
                                VStack(alignment: .leading, spacing: 6) {
                                    RoundedRectangle(cornerRadius: 10).fill(meal.2).frame(height: 54)
                                    Meta(text: meal.1)
                                    Text(meal.0).font(sans(15, "SemiBold")).foregroundStyle(Color.ink).lineLimit(2)
                                }
                                .padding(10).background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
                            }
                            Image(systemName: "plus").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.inkMuted)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                Spacer()
                Text("Zutaten der Woche einkaufen").font(sans(17, "SemiBold")).foregroundStyle(Color.canvas)
                    .frame(width: 420, height: 54).background(Color.ink, in: RoundedRectangle(cornerRadius: 18))
            }
            .padding(.horizontal, 28).padding(.top, 22).padding(.bottom, 26)
        }
    }
}

struct SplitCooking: View {
    var body: some View {
        IPadPlain {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "xmark").font(.system(size: 15, weight: .bold)).foregroundStyle(.white).frame(width: 38, height: 38).background(.white.opacity(0.18), in: .circle)
                        Spacer()
                        Meta(text: "Schritt 2 von 4", color: .white)
                    }
                    Text("Pasta Aglio e Olio").font(heading(24)).foregroundStyle(.white)
                    Capsule().fill(.white.opacity(0.25)).frame(height: 6).overlay(alignment: .leading) { Capsule().fill(.white).frame(width: 520, height: 6) }
                }
                .padding(.horizontal, 32).padding(.top, 30).padding(.bottom, 20)
                .background(Color.brand, in: UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30))
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Zutaten").font(heading(22))
                        ForEach([("200 g", "Spaghetti", true), ("2 Zehen", "Knoblauch", false), ("4 EL", "Olivenöl", false), ("1", "Chili", false), ("", "Salz", true)], id: \.1) { i in
                            HStack(spacing: 12) {
                                Image(systemName: i.2 ? "checkmark.circle.fill" : "circle").foregroundStyle(i.2 ? Color.sage : Color.hairline).font(.system(size: 22))
                                Text(i.0).font(sans(16, "Medium")).frame(width: 70, alignment: .leading)
                                Text(i.1).font(sans(16)).strikethrough(i.2, color: Color.inkMuted).foregroundStyle(i.2 ? Color.inkMuted : Color.ink)
                            }
                        }
                        Meta(text: "In diesem Schritt: Spaghetti, Salz").padding(.top, 6)
                    }
                    .padding(32).frame(width: 380, alignment: .topLeading).frame(maxHeight: .infinity, alignment: .top)
                    .background(Color.surface)
                    VStack(alignment: .leading, spacing: 22) {
                        Text("2").font(heading(64)).foregroundStyle(Color.brand)
                        Text("Spaghetti in reichlich Salzwasser bissfest kochen.").font(heading(40)).foregroundStyle(Color.ink)
                        HStack {
                            Text("08:42").font(.custom("DMMono-Medium", size: 64)).foregroundStyle(Color.ink)
                            Spacer()
                            Image(systemName: "pause.fill").font(.system(size: 24, weight: .bold)).foregroundStyle(.white).frame(width: 70, height: 70).background(Color.brand, in: .circle)
                        }
                        .padding(24).background(Color.surface, in: RoundedRectangle(cornerRadius: 24))
                        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.brand, lineWidth: 2))
                        Spacer()
                        HStack(spacing: 12) {
                            Label("Zurück", systemImage: "chevron.left").font(sans(17, "Medium")).frame(width: 160, height: 56).overlay(Capsule().stroke(Color.hairline, lineWidth: 1.5))
                            Text("Weiter").font(sans(18, "SemiBold")).foregroundStyle(Color.canvas).frame(maxWidth: .infinity, minHeight: 56).background(Color.ink, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                    .padding(36)
                }
            }
        }
    }
}

struct ColumnsShopping: View {
    var body: some View {
        IPad(title: "Einkauf", active: "Einkauf", count: 13, trailing: AnyView(
            HStack(spacing: 8) { Image(systemName: "cart.fill"); Text("Einkaufen starten").font(sans(16, "SemiBold")) }
                .foregroundStyle(Color.ink).padding(.horizontal, 18).frame(height: 44).background(.white, in: .capsule)
        )) {
            VStack(alignment: .leading, spacing: 10) {
                InputRow().frame(width: 640)
                HStack(alignment: .top, spacing: 36) {
                    VStack(spacing: 0) { Group2(title: shopping[0].0, items: shopping[0].1); Group2(title: shopping[1].0, items: shopping[1].1) }
                    VStack(spacing: 0) { Group2(title: shopping[2].0, items: shopping[2].1); Group2(title: shopping[3].0, items: shopping[3].1) }
                    VStack(spacing: 0) { Group2(title: shopping[4].0, items: shopping[4].1) }
                }
            }
            .padding(.horizontal, 32).padding(.top, 22)
        }
    }
}

// MARK: - Bogen

struct Caption: View {
    var tag: String
    var title: String
    var text: String
    var highlight = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(tag).font(mono(15)).foregroundStyle(highlight ? Color.canvas : Color.ink)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(highlight ? Color.brand : Color.chip, in: .capsule)
                Text(title).font(heading(26)).foregroundStyle(Color.ink)
            }
            Text(text).font(sans(17)).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 1180, alignment: .leading)
    }
}

struct Cell<Content: View>: View {
    var caption: Caption
    @ViewBuilder var content: Content
    var body: some View { VStack(alignment: .leading, spacing: 18) { caption; content } }
}

struct Sheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 50) {
            VStack(alignment: .leading, spacing: 10) {
                Text("nomi auf dem iPad").font(heading(54)).foregroundStyle(Color.ink)
                Text("Heute läuft alles, sieht aber aus wie ein großes iPhone. Zwei Richtungen; alle Bildschirme passen sich an, auch hochkant und in Split View.")
                    .font(sans(21)).foregroundStyle(Color.inkMuted)
            }
            Text("A · LESESPALTE").font(mono(18)).tracking(2)
            HStack(alignment: .top, spacing: 60) {
                Cell(caption: Caption(tag: "A", title: "Einkauf", text: "Inhalt mittig, höchstens 660 pt breit. Schnell gebaut, ruhig, aber die Fläche bleibt leer.")) { ColumnShopping() }
                Cell(caption: Caption(tag: "A", title: "Rezepte", text: "Gleiche Spalte überall – wirkt wie ein iPhone in der Mitte.")) { ColumnRecipe() }
            }
            Text("B · IPAD-LAYOUTS").font(mono(18)).tracking(2).padding(.top, 20)
            HStack(alignment: .top, spacing: 60) {
                Cell(caption: Caption(tag: "B", title: "Rezepte als Raster", text: "Kacheln in 4 Spalten (hochkant 3), Filter-Chips oben. Man sieht die ganze Sammlung.", highlight: true)) { GridRecipes() }
                Cell(caption: Caption(tag: "B", title: "Rezept zweispaltig", text: "Links Bild, Portionen und Zutaten fest, rechts Schritte und Aktionen.", highlight: true)) { SplitRecipe() }
            }
            HStack(alignment: .top, spacing: 60) {
                Cell(caption: Caption(tag: "B", title: "Woche als Board", text: "Sieben Spalten nebeneinander, Gerichte als Karten, Ziehen zwischen Tagen bleibt. Hochkant wie heute als Liste.", highlight: true)) { WeekBoard() }
                Cell(caption: Caption(tag: "B", title: "Kochmodus zweispaltig", text: "Zutaten zum Abhaken links, Schritt und Timer groß rechts – lesbar vom Herd aus.", highlight: true)) { SplitCooking() }
            }
            HStack(alignment: .top, spacing: 60) {
                Cell(caption: Caption(tag: "B", title: "Einkauf in Spalten", text: "Abteilungen in bis zu drei Spalten, „Einkaufen starten“ wandert in den Kopf. nomi-Chat, Heute und Formulare bekommen die Lesespalte aus A.", highlight: true)) { ColumnsShopping() }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "star.fill").foregroundStyle(Color.ochre).font(.system(size: 26))
                        Text("Empfehlung: B").font(heading(32))
                    }
                    Text("Das iPad liegt beim Kochen und Planen auf dem Tisch – da lohnt die Fläche: Rezepte im Raster finden, die Woche auf einen Blick, Kochen mit großer Schrift. Bildschirme ohne eigenes Layout (nomi, Heute, Formulare) bekommen die Lesespalte aus A. Zuerst baue ich die Lesespalte für alle, dann Rezepte, Kochmodus, Woche und Einkauf.")
                        .font(sans(21)).foregroundStyle(Color.ink).fixedSize(horizontal: false, vertical: true)
                    Text("Tab-Leiste: bleibt die iOS-26-Kapsel oben. Für den App Store braucht es zusätzlich iPad-Screenshots (13″).")
                        .font(sans(18)).foregroundStyle(Color.inkMuted).fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 1180, alignment: .leading)
                .padding(.top, 40)
            }
        }
        .padding(70)
        .background(Color(hex: 0xEFEBE3))
    }
}

MainActor.assumeIsolated {
    let renderer = ImageRenderer(content: Sheet())
    renderer.scale = 0.75
    guard let image = renderer.cgImage else { fatalError("Rendern fehlgeschlagen") }
    let rep = NSBitmapImageRep(cgImage: image)
    let out = URL(fileURLWithPath: args[3])
    try! FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: out)
    print("geschrieben: \(args[3])")
}
