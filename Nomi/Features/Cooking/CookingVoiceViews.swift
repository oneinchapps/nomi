import SwiftUI

/// Chefi lugt unten rechts über die Leiste, solange nomi zuhört (Entwurf B in design/cooking/sprachsteuerung.png).
/// Antippen hört auch ohne „Hey nomi“ zu; Antworten erscheinen in einer Blase daneben.
struct VoiceCorner: View {
    let voice: CookingVoice
    /// Auf der „Fertig“-Seite tanzt Chefi schon groß – dann nur die Blase
    var showsChefi = true
    /// Tipp auf Chefi (hört zu, ohne „Hey nomi“)
    var onChefiTap: () -> Void
    /// Nach dem Einschalten kurz zeigen, wie es geht
    @State private var showsHint = false

    private var isAnswering: Bool { voice.phase == .answering }

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            if let bubble {
                SpeechBubble(eyebrow: bubble.eyebrow, text: bubble.text, tail: .trailing)
                    // Nur die Blase selbst ist antippbar – sonst schnappte sie Chefi Tipps weg
                    .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onTapGesture {
                        // Bei einer Antwort heißt ein Tipp (auf Blase oder Chefi) „ich will was sagen“ –
                        // die Antwort verschwindet ohnehin, sobald sie vorgelesen ist
                        if isAnswering {
                            onChefiTap()
                        } else {
                            voice.clearProblem()
                            showsHint = false
                        }
                    }
                    .frame(maxWidth: 300, alignment: .trailing)
                    .accessibilityIdentifier(isAnswering ? "voice-reply" : "voice-hint")
                    .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }
            if voice.isOn && showsChefi {
                chefi
                    .zIndex(1)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.trailing, 14)
        .animation(.spring(duration: 0.45, bounce: 0.35), value: voice.phase)
        .animation(.spring(duration: 0.45, bounce: 0.35), value: showsHint)
        .onChange(of: voice.phase) { old, new in
            // Frisch eingeschaltet (nicht nach einer Antwort): kurz zeigen, wie es geht
            if new == .ready && [.off, .starting].contains(old) {
                showsHint = true
            } else if new != .ready {
                showsHint = false
            }
        }
        .task(id: showsHint) {
            guard showsHint else { return }
            try? await Task.sleep(for: .seconds(5))
            showsHint = false
        }
    }

    private var bubble: (eyebrow: String, text: String)? {
        switch voice.phase {
        case .starting: ("Moment", "nomi spitzt die Ohren …")
        case .answering: voice.reply.map { ("nomi", $0.display) }
        case .unavailable(let message): ("Hoppla", message)
        case .ready where showsHint: ("Hände frei", "Sag „Hey nomi, weiter“ – oder tipp auf mich.")
        default: nil
        }
    }

    private var chefi: some View {
        Button(action: onChefiTap) {
            ZStack(alignment: .topLeading) {
                ChefiView(spoonTilt: isAnswering ? -0.08 : -0.25, winks: isAnswering, eyes: isAnswering ? .happy : .open)
                    .frame(width: 72, height: 83)
                    // Steckt halb hinter der Leiste; bei einer Antwort hüpft er ganz hoch
                    .offset(y: isAnswering ? 0 : 26)
                    .frame(width: 72, height: 83, alignment: .top)
                    .clipped()
                Image(systemName: "mic.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.onBrand)
                    .frame(width: 22, height: 22)
                    .background(Color.brand, in: .circle)
                    .overlay(Circle().strokeBorder(Color.canvas, lineWidth: 2))
                    .offset(x: -6, y: isAnswering ? -4 : 18)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("nomi zuhören lassen")
        .accessibilityIdentifier("voice-chefi")
    }
}

/// Nach „Hey nomi“: Bild dimmt, der Rand leuchtet, Chefi springt hoch und zeigt, was er versteht.
struct VoiceListeningOverlay: View {
    let voice: CookingVoice
    var isActive: Bool

    private var isThinking: Bool { voice.phase == .thinking }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.canvas.opacity(0.84)
                .ignoresSafeArea()
                .contentShape(.rect)
                .onTapGesture { voice.dismiss() }
            if isActive {
                // Nur beim Zuhören – der Rand animiert sonst unsichtbar weiter
                ListeningGlow(level: isThinking ? 0.3 : voice.level)
            }
            VStack(alignment: .leading, spacing: -6) {
                SpeechBubble(
                    eyebrow: isThinking ? "Moment …" : "Ja?",
                    text: voice.heardText.isEmpty ? "Ich höre …" : "„\(voice.heardText)“",
                    tail: .leading,
                    level: isThinking ? nil : voice.level
                )
                .frame(maxWidth: 420, alignment: .leading)
                .padding(.leading, 96)
                .padding(.trailing, 20)
                .accessibilityIdentifier("voice-heard")
                ChefiView(spoonTilt: isThinking ? -0.1 : -0.5, spoonLift: isThinking ? 6 : 0, mouth: isThinking ? .smile : .oh)
                    .frame(width: 170, height: 196)
                    .accessibilityHidden(true)
            }
            .padding(.leading, 10)
            // Chefi springt von unten herein
            .offset(y: isActive ? 24 : 120)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isActive ? "voice-listening" : "")
    }
}

