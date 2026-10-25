import Foundation
import Supabase

/// Fehler aus einer Edge Function mit deren deutscher Meldung („Das Rezept ließ sich nicht auslesen.“).
struct FunctionError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private struct FunctionErrorBody: Decodable {
    let error: String
}

/// Ruft eine Edge Function auf und dekodiert die Antwort. Fehlermeldungen der Function werden durchgereicht.
func callFunction<Response: Decodable>(
    _ name: String,
    body: some Encodable,
    timeout: TimeInterval = 90,
    fallbackMessage: String
) async throws -> Response {
    do {
        return try await supabase.functions.invoke(
            name,
            options: FunctionInvokeOptions(body: body, timeoutInterval: timeout)
        )
    } catch let FunctionsError.httpError(_, data) {
        let message = (try? JSONDecoder().decode(FunctionErrorBody.self, from: data))?.error
        throw FunctionError(message: message ?? fallbackMessage)
    }
}

/// Text für die Oberfläche – Function-Meldungen direkt, alles andere über userMessage(for:).
func displayMessage(for error: Error) -> String {
    (error as? FunctionError)?.message ?? userMessage(for: error)
}
