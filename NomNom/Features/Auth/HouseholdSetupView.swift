import SwiftUI

/// Nach dem ersten Login: Namen angeben und Haushalt anlegen oder per Code beitreten.
struct HouseholdSetupView: View {
    @Environment(AppModel.self) private var app

    enum Mode { case create, join }

    @State private var mode: Mode = .create
    @State private var name = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var error: String?
    @FocusState private var focus: Field?

    enum Field { case name, code }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var normalizedCode: String { code.uppercased().filter { $0.isLetter || $0.isNumber } }
    private var isValid: Bool {
        !trimmedName.isEmpty && (mode == .create || normalizedCode.count == 6)
    }

    var body: some View {
        FormScreen(
            eyebrow: "Euer Haushalt",
            headline: ["Schön, dass", "du da bist"],
            text: "nomnom gehört euch beiden. Eine Person legt den Haushalt an, die andere tritt mit dem Code bei."
        ) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    MetaLabel("Wie heißt du?")
                    TextField("Vorname", text: $name)
                        .textContentType(.givenName)
                        .submitLabel(.next)
                        .focused($focus, equals: .name)
                        .onSubmit { focus = mode == .join ? .code : nil }
                        .fieldBackground(isFocused: focus == .name)
                }

                VStack(spacing: 10) {
                    ChoiceCard(
                        title: "Neuen Haushalt anlegen",
                        detail: "Du bekommst einen Code zum Weitergeben.",
                        systemImage: "house",
                        isSelected: mode == .create
                    ) { select(.create) }
                    ChoiceCard(
                        title: "Ich habe einen Code",
                        detail: "Tritt dem Haushalt bei, der schon angelegt wurde.",
                        systemImage: "ticket",
                        isSelected: mode == .join
                    ) { select(.join) }
                }

                if mode == .join {
                    TextField("ABC123", text: $code)
                        .font(.custom("DMMono-Medium", size: 22, relativeTo: .title3))
                        .tracking(4)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .code)
                        .onChange(of: code) { _, new in
                            let cleaned = String(new.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
                            if cleaned != new { code = cleaned }
                        }
                        .fieldBackground(isFocused: focus == .code)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                InlineError(message: error)
            }
        } footer: {
            LoadingButton(
                title: mode == .create ? "Haushalt anlegen" : "Beitreten",
                isLoading: isWorking,
                isEnabled: isValid,
                action: submit
            )
        }
        .onAppear { focus = .name }
    }

    private func select(_ newMode: Mode) {
        withAnimation(.smooth(duration: 0.25)) {
            mode = newMode
            error = nil
        }
        if newMode == .join { focus = .code }
    }

    private func submit() {
        guard isValid, !isWorking else { return }
        isWorking = true
        error = nil
        Task {
            defer { isWorking = false }
            do {
                switch mode {
                case .create: try await app.createHousehold(displayName: trimmedName)
                case .join: try await app.joinHousehold(code: normalizedCode, displayName: trimmedName)
                }
            } catch {
                withAnimation { self.error = userMessage(for: error) }
            }
        }
    }
}

struct ChoiceCard: View {
    let title: String
    let detail: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 40, height: 40)
                    .background(Color.mist, in: .circle)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.bodySansMedium)
                    Text(detail).font(.captionSans).foregroundStyle(Color.inkMuted)
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isSelected ? Color.ink : Color.hairline)
            }
            .foregroundStyle(Color.ink)
            .padding(14)
            .background(Color.surface, in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(isSelected ? Color.ink : Color.hairline, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
