import Foundation
import Supabase

/// Ruft `onChange` bei jeder Änderung an `table` im Haushalt auf und läuft, bis die Task abgebrochen wird.
///
/// Insert/Update kommen gefiltert auf den Haushalt. Delete-Events lassen sich in Supabase Realtime
/// nicht filtern (gefilterte Abos bekommen sie gar nicht), deshalb ein zweites, ungefiltertes Abo:
/// es liefert nur die ID des gelöschten Eintrags und dient lediglich als Anstoß zum Neuladen.
func observeTable(
    _ table: String,
    householdId: UUID,
    onChange: @escaping @MainActor @Sendable () async -> Void
) async {
    let channel = supabase.channel("\(table)-\(householdId)")
    let changes = channel.postgresChange(
        AnyAction.self,
        table: table,
        filter: .eq("household_id", value: householdId)
    )
    let deletes = channel.postgresChange(DeleteAction.self, table: table)
    do {
        try await channel.subscribeWithError()
    } catch {
        return
    }

    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            for await _ in changes { await onChange() }
        }
        group.addTask {
            for await _ in deletes { await onChange() }
        }
    }
    await supabase.removeChannel(channel)
}
