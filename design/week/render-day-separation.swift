// Rendert drei Richtungen, wie sich die Tage im Wochenplan klarer voneinander trennen lassen.
// Aufruf: swift design/week/render-day-separation.swift Nomi/Resources/Fonts design/fonts/DynaPuff.ttf design/week/vorschlaege.png
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
    static let peach = Color(hex: 0xF8DCC8)
    static let butter = Color(hex: 0xF7E3B0)
    static let sageLight = Color(hex: 0xD8E6D3)
}

func sans(_ size: CGFloat, _ weight: String = "Regular") -> Font { .custom("DMSans-\(weight)", size: size) }
func mono(_ size: CGFloat) -> Font { .custom("DMMono-Regular", size: size) }
func heading(_ size: CGFloat) -> Font { .custom(size >= 32 ? "BricolageGrotesque96pt-ExtraBold" : "BricolageGrotesque24pt-Bold", size: size) }

struct Meta: View {
    let text: String
    var color = Color.inkMuted
    var body: some View { Text(text.uppercased()).font(mono(11)).tracking(1.4).foregroundStyle(color) }
}

// MARK: - Daten

struct Dish: Hashable {
    var title: String
    var meta: String
    var tint: Color
}

struct Day: Hashable {
    var weekday: String
    var short: String
    var number: String
    var date: String
    var dishes: [Dish]
    var today = false
}

let week: [Day] = [
    Day(weekday: "Montag", short: "Mo", number: "2", date: "02.11.", dishes: [Dish(title: "Shakshuka", meta: "Abend · für zwei", tint: .butter)]),
    Day(weekday: "Dienstag", short: "Di", number: "3", date: "03.11.", dishes: []),
    Day(weekday: "Mittwoch", short: "Mi", number: "4", date: "04.11.", dishes: [
        Dish(title: "Linsensuppe", meta: "Mittag · für zwei", tint: .peach),
        Dish(title: "Ofengemüse mit Feta", meta: "Abend · 40 min · für zwei", tint: .sageLight),
    ]),
    Day(weekday: "Donnerstag", short: "Do", number: "5", date: "05.11.", dishes: [Dish(title: "Spaghetti Carbonara", meta: "Abend · 20 min · für zwei", tint: .butter)], today: true),
    Day(weekday: "Freitag", short: "Fr", number: "6", date: "06.11.", dishes: []),
    Day(weekday: "Samstag", short: "Sa", number: "7", date: "07.11.", dishes: []),
]

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
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("nomi").font(.custom("DynaPuff", size: 30)).fontWeight(.bold).foregroundStyle(.white)
                Spacer()
                Text("A").font(sans(16, "SemiBold")).foregroundStyle(.white)
                    .frame(width: 38, height: 38).background(.white.opacity(0.22), in: .circle)
            }
            HStack {
                Text("Diese Woche").font(heading(40)).foregroundStyle(.white)
                Spacer()
                ForEach(["chevron.left", "chevron.right"], id: \.self) { icon in
                    Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 32, height: 32).background(.white.opacity(0.18), in: .circle)
                }
            }
        }
        .padding(.horizontal, 22).padding(.top, 58).padding(.bottom, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brand, in: UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
    }
}

struct DishCard: View {
    var dish: Dish
    var compact = false
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10).fill(dish.tint)
                .frame(width: compact ? 42 : 48, height: compact ? 42 : 48)
                .overlay { Circle().stroke(Color.ink.opacity(0.7), lineWidth: 1.5).padding(12) }
            VStack(alignment: .leading, spacing: 3) {
                Text(dish.title).font(heading(16)).foregroundStyle(Color.ink).lineLimit(1)
                Meta(text: dish.meta)
            }
            Spacer(minLength: 0)
            Image(systemName: "ellipsis").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.inkMuted)
        }
        .padding(8)
        .background(Color.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline))
    }
}

struct Plus: View {
    var filled = Color.mist
    var body: some View {
        Image(systemName: "plus").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.ink)
            .frame(width: 28, height: 28).background(filled, in: .circle)
    }
}

struct TodayTag: View {
    var body: some View {
        Text("HEUTE").font(mono(10)).tracking(1.2).foregroundStyle(Color.canvas)
            .padding(.horizontal, 6).padding(.vertical, 2).background(Color.ink, in: .capsule)
    }
}

// MARK: - A: Tageskarten

