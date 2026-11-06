import SwiftUI

/// Live einkaufen: Vollbild wie der Kochmodus, eine Seite pro Abteilung, nur Abhaken.
/// Der Bildschirm bleibt an, und die Liste gleicht sich zusätzlich zu Realtime alle paar Sekunden ab,
/// damit man zu zweit im Laden auch bei wackeligem Netz denselben Stand sieht.
struct LiveShoppingView: View {
    @Environment(ShoppingStore.self) private var shopping
    @Environment(RecipeStore.self) private var recipes
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @State private var page = 0
    @State private var presence = ShoppingPresence()

    /// Abgleich im Modus: Realtime kommt sofort, das hier fängt verpasste Änderungen auf
    private static let syncInterval: Duration = .seconds(3)

    private var pages: [LiveShopping.Page] { LiveShopping.pages(shopping.items, order: shopping.categoryOrder) }
    private var total: Int { shopping.items.count }
    private var done: Int { shopping.checkedItems.count }
    private var isFinished: Bool { shopping.hasLoaded && total > 0 && done == total }

    var body: some View {
        // NavigationStack nur für die Leiste: helle Statusleiste auf Himbeere, Schließen + Fortschritt
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.onBrand)
                                .frame(width: 36, height: 36)
                                .background(Color.onBrand.opacity(0.18), in: .circle)
                        }
                        .accessibilityLabel("Einkaufen beenden")
                        .accessibilityIdentifier("live-close")
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) {
                        MetaLabel("\(done) von \(total)", font: .eyebrow, tracking: 2)
                            .environment(\.onBrandSurface, true)
                            .fixedSize()
                            .contentTransition(.numericText())
                            .accessibilityIdentifier("live-progress")
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .brandNavigationBar()
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            if isFinished {
                finishedView
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if shopping.hasLoaded && pages.isEmpty {
                emptyView
            } else {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        pageView(page, index: index).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.smooth, value: page)
                bottomBar
            }
        }
        .animation(.smooth(duration: 0.35), value: isFinished)
        .background(Color.canvas.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: isFinished) { _, finished in finished }
        // Fällt eine Abteilung weg (alles gelöscht), nicht auf einer leeren Seite stehen bleiben
        .onChange(of: pages.count) { _, count in
            if page >= count { page = max(count - 1, 0) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await shopping.load() } }
        }
        .task {
            while !Task.isCancelled {
                do { try await Task.sleep(for: Self.syncInterval) } catch { break }
                await shopping.load()
            }
        }
        .task { await presence.run(householdId: shopping.householdId, userId: shopping.userId) }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: - Kopf & Fuß

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Einkaufen")
                    .font(.heading(22, relativeTo: .title3))
                if let subtitle {
                    Text(subtitle)
                        .font(.captionSans)
                        .opacity(0.85)
                }
            }
            ProgressView(value: Double(done), total: Double(max(total, 1)))
                .tint(Color.onBrand)
                .background(Color.onBrand.opacity(0.25), in: .capsule)
                .animation(.smooth, value: done)
            if !partners.isEmpty {
                presencePill
            }
        }
        .environment(\.onBrandSurface, true)
        .foregroundStyle(Color.onBrand)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 4)
        .padding(.bottom, 18)
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28)
                .fill(Color.brand)
                .padding(.top, -200)
        }
    }

    /// „Rewe · Abteilung 2 von 5“
    private var subtitle: String? {
        var parts: [String] = []
        if let store = shopping.activeStore { parts.append(store.name) }
        if !isFinished && pages.count > 0 { parts.append("Abteilung \(min(page, pages.count - 1) + 1) von \(pages.count)") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var partners: [HouseholdMember] {
        app.members.filter { presence.others.contains($0.userId) }
    }

    /// Zeigt, wer gerade auch im Modus ist
    private var presencePill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(red: 0.62, green: 0.89, blue: 0.63))
                .frame(width: 8, height: 8)
            ForEach(partners) { member in
                MemberAvatar(member: member, size: 22, onBrand: true)
            }
            Text("\(partners.map(\.displayName).formatted(.list(type: .and))) kauft mit")
                .font(.custom("DMSans-Medium", size: 14, relativeTo: .footnote))
        }
        .padding(.leading, 10)
        .padding(.trailing, 14)
        .padding(.vertical, 5)
        .background(Color.onBrand.opacity(0.14), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("live-presence")
        .transition(.opacity)
    }

    private var bottomBar: some View {
        HStack {
            roundButton("chevron.left", label: "Vorige Abteilung", id: "live-prev") {
                withAnimation { page -= 1 }
            }
            .opacity(page > 0 ? 1 : 0)
            .disabled(page == 0)
            Spacer()
            pageIndicator
            Spacer()
            roundButton("chevron.right", label: "Nächste Abteilung", id: "live-next", filled: true) {
                withAnimation { page += 1 }
            }
            .opacity(page < pages.count - 1 ? 1 : 0)
            .disabled(page >= pages.count - 1)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
    }

    /// Punkte für wenige Abteilungen; bei vielen reicht die Zahl, Punkte würden zu eng
    @ViewBuilder
    private var pageIndicator: some View {
        if pages.count <= 8 {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.brand : (pages[index].openCount == 0 ? Color.sage.opacity(0.5) : Color.hairline))
                        .frame(width: index == page ? 18 : 7, height: 7)
                }
            }
            .animation(.smooth, value: page)
            .accessibilityHidden(true)
        } else {
            MetaLabel("\(page + 1) / \(pages.count)")
        }
    }

    private func roundButton(_ icon: String, label: String, id: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(filled ? Color.onBrand : Color.ink)
                .frame(width: 54, height: 54)
                .background(filled ? Color.brand : Color.mist, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(id)
    }

    // MARK: - Seiten

    private func pageView(_ page: LiveShopping.Page, index: Int) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(page.category.name)
                    .font(.heading(34, relativeTo: .largeTitle))
                    .tracking(-0.5)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                MetaLabel(countLabel(page))
                    .padding(.top, 6)
                    .padding(.bottom, 10)
                ForEach(page.items) { item in
                    row(item, pageIndex: index)
                }
            }
            .padding(.horizontal, Metrics.gutter - 10)
            .padding(.top, 22)
            .padding(.bottom, 24)
        }
    }

    private func countLabel(_ page: LiveShopping.Page) -> String {
        let count = page.items.count
        let inCart = count - page.openCount
        let things = count == 1 ? "1 Ding" : "\(count) Dinge"
        return inCart == 0 ? things : "\(things) · \(inCart) im Wagen"
    }

    private func row(_ item: ShoppingItem, pageIndex: Int) -> some View {
        let highlighted = shopping.partnerHighlights.contains(item.id)
        return Button {
            toggle(item, pageIndex: pageIndex)
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .strokeBorder(item.checked ? Color.sage : Color.inkMuted.opacity(0.45), lineWidth: 2.5)
                    if item.checked {
                        Circle().fill(Color.sage)
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(Color.onBrand)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 32, height: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.custom("DMSans-Medium", size: 20, relativeTo: .title3))
                        .strikethrough(item.checked, color: .inkMuted)
                        .foregroundStyle(item.checked ? Color.inkMuted : Color.ink)
                    if !item.checked, let title = item.recipeId.flatMap({ recipes.recipe(id: $0)?.title }) {
                        Text("für \(title)")
                            .font(.captionSans)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                if item.checked, let by = checkedByPartner(item) {
                    Text(by.initials)
                        .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
                        .foregroundStyle(Color.onBrand)
                        .frame(width: 24, height: 24)
                        .background(Color.sage, in: .circle)
                        .accessibilityLabel("abgehakt von \(by.displayName)")
                }
                Text(item.amountText)
                    .font(.custom("DMSans-Medium", size: 17, relativeTo: .body))
                    .monospacedDigit()
                    .foregroundStyle(item.checked ? Color.inkMuted : Color.ink)
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 62)
            .background(highlighted ? Color.sage.opacity(0.18) : .clear, in: .rect(cornerRadius: 14))
            .overlay(alignment: .bottom) {
                if !highlighted {
                    Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 58)
                }
            }
            .contentShape(.rect)
            .animation(.smooth(duration: 0.3), value: item.checked)
            .animation(.smooth(duration: 0.4), value: highlighted)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: item.checked)
        .accessibilityIdentifier("live-item-\(item.name)")
        .accessibilityValue(item.checked ? "erledigt" : "offen")
    }

    private func checkedByPartner(_ item: ShoppingItem) -> HouseholdMember? {
        guard let id = item.checkedBy, id != shopping.userId else { return nil }
        return app.members.first { $0.userId == id }
    }

    /// Abhaken; wer das Letzte einer Abteilung abhakt, landet kurz danach in der nächsten mit Offenem.
    private func toggle(_ item: ShoppingItem, pageIndex: Int) {
        let completesPage = !item.checked && pages.indices.contains(pageIndex) && pages[pageIndex].openCount == 1
        Task { await shopping.toggle(item) }
        guard completesPage else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            guard page == pageIndex, let next = LiveShopping.nextOpenPage(after: pageIndex, in: pages) else { return }
            withAnimation { page = next }
        }
    }

    // MARK: - Ende

    private var finishedView: some View {
        VStack(spacing: 14) {
            Spacer()
            ReactionIllustration(reaction: .korb).frame(width: 130, height: 130)
            Text("Alles im Wagen!")
                .font(.display)
                .tracking(-1)
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
            Text(finishedText)
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
            VStack(spacing: 12) {
                Button("Fertig, Liste leeren") {
                    Task {
                        await shopping.clearChecked()
                        dismiss()
                    }
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("live-finish-clear")
                Button("Liste behalten") { dismiss() }
                    .buttonStyle(.secondary)
                    .accessibilityIdentifier("live-finish-keep")
            }
        }
        .padding(Metrics.gutter)
    }

    /// „12 Dinge, Sam hat 5 davon geholt.“
    private var finishedText: String {
        let things = total == 1 ? "1 Ding" : "\(total) Dinge"
        let byPartner = Dictionary(grouping: shopping.items.compactMap(\.checkedBy).filter { $0 != shopping.userId }) { $0 }
        guard let (id, ids) = byPartner.max(by: { $0.value.count < $1.value.count }),
              let member = app.members.first(where: { $0.userId == id }) else {
            return "\(things), alles drin."
        }
        return "\(things), \(member.displayName) hat \(ids.count) davon geholt."
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()
            ReactionIllustration(reaction: .ratlos).frame(width: 120, height: 120)
            Text("Die Liste ist leer.")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            Spacer()
            Button("Zurück zur Liste") { dismiss() }
                .buttonStyle(.secondary)
        }
        .padding(Metrics.gutter)
    }
}