/// Himbeer-Ocker-Leuchten am Bildschirmrand, atmet mit der Lautstärke
struct ListeningGlow: View {
    var level: Float
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: reduceMotion || Self.isUITest)) { context in
            let angle = Angle.degrees(context.date.timeIntervalSinceReferenceDate * 60)
            let gradient = AngularGradient(
                colors: [.brand, Self.ochre, .brand, Self.blush, .brand],
                center: .center,
                angle: angle
            )
            let width = 10 + CGFloat(level) * 14
            ZStack {
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .strokeBorder(gradient, lineWidth: width)
                    .blur(radius: 16)
                RoundedRectangle(cornerRadius: 48, style: .continuous)
                    .strokeBorder(gradient, lineWidth: 4)
                    .blur(radius: 2)
            }
            .animation(.easeOut(duration: 0.15), value: level)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// UI-Tests warten auf Ruhe – ein ständig drehender Rand ließe jede Abfrage hängen
    private static var isUITest: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["NOMI_VOICE_TEST"] == "1"
        #else
        false
        #endif
    }

    private static let ochre = Color(red: 0xF2 / 255, green: 0xB3 / 255, blue: 0x3D / 255)
    private static let blush = Color(red: 0xF4 / 255, green: 0xA0 / 255, blue: 0xB5 / 255)
}

/// Sprechblase mit Spitze nach unten (links zu Chefi bzw. rechts zu Chefi)
struct SpeechBubble: View {
    enum Tail { case leading, trailing }

    let eyebrow: String
    let text: String
    let tail: Tail
    var level: Float?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Text(eyebrow.uppercased())
                    .font(.custom("DMMono-Medium", size: 12, relativeTo: .caption))
                    .tracking(1.2)
                    .foregroundStyle(Color.brand)
                if let level {
                    LevelBars(level: level)
                }
            }
            Text(text)
                .font(.custom("DMSans-Medium", size: 19, relativeTo: .title3))
                .foregroundStyle(Color.ink)
                // Vorgelesen wird alles; zu sehen ist höchstens so viel, dass der Schritt lesbar bleibt
                .lineLimit(7)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(alignment: tail == .leading ? .bottomLeading : .bottomTrailing) {
            ZStack(alignment: tail == .leading ? .bottomLeading : .bottomTrailing) {
                RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.surface)
                BubbleTail()
                    .fill(Color.surface)
                    .frame(width: 22, height: 16)
                    .scaleEffect(x: tail == .leading ? 1 : -1)
                    .offset(x: tail == .leading ? 22 : -22, y: 12)
            }
            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + 2, y: rect.maxY), control: CGPoint(x: rect.minX + rect.width * 0.5, y: rect.minY + rect.height * 0.4))
        path.closeSubpath()
        return path
    }
}

/// Sechs Balken, die mit der Lautstärke wippen
private struct LevelBars: View {
    var level: Float
    private let factors: [CGFloat] = [0.45, 0.8, 1, 0.65, 0.9, 0.4]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(factors.enumerated()), id: \.offset) { _, factor in
                Capsule()
                    .fill(Color.brand)
                    .frame(width: 3.5, height: 4 + 14 * factor * CGFloat(level))
            }
        }
        .frame(height: 18)
        .animation(.easeOut(duration: 0.12), value: level)
    }
}