struct VariantA: View {
    var body: some View {
        Phone {
            VStack(spacing: 0) {
                BrandTop()
                VStack(spacing: 10) {
                    ForEach(week, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Meta(text: "\(day.weekday) · \(day.date)", color: day.today ? .brand : .inkMuted)
                                if day.today { TodayTag() }
                                Spacer()
                                if day.dishes.isEmpty { Text("Noch nichts").font(sans(12)).foregroundStyle(Color.inkMuted.opacity(0.7)) }
                                Plus()
                            }
                            ForEach(day.dishes, id: \.self) { DishCard(dish: $0, compact: true) }
                        }
                        .padding(12)
                        .background(day.dishes.isEmpty ? Color.mist.opacity(0.55) : Color.surface.opacity(0.75), in: RoundedRectangle(cornerRadius: 18))
                        .overlay(RoundedRectangle(cornerRadius: 18).stroke(day.today ? Color.brand : .clear, lineWidth: 1.5))
                    }
                }
                .padding(.horizontal, 16).padding(.top, 16)
            }
        }
    }
}

// MARK: - B: Datumsspalte

struct VariantB: View {
    var body: some View {
        Phone {
            VStack(spacing: 0) {
                BrandTop()
                VStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                Text(day.short.uppercased()).font(mono(11)).tracking(1.2)
                                    .foregroundStyle(day.today ? Color.brand : Color.inkMuted)
                                Text(day.number).font(heading(26))
                                    .foregroundStyle(day.today ? Color.onBrandish : Color.ink)
                                    .frame(width: 42, height: 42)
                                    .background(day.today ? Color.brand : .clear, in: .circle)
                            }
                            .frame(width: 46)
                            VStack(alignment: .leading, spacing: 8) {
                                if day.dishes.isEmpty {
                                    HStack {
                                        Text("Noch nichts geplant").font(sans(14)).foregroundStyle(Color.inkMuted.opacity(0.75))
                                        Spacer()
                                        Plus()
                                    }
                                    .frame(minHeight: 42)
                                    .padding(.top, 14)
                                } else {
                                    ForEach(day.dishes, id: \.self) { DishCard(dish: $0, compact: true) }
                                    HStack(spacing: 6) {
                                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                                        Text("Gericht").font(sans(12, "Medium"))
                                    }
                                    .foregroundStyle(Color.inkMuted)
                                }
                            }
                            .padding(.top, day.dishes.isEmpty ? 0 : 14)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 60) }
                    }
                }
                .padding(.horizontal, 18).padding(.top, 6)
            }
        }
    }
}

extension Color { static let onBrandish = Color.white }

// MARK: - C: Kräftige Tagesköpfe

struct VariantC: View {
    var body: some View {
        Phone {
            VStack(spacing: 0) {
                BrandTop()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(day.weekday).font(heading(21)).foregroundStyle(day.today ? Color.brand : Color.ink)
                                Meta(text: day.date)
                                if day.today { TodayTag() }
                                Spacer()
                                Plus()
                            }
                            if day.dishes.isEmpty {
                                Text("Noch nichts geplant").font(sans(13)).foregroundStyle(Color.inkMuted.opacity(0.7))
                            }
                            ForEach(day.dishes, id: \.self) { DishCard(dish: $0, compact: true) }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(day.today ? Color.brand.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 16))
                        .overlay(alignment: .top) {
                            if day != week.first { Rectangle().fill(Color.ink.opacity(0.85)).frame(height: 2).padding(.horizontal, 14) }
                        }
                    }
                }
                .padding(.horizontal, 6).padding(.top, 10)
            }
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
                Text("Tage im Wochenplan").font(heading(40)).foregroundStyle(Color.ink)
                Text("Drei Wege, die Tage klarer zu trennen. Kopf und Gerichte-Karten bleiben, wie sie sind.")
                    .font(sans(17)).foregroundStyle(Color.inkMuted)
            }
            HStack(alignment: .top, spacing: 48) {
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "A", title: "Tageskarten", text: "Jeder Tag eine eigene Fläche. Leere Tage sind kleiner und grauer, heute hat einen Himbeer-Rand.")
                    VariantA()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "B", title: "Datumsspalte", text: "Wie ein Kalender: links groß der Tag, rechts die Gerichte. Heute steht im Himbeer-Kreis.", highlight: true)
                    VariantB()
                }
                VStack(alignment: .leading, spacing: 18) {
                    Caption(tag: "C", title: "Kräftige Köpfe", text: "Der Wochentag als Überschrift, dazwischen eine kräftige Linie. Heute leicht hinterlegt.")
                    VariantC()
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "star.fill").foregroundStyle(Color.ochre)
                Text("Empfehlung: B – die Spalte gibt jedem Tag einen klaren Anfang, man findet „heute“ sofort, und leere Tage bleiben schmal.")
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
