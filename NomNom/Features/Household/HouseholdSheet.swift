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

                    if let household = app.household, app.partner == nil {
                        InviteCard(code: household.inviteCode)
                    }

                    Button("Abmelden", role: .destructive) {
                        Task {
                            await app.signOut()
                            dismiss()
                        }
                    }
                    .font(.bodySansMedium)
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
        }
        .presentationDetents([.medium, .large])
    }
}

/// Zeigt den Einladungscode groß und bietet Teilen an.
struct InviteCard: View {
    let code: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MetaLabel("Einladungscode")
            Text(code)
                .font(.custom("DMMono-Medium", size: 34, relativeTo: .largeTitle))
                .tracking(6)
                .foregroundStyle(Color.ink)
                .textSelection(.enabled)
            Text("Die zweite Person installiert nomnom, meldet sich an und gibt diesen Code ein.")
                .font(.captionSans)
                .foregroundStyle(Color.inkMuted)
            ShareLink(
                item: "Komm in unseren nomnom-Haushalt! Einladungscode: \(code)"
            ) {
                Label("Code teilen", systemImage: "square.and.arrow.up")
                    .font(.bodySansMedium)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mist, in: .rect(cornerRadius: Metrics.cardRadius))
    }
}
