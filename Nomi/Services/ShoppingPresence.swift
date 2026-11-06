import Foundation
import Observation
import Supabase

/// Wer gerade im Live-Einkaufsmodus ist. Läuft über Realtime Presence, ohne Tabelle:
/// Jede Person meldet sich mit ihrer User-ID als Schlüssel an, beim Verlassen verschwindet sie von selbst.
@Observable
final class ShoppingPresence {
    /// Andere Mitglieder, die gerade mit einkaufen
    private(set) var others: Set<UUID> = []

    /// Läuft, bis die Task abgebrochen wird (also solange der Modus offen ist).
    func run(householdId: UUID, userId: UUID) async {
        let channel = supabase.channel("shopping-live-\(householdId)") { config in
            config.presence.key = userId.uuidString
        }
        let changes = channel.presenceChange()
        do {
            try await channel.subscribeWithError()
            try await channel.track(["user_id": userId.uuidString])
        } catch {
            await supabase.removeChannel(channel)
            return
        }
        // Der erste Eintrag ist der aktuelle Stand (alle Anwesenden als joins)
        for await change in changes {
            let joined = Set(change.joins.keys.compactMap(UUID.init(uuidString:)))
            let left = Set(change.leaves.keys.compactMap(UUID.init(uuidString:)))
            others = others.union(joined).subtracting(left).subtracting([userId])
        }
        others = []
        await channel.untrack()
        await supabase.removeChannel(channel)
    }
}
