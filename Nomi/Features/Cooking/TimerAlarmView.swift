import SwiftUI

/// Timer abgelaufen: Chefi hüpft hinter der Scheibe hoch, klopft zweimal ans Display, drückt Pfoten und Nase
/// ans Glas und winkt dann neben der Karte „Alles klar“. Entwurf: design/cooking/timer-alarm.png (Variante A).
struct TimerAlarmView: View {
    let title: String
    let detail: String?
    let dismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .hidden
    @State private var knocks = 0
    @State private var waveTilt = false
    @State private var winks = false

    private enum Phase { case hidden, rise, knock, press, wave }

    /// Fest dunkel, auch im Dunkelmodus (`Color.ink` wäre dort hell)
    private static let dim = Color(red: 0x26 / 255, green: 0x2B / 255, blue: 0x28 / 255)

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                Self.dim.opacity(phase == .hidden ? 0 : 0.6)
                chefi(in: size)
                glass(in: size)
                if phase == .wave {
                    card
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            // Wackeln bei jedem Klopfen
            .keyframeAnimator(initialValue: 0.0, trigger: knocks) { content, angle in
                content.rotationEffect(.degrees(angle)).offset(x: angle * 2)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(-2.5, duration: 0.05)
                    CubicKeyframe(2, duration: 0.07)
                    CubicKeyframe(-1, duration: 0.07)
                    CubicKeyframe(0, duration: 0.09)
                }
            }
        }
        .ignoresSafeArea()
        .sensoryFeedback(.impact(weight: .heavy), trigger: knocks)
        .task { await play() }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }

    // MARK: - Ablauf

    private func play() async {
        guard !reduceMotion else {
            phase = .wave
            return
        }
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { phase = .rise }
        await pause(0.55)
        withAnimation(.spring(duration: 0.3, bounce: 0.2)) { phase = .knock }
        for _ in 0..<2 {
            await pause(0.28)
            knocks += 1
        }
        await pause(0.5)
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) { phase = .press }
        knocks += 1
        await pause(0.85)
        withAnimation(.spring(duration: 0.55, bounce: 0.3)) { phase = .wave }
        // Winken, bis jemand „Alles klar“ tippt
        while !Task.isCancelled {
            await pause(0.45)
            withAnimation(.easeInOut(duration: 0.4)) { waveTilt.toggle() }
            if Int.random(in: 0..<4) == 0 {
                winks = true
                await pause(0.3)
                winks = false
            }
        }
    }

    private func pause(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    // MARK: - Chefi

    private func chefi(in size: CGSize) -> some View {
        // Breite und Lage des Gesichts je Phase: Chefi kommt von unten, ist mal riesig nah, mal klein und winkend.
        // Ausgerichtet am Gesicht (60 % von oben im Raster), damit es bei jeder Größe an der richtigen Stelle sitzt.
        let (widthFactor, faceY): (CGFloat, CGFloat) = switch phase {
        case .hidden: (1.5, size.height * 1.5)
        case .rise: (1.5, size.height * 0.97)
        case .knock: (1.3, size.height * 0.76)
        case .press: (2.1, size.height * 0.56)
        case .wave: (0.62, size.height * 0.4)
        }
        let width = size.width * widthFactor
        let height = width / ChefiView.aspectRatio
        let centerY = faceY - height * 0.1
        return ChefiView(
            spoonTilt: phase == .rise ? -0.5 : (phase == .wave ? -0.08 : -0.32),
            winks: winks,
            waves: phase == .wave,
            pawOnGlass: phase == .knock || phase == .press,
            mouth: phase == .knock ? .oh : .smile
        )
        .frame(width: width, height: height)
        .rotationEffect(.degrees(phase == .wave ? (waveTilt ? 4 : -4) : 0), anchor: .bottom)
        .position(x: size.width / 2, y: centerY)
    }

    // MARK: - Scheibe

    @ViewBuilder
    private func glass(in size: CGSize) -> some View {
        if phase == .knock || phase == .press {
            let pawWidth = size.width * (phase == .press ? 0.3 : 0.27)
            let paws: [CGPoint] = phase == .press
                // Über Augenhöhe und weit außen, damit das Gesicht frei bleibt
                ? [CGPoint(x: size.width * 0.15, y: size.height * 0.38), CGPoint(x: size.width * 0.85, y: size.height * 0.41)]
                : [CGPoint(x: size.width * 0.22, y: size.height * 0.4)]
            ForEach(paws.indices, id: \.self) { index in
                GlassPaw()
                    .frame(width: pawWidth)
                    // Platt gedrückt: bei jedem Klopfen kurz breiter
                    .keyframeAnimator(initialValue: 1.0, trigger: knocks) { content, squash in
                        content.scaleEffect(x: squash, y: 2 - squash)
                    } keyframes: { _ in
                        KeyframeTrack {
                            CubicKeyframe(1.15, duration: 0.06)
                            CubicKeyframe(1, duration: 0.18)
                        }
                    }
                    .position(paws[index])
                    .transition(.scale(scale: 1.4).combined(with: .opacity))
            }
            if phase == .knock {
                KnockRings(trigger: knocks)
                    .frame(width: pawWidth * 2.2, height: pawWidth * 2.2)
                    .position(paws[0])
                VStack(alignment: .leading, spacing: 4) {
                    if knocks >= 1 { knockWord.transition(.scale.combined(with: .opacity)) }
                    if knocks >= 2 { knockWord.padding(.leading, 24).transition(.scale.combined(with: .opacity)) }
                }
                .animation(.spring(duration: 0.25, bounce: 0.5), value: knocks)
                .position(x: size.width * 0.7, y: size.height * 0.24)
            }
        }
        // Spiegelung: zeigt, dass Chefi hinter Glas steckt
        if phase != .hidden {
            GlassShine()
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    private var knockWord: some View {
        Text("KLOPF")
            .font(.custom("DMMono-Medium", size: 26, relativeTo: .title2))
            .tracking(2)
            .foregroundStyle(.white)
            .accessibilityHidden(true)
    }

    // MARK: - Karte

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel("Timer fertig")
            Text(title)
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
                .accessibilityIdentifier("timer-alarm-title")
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.bodySans)
                    .foregroundStyle(Color.inkMuted)
                    .lineLimit(2)
            }
            Button("Alles klar", action: dismiss)
                .buttonStyle(PrimaryButtonStyle(showsArrow: false))
                .padding(.top, 8)
                .accessibilityIdentifier("timer-alarm-ok")
        }
        .padding(20)
        .background(Color.canvas, in: .rect(cornerRadius: 28))
        .padding(.horizontal, 14)
        .padding(.bottom, 34)
    }
}

