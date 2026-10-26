import SwiftUI

/// Rundes Initialen-Badge oben rechts, öffnet die Haushaltsübersicht.
struct ProfileButton: View {
    @Environment(AppModel.self) private var app
    @State private var showsSheet = false

    var body: some View {
        Button { showsSheet = true } label: {
            Text(app.me?.initials ?? "?")
                .font(.buttonSans)
                .foregroundStyle(Color.onBrand)
                .frame(width: 36, height: 36)
                .background(Color.onBrand.opacity(0.18), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Haushalt und Konto")
        .sheet(isPresented: $showsSheet) {
            HouseholdSheet()
        }
    }
}

struct HouseholdSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    /// Mitglied, das per Einladung ohne E-Mail beigetreten ist – kommt nur per neuem Code wieder rein
    @State private var partnerWithoutEmail = false
    @State private var showsRelogin = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        MetaLabel("Ihr zwei")
                        ForEach(app.members) { member in
                            HStack(spacing: 12) {
                                Text(member.initials)
                                    .font(.buttonSans)
                                    .frame(width: 40, height: 40)
                                    .background(Color.mist, in: .circle)
                                Text(member.displayName).font(.bodySansMedium)
                                if member.userId == app.userId {
                                    MetaLabel("Du")
                                }
                            }
                        }
                    }

                    if app.partner == nil {
                        InviteCard()
                    } else if let partner = app.partner, partnerWithoutEmail {
                        if showsRelogin {
                            InviteCard(member: partner)
                        } else {
                            Button("Neues Handy? Code für \(partner.displayName) schicken", systemImage: "iphone") {
                                withAnimation { showsRelogin = true }
                            }
                            .font(.bodySansMedium)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Button("Abmelden", role: .destructive) {
                            Task {
                                await app.signOut()
                                dismiss()
                            }
                        }
                        .font(.bodySansMedium)
                        if app.signedInWithoutEmail {
                            Text("Du bist per Einladung ohne E-Mail angemeldet. Nach dem Abmelden brauchst du einen neuen Code\(app.partner.map { " von \($0.displayName)" } ?? "").")
                                .font(.captionSans)
                                .foregroundStyle(Color.inkMuted)
                        }
                    }
                }
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Metrics.gutter)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(app.household?.name ?? "Haushalt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .refreshable { await app.loadHousehold() }
            .task { await app.loadHousehold() }
            .task(id: app.partner?.userId) {
                guard let partner = app.partner else { return }
                partnerWithoutEmail = await app.isInvitedAccount(partner.userId)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Einmal-Code zum Verschicken per WhatsApp oder Nachricht. Wer ihn eingibt, braucht keine E-Mail.
/// Mit `member` meldet der Code dieses Mitglied auf einem neuen Handy wieder an.
struct InviteCard: View {
    var member: HouseholdMember?

    @Environment(AppModel.self) private var app
    @State private var invite: HouseholdInvite?
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MetaLabel(member == nil ? "Einladung" : "Anmeldecode für \(member!.displayName)")
            Text(invite?.formattedCode ?? "XXXX-XXXX")
                .font(.custom("DMMono-Medium", size: 30, relativeTo: .largeTitle))
                .tracking(3)
                .foregroundStyle(Color.ink)
                .redacted(reason: invite == nil ? .placeholder : [])
                .textSelection(.enabled)
                .accessibilityIdentifier("invite-code")
            Text(explanation)
                .font(.captionSans)
                .foregroundStyle(Color.inkMuted)
            if let invite {
                ShareLink(item: message(for: invite)) {
                    Label(member == nil ? "Einladung verschicken" : "Code verschicken", systemImage: "paperplane")
                }
                .buttonStyle(PrimaryButtonStyle(showsArrow: false))
            }
            InlineError(message: error)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mist, in: .rect(cornerRadius: Metrics.cardRadius))
        .task(id: member?.userId) { await load() }
    }

    private var explanation: String {
        let validity = invite.map { " Gilt einmal, bis \(DayFormat.short($0.expiresAt))." } ?? ""
        return member == nil
            ? "Per WhatsApp oder Nachricht an die zweite Person. Sie tippt in nomi auf „Ich habe eine Einladung“ – ganz ohne E-Mail.\(validity)"
            : "Damit kommt \(member!.displayName) auf einem neuen Handy wieder ins eigene Konto.\(validity)"
    }

    private func message(for invite: HouseholdInvite) -> String {
        let steps = "Öffne nomi, tippe auf „Ich habe eine Einladung“ und gib diesen Code ein:\n\n\(invite.formattedCode)\n\nGilt bis \(DayFormat.short(invite.expiresAt))."
        if member == nil {
            let from = app.me.map { "\($0.displayName) lädt dich ein: " } ?? ""
            return "\(from)Lass uns zusammen in nomi aussuchen, was wir essen. \(steps)"
        }
        return "Damit kommst du auf deinem neuen Handy wieder in nomi. \(steps)"
    }

    private func load() async {
        do {
            invite = try await app.invite(for: member?.userId)
            error = nil
        } catch {
            self.error = userMessage(for: error)
        }
    }
}
