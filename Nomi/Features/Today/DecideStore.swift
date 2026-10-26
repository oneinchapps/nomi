import Foundation
import Observation
import Supabase

/// Die aktuelle Runde „Was essen wir?“ – Chat, Swipe-Stapel, Stimmen und Match, live für beide.
@Observable
final class DecideStore {
    let householdId: UUID
    let userId: UUID

    private(set) var session: DecideSession?
    private(set) var messages: [ChatMessage] = []
    private(set) var candidates: [SessionCandidate] = []
    private(set) var votes: [SessionVote] = []
    private(set) var isThinking = false
    private(set) var hasLoaded = false
    var error: String?
    /// Für „alle mögen es“ – kommt aus AppModel.members
    var memberCount = 1

    init(householdId: UUID, userId: UUID) {
        self.householdId = householdId
        self.userId = userId
    }

    // MARK: - Abgeleitet

    var menu: MenuState {
        MenuState(courses: session?.courses ?? [], candidates: candidates, votes: votes, memberCount: memberCount)
    }

    /// Meine noch nicht bewerteten Karten – bei Menüs ohne schon entschiedene Gänge.
    var myDeck: [SessionCandidate] { menu.deck(for: userId) }

    /// Match für ein einzelnes Gericht (nicht bei Menüs)
    var match: SessionCandidate? {
        guard session?.status == .matched, !menu.isMenu, let id = session?.matchedCandidateId else { return nil }
        return candidates.first { $0.id == id }
    }

    /// Fertiges Menü: alle Gänge entschieden
    var menuMatch: [(course: String, candidate: SessionCandidate)]? {
        guard session?.status == .matched, menu.isMenu else { return nil }
        return menu.dishes
    }

    /// Wie viele Karten eine andere Person noch vor sich hat.
    func remaining(for member: UUID) -> Int { menu.deck(for: member).count }

    // MARK: - Laden

    func load() async {
        do {
            let sessions: [DecideSession] = try await supabase
                .from("decide_sessions")
                .select()
                .eq("household_id", value: householdId)
                .neq("status", value: DecideSession.Status.closed.rawValue)
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            guard let current = sessions.first else {
                reset()
                hasLoaded = true
                return
            }
            async let messages: [ChatMessage] = supabase.from("chat_messages").select()
                .eq("session_id", value: current.id).order("created_at").execute().value
            async let candidates: [SessionCandidate] = supabase.from("session_candidates").select()
                .eq("session_id", value: current.id).order("position").execute().value
            async let votes: [SessionVote] = supabase.from("session_votes").select()
                .eq("session_id", value: current.id).execute().value
            (self.messages, self.candidates, self.votes) = try await (messages, candidates, votes)
            session = current
            error = nil
        } catch {
            self.error = userMessage(for: error)
        }
        hasLoaded = true
    }

    func observeChanges() async {
        await withTaskGroup(of: Void.self) { group in
            for table in ["decide_sessions", "chat_messages", "session_candidates", "session_votes"] {
                group.addTask {
                    await observeTable(table, householdId: self.householdId) { [weak self] in
                        await self?.load()
                    }
                }
            }
        }
    }

    // MARK: - Aktionen

    /// Nachricht an nomi; ohne Text nur neue Vorschläge holen.
    func send(_ text: String?) async {
        let content = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        do {
            let session = try await openSession()
            if !content.isEmpty {
                let message = ChatMessage(sessionId: session.id, householdId: householdId, userId: userId, content: content)
                messages.append(message)
                try await supabase.from("chat_messages").insert(message).execute()
            }
            isThinking = true
            defer { isThinking = false }
            let _: SuggestResponse = try await callFunction(
                "decide",
                body: ["action": "suggest", "session_id": session.id.uuidString],
                fallbackMessage: "nomi hat gerade keine Idee. Probier es gleich noch mal."
            )
            error = nil
        } catch {
            self.error = displayMessage(for: error)
        }
        await load()
    }

    func vote(_ candidate: SessionCandidate, liked: Bool) async {
        let vote = SessionVote(candidateId: candidate.id, sessionId: candidate.sessionId, householdId: householdId, userId: userId, liked: liked)
        votes.append(vote)
        do {
            try await supabase.from("session_votes").upsert(vote).execute()
        } catch {
            self.error = userMessage(for: error)
            await load()
        }
    }

    /// Macht aus der gematchten Idee ein Rezept in der Sammlung.
    func expand(_ candidate: SessionCandidate) async throws -> Recipe {
        struct Response: Decodable { let recipe: Recipe }
        let response: Response = try await callFunction(
            "decide",
            body: ["action": "expand", "candidate_id": candidate.id.uuidString],
            fallbackMessage: "Das Rezept ließ sich gerade nicht ausarbeiten."
        )
        await load()
        return response.recipe
    }

    /// Runde abschließen; die nächste Nachricht startet eine neue.
    func newRound() async {
        guard let session else { return }
        reset()
        do {
            try await supabase.from("decide_sessions")
                .update(["status": DecideSession.Status.closed.rawValue])
                .eq("id", value: session.id)
                .execute()
        } catch {
            self.error = userMessage(for: error)
        }
    }

    // MARK: - Intern

    private struct SuggestResponse: Decodable {
        let reply: String
    }

    private func openSession() async throws -> DecideSession {
        if let session, session.status == .open { return session }
        struct NewSession: Encodable { let household_id: UUID }
        let created: DecideSession = try await supabase
            .from("decide_sessions")
            .insert(NewSession(household_id: householdId))
            .select()
            .single()
            .execute()
            .value
        reset()
        session = created
        return created
    }

    private func reset() {
        session = nil
        messages = []
        candidates = []
        votes = []
    }
}