/// Drei Bögen, die bei jedem Klopfen von der Pfote wegfliegen
private struct KnockRings: View {
    let trigger: Int

    var body: some View {
        ZStack {
            ForEach(0..<3) { index in
                ForEach([0.15, 1.15], id: \.self) { start in
                    Circle()
                        .trim(from: 0, to: 0.27)
                        .rotation(.radians(start * .pi))
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .padding(CGFloat(2 - index) * 18)
                        .opacity(0.9 - Double(index) * 0.25)
                }
            }
        }
        .keyframeAnimator(initialValue: RingState(), trigger: trigger) { content, state in
            content.scaleEffect(state.scale).opacity(state.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.scale) {
                CubicKeyframe(0.7, duration: 0.01)
                CubicKeyframe(1.15, duration: 0.4)
            }
            KeyframeTrack(\.opacity) {
                CubicKeyframe(1, duration: 0.01)
                CubicKeyframe(0, duration: 0.4)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    struct RingState {
        var scale = 1.0
        var opacity = 0.0
    }
}

/// Zwei schräge Lichtstreifen wie auf einer Glasscheibe
private struct GlassShine: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            Path { p in
                for (offset, width) in [(0.16, 0.12), (0.34, 0.04)] as [(CGFloat, CGFloat)] {
                    let x = w * offset
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x + w * width, y: 0))
                    p.addLine(to: CGPoint(x: x + w * width - h * 0.45, y: h))
                    p.addLine(to: CGPoint(x: x - h * 0.45, y: h))
                    p.closeSubpath()
                }
            }
            .fill(.white.opacity(0.1))
        }
        .accessibilityHidden(true)
    }
}
