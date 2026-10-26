import PhotosUI
import SwiftUI

/// Profilfoto (oder Initialen) oben rechts, öffnet die Haushaltsübersicht.
struct ProfileButton: View {
    @Environment(AppModel.self) private var app
    @State private var showsSheet = false

    var body: some View {
        Button { showsSheet = true } label: {
            MemberAvatar(member: app.me, size: 36, onBrand: true)
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
    @State private var confirmsDeletion = false
    @State private var isDeleting = false
    @State private var deletionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        MetaLabel("Ihr zwei")
                        ForEach(app.members) { member in
                            HStack(spacing: 12) {
                                if member.userId == app.userId {
                                    AvatarEditor(member: member)
                                } else {
                                    MemberAvatar(member: member, size: 48)
                                }
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

                    VStack(alignment: .leading, spacing: 6) {
                        Button(isDeleting ? "Konto wird gelöscht …" : "Konto löschen") { confirmsDeletion = true }
                            .font(.captionSans)
                            .foregroundStyle(Color.inkMuted)
                            .disabled(isDeleting)
                        InlineError(message: deletionError)
                    }
                    .confirmationDialog("Konto wirklich löschen?", isPresented: $confirmsDeletion, titleVisibility: .visible) {
                        Button("Konto endgültig löschen", role: .destructive) { deleteAccount() }
                        Button("Abbrechen", role: .cancel) {}
                    } message: {
                        Text(app.partner == nil
                             ? "Du bist allein im Haushalt. Gelöscht werden dein Konto und alles im Haushalt: Rezepte, Pläne, Einkaufsliste, Verlauf und Fotos."
                             : "Gelöscht werden dein Konto, dein Profilfoto und deine Nachrichten. Rezepte, Pläne und Listen bleiben für \(app.partner?.displayName ?? "die anderen") erhalten.")
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

extension HouseholdSheet {
    func deleteAccount() {
        isDeleting = true
        deletionError = nil
        Task {
            do {
                try await app.deleteAccount()
                dismiss()
            } catch {
                deletionError = displayMessage(for: error)
            }
            isDeleting = false
        }
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

/// Profilfoto eines Mitglieds als Kreis; ohne Foto die Initialen.
struct MemberAvatar: View {
    let member: HouseholdMember?
    var size: CGFloat = 40
    /// Auf Himbeere: Initialen weiß auf transparentem Weiß
    var onBrand = false

    var body: some View {
        ZStack {
            if let url = member?.avatarURL {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        initials
                    }
                }
                .accessibilityIdentifier("avatar-photo")
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay {
            if member?.avatarURL != nil {
                Circle().strokeBorder(onBrand ? Color.onBrand.opacity(0.7) : Color.hairline, lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }

    private var initials: some View {
        Text(member?.initials ?? "?")
            .font(size > 44 ? .heading(size * 0.42, relativeTo: .title3) : .buttonSans)
            .foregroundStyle(onBrand ? Color.onBrand : Color.ink)
            .frame(width: size, height: size)
            .background(onBrand ? Color.onBrand.opacity(0.18) : Color.mist, in: .circle)
    }
}

/// Eigenes Profilfoto: antippen zum Auswählen, Aufnehmen oder Entfernen.
struct AvatarEditor: View {
    let member: HouseholdMember

    @Environment(AppModel.self) private var app
    @State private var showsLibrary = false
    @State private var showsCamera = false
    @State private var selection: PhotosPickerItem?
    @State private var isUploading = false
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("Foto auswählen", systemImage: "photo.on.rectangle") { chooseFromLibrary() }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Foto aufnehmen", systemImage: "camera") { showsCamera = true }
                }
                if member.avatarURL != nil {
                    Button("Foto entfernen", systemImage: "trash", role: .destructive) { remove() }
                }
            } label: {
                MemberAvatar(member: member, size: 48)
                    .overlay(alignment: .bottomTrailing) {
                        Group {
                            if isUploading {
                                ProgressView().controlSize(.mini)
                            } else {
                                Image(systemName: "camera.fill").font(.system(size: 9, weight: .bold))
                            }
                        }
                        .foregroundStyle(Color.canvas)
                        .frame(width: 20, height: 20)
                        .background(Color.ink, in: .circle)
                        .overlay { Circle().strokeBorder(Color.canvas, lineWidth: 2) }
                        .offset(x: 3, y: 3)
                    }
            }
            .accessibilityLabel("Profilfoto ändern")
            .disabled(isUploading)
            if let error {
                Text(error).font(.captionSans).foregroundStyle(Color.tomato)
            }
        }
        .photosPicker(isPresented: $showsLibrary, selection: $selection, matching: .images)
        .onChange(of: selection) { _, item in
            guard let item else { return }
            selection = nil
            Task {
                guard let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else { return }
                upload(image)
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                showsCamera = false
                if let image { upload(image) }
            }
            .ignoresSafeArea()
        }
    }

    private func chooseFromLibrary() {
        #if DEBUG
        // UI-Tests: Die Fotoauswahl des Systems lässt sich nicht fernsteuern
        if let path = ProcessInfo.processInfo.environment["NOMI_TEST_PHOTOS"]?.split(separator: ",").first,
           let image = UIImage(contentsOfFile: String(path)) {
            upload(image)
            return
        }
        #endif
        showsLibrary = true
    }

    private func upload(_ image: UIImage) {
        isUploading = true
        error = nil
        Task {
            defer { isUploading = false }
            do {
                try await app.setAvatar(image)
            } catch {
                self.error = "Das Foto ließ sich nicht speichern. Probier es noch mal."
            }
        }
    }

    private func remove() {
        Task {
            do {
                try await app.removeAvatar()
            } catch {
                self.error = "Das Foto ließ sich nicht entfernen."
            }
        }
    }
}
