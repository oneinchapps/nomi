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
            options: FunctionInvokeOptions(body: body, timeoutInterval: timeout),
            decoder: FunctionDecoding.decoder
        )
    } catch let FunctionsError.httpError(_, data) {
        let message = (try? JSONDecoder().decode(FunctionErrorBody.self, from: data))?.error
        throw FunctionError(message: message ?? fallbackMessage)
    }
}

/// Der Functions-Client dekodiert ohne Datumsformat; Postgres liefert Zeitstempel wie
/// „2026-10-25T21:14:33.123456+00:00“ (Mikrosekunden). Ohne eigenen Decoder scheitert jede Antwort,
/// die ein gespeichertes Rezept mit created_at enthält.
enum FunctionDecoding {
    nonisolated static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            guard let date = date(from: text) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unbekanntes Datum: \(text)")
            }
            return date
        }
        return decoder
    }

    nonisolated static func date(from text: String) -> Date? {
        // Nachkommastellen auf Millisekunden kürzen – mehr versteht ISO8601DateFormatter nicht zuverlässig
        let trimmed = text.replacingOccurrences(of: #"(\.\d{3})\d+"#, with: "$1", options: .regularExpression)
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return withFraction.date(from: trimmed) ?? plain.date(from: trimmed)
    }
}

/// Text für die Oberfläche – Function-Meldungen direkt, alles andere über userMessage(for:).
func displayMessage(for error: Error) -> String {
    (error as? FunctionError)?.message ?? userMessage(for: error)
}
