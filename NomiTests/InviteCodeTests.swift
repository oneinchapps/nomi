import Testing
@testable import nomi

struct InviteCodeTests {
    @Test func formatiertBeimTippen() {
        #expect(InviteCode.format("k7mp") == "K7MP")
        #expect(InviteCode.format("k7mp4") == "K7MP-4")
        #expect(InviteCode.format("K7MP-4QXR") == "K7MP-4QXR")
        #expect(InviteCode.format("K7MP-4QXR-zuviel") == "K7MP-4QXR")
    }

    @Test func findetCodeInEingefuegterNachricht() {
        let message = """
        Alex lädt dich ein: Lass uns zusammen in nomi aussuchen, was wir essen. Öffne nomi, tippe auf „Ich habe eine Einladung“ und gib diesen Code ein:

        K7MP-4QXR

        Gilt bis 02.11.
        """
        #expect(InviteCode.find(in: message) == "K7MP4QXR")
        #expect(InviteCode.find(in: " k7mp4qxr ") == "K7MP4QXR")
    }

    @Test func ignoriertTextOhneCode() {
        #expect(InviteCode.find(in: "Komm in unseren nomi-Haushalt!") == nil)
        // Kleinbuchstaben und verwechselbare Zeichen (O, I, 0, 1) kommen in Codes nicht vor
        #expect(InviteCode.find(in: "Treffen im Raum OI01-2345") == nil)
    }
}
