import SwiftUI
import Supabase

/// Willkommen → E-Mail → Code, oder Willkommen → Einladung (ohne E-Mail).
/// Nach erfolgreicher Anmeldung übernimmt AppModel über authStateChanges.
struct SignInFlow: View {
    @State private var path: [Step] = []

    enum Step: Hashable {
        case email
        case code(email: String)
        case invite
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView { path.append(.email) } onInvite: { path.append(.invite) }
                .navigationDestination(for: Step.self) { step in
                    switch step {
                    case .email:
                        EmailStepView { path.append(.code(email: $0)) }
                    case .code(let email):
                        CodeStepView(email: email)
                    case .invite:
                        InviteStepView()
                    }
                }
        }
    }
}

struct EmailStepView: View {
    var onCodeSent: (String) -> Void

    @State private var email = ""
    @State private var isSending = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private var trimmed: String { email.trimmingCharacters(in: .whitespaces).lowercased() }
    private var isValid: Bool { trimmed.contains("@") && trimmed.contains(".") }

    var body: some View {
        FormScreen(
            eyebrow: "Anmelden",
            headline: ["Wie lautet", "deine E-Mail?"],
            text: "Wir schicken dir einen 6-stelligen Code. Kein Passwort nötig."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                TextField("name@beispiel.de", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.send)
                    .focused($focused)
                    .onSubmit(send)
                    .fieldBackground(isFocused: focused)
                InlineError(message: error)
            }
        } footer: {
            LoadingButton(title: "Code schicken", isLoading: isSending, isEnabled: isValid, action: send)
        }
        .onAppear { focused = true }
    }

    private func send() {
        guard isValid, !isSending else { return }
        isSending = true
        error = nil
        Task {
            defer { isSending = false }
            do {
                try await supabase.auth.signInWithOTP(email: trimmed)
                onCodeSent(trimmed)
            } catch {
                withAnimation { self.error = userMessage(for: error) }
            }
        }
    }
}

struct CodeStepView: View {
    let email: String

    @State private var code = ""
    @State private var isVerifying = false
    @State private var isResending = false
    @State private var resent = false
    @State private var error: String?
    @FocusState private var focused: Bool

    private let length = 6

    var body: some View {
        FormScreen(
            eyebrow: "Fast geschafft",
            headline: ["Code aus", "der Mail"],
            text: "Gesendet an \(email)."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                codeBoxes
                InlineError(message: error)
                Button(resent ? "Neuer Code ist unterwegs" : "Keinen Code bekommen? Neu schicken", action: resend)
                    .font(.captionSans)
                    .foregroundStyle(Color.inkMuted)
                    .underline(!resent)
                    .disabled(isResending || resent)
            }
        } footer: {
            LoadingButton(title: "Anmelden", isLoading: isVerifying, isEnabled: code.count == length, action: verify)
        }
        .onAppear { focused = true }
    }

    /// Ein unsichtbares Textfeld nimmt die Eingabe auf (inkl. Autofill aus Mail), die Kästchen zeigen sie an.
    private var codeBoxes: some View {
        ZStack {
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focused)
                .opacity(0.01)
                .accessibilityLabel("Code aus der Mail")
                .onChange(of: code) { _, new in
                    let digits = String(new.filter(\.isNumber).prefix(length))
                    if digits != new { code = digits }
                    if digits.count == length { verify() }
                }
            HStack(spacing: 8) {
                ForEach(0..<length, id: \.self) { index in
                    let chars = Array(code)
                    let isCurrent = focused && index == min(code.count, length - 1)
                    Text(index < chars.count ? String(chars[index]) : "")
                        .font(.custom("DMMono-Medium", size: 26, relativeTo: .title2))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.surface, in: .rect(cornerRadius: 14))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14)
                                .strokeBorder(isCurrent ? Color.ink : Color.hairline, lineWidth: isCurrent ? 1.5 : 1)
                        }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .onTapGesture { focused = true }
    }

    private func verify() {
        guard code.count == length, !isVerifying else { return }
        isVerifying = true
        error = nil
        Task {
            defer { isVerifying = false }
            do {
                try await supabase.auth.verifyOTP(email: email, token: code, type: .email)
            } catch {
                code = ""
                withAnimation { self.error = userMessage(for: error) }
            }
        }
    }

    private func resend() {
        isResending = true
        Task {
            defer { isResending = false }
            do {
                try await supabase.auth.signInWithOTP(email: email)
                resent = true
                error = nil
            } catch {
                withAnimation { self.error = userMessage(for: error) }
            }
        }
    }
}

/// Code aus WhatsApp/Nachricht: Name und Code genügen, das Konto entsteht dabei.
struct InviteStepView: View {
    @Environment(AppModel.self) private var app

    @State private var name = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var error: String?
    @FocusState private var focus: Field?

    enum Field { case name, code }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var normalizedCode: String { InviteCode.normalize(code) }
    private var isValid: Bool { !trimmedName.isEmpty && normalizedCode.count == InviteCode.length }

    var body: some View {
        FormScreen(
            eyebrow: "Einladung",
            headline: ["Schön, dass", "du da bist"],
            text: "Gib den Code aus der Nachricht ein. Eine E-Mail brauchst du nicht."
        ) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    MetaLabel("Code aus der Nachricht")
                    HStack(spacing: 10) {
                        TextField("XXXX-XXXX", text: $code)
                            .font(.custom("DMMono-Medium", size: 22, relativeTo: .title3))
                            .tracking(3)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($focus, equals: .code)
                            .onSubmit { focus = .name }
                            .onChange(of: code) { _, new in
                                // Eingefügte ganze Nachricht → nur der Code. Erst formatieren, wenn er vollständig ist –
                                // Umschreiben bei jedem Tastendruck verschluckt Zeichen.
                                guard let found = InviteCode.find(in: new) else { return }
                                let cleaned = InviteCode.format(found)
                                if cleaned != new { code = cleaned }
                                if trimmedName.isEmpty { focus = .name }
                            }
                            .fieldBackground(isFocused: focus == .code)
                        PasteButton(payloadType: String.self) { strings in
                            guard let text = strings.first, let found = InviteCode.find(in: text) else { return }
                            code = InviteCode.format(found)
                            focus = .name
                        }
                        .labelStyle(.iconOnly)
                        .buttonBorderShape(.circle)
                        .tint(Color.ink)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    MetaLabel("Wie heißt du?")
                    TextField("Vorname", text: $name)
                        .textContentType(.givenName)
                        .submitLabel(.join)
                        .focused($focus, equals: .name)
                        .onSubmit(submit)
                        .fieldBackground(isFocused: focus == .name)
                }

                InlineError(message: error)
            }
        } footer: {
            LoadingButton(title: "Los geht's", isLoading: isWorking, isEnabled: isValid, action: submit)
        }
        .onAppear { focus = .code }
    }

    private func submit() {
        guard isValid, !isWorking else { return }
        // Tastatur weg, damit eine Fehlermeldung sichtbar ist
        focus = nil
        isWorking = true
        error = nil
        Task {
            defer { isWorking = false }
            do {
                try await app.redeemInvite(code: normalizedCode, displayName: trimmedName)
            } catch {
                withAnimation { self.error = userMessage(for: error) }
            }
        }
    }
}

#Preview("E-Mail") {
    NavigationStack { EmailStepView { _ in } }
}

#Preview("Code") {
    NavigationStack { CodeStepView(email: "gregor@example.com") }
}
