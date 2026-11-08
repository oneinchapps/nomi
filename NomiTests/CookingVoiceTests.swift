import Foundation
import Testing
@testable import nomi

struct CookingVoiceTests {
    @Test func weckwortInVerschiedenenSchreibweisen() {
        #expect(WakeWord.command(in: "Hey Nomi, weiter.") == "weiter")
        #expect(WakeWord.command(in: "hey naomi wie viel Salz?") == "wie viel Salz")
        #expect(WakeWord.command(in: "Okay nomie") == "")
        #expect(WakeWord.command(in: "Ähm, No mi zurück") == "zurück")
        #expect(WakeWord.command(in: "Wir brauchen noch Milch") == nil)
        // Das letzte Weckwort zählt
        #expect(WakeWord.command(in: "Hey nomi, äh, hey nomi, weiter") == "weiter")
        // Kein Treffer mitten im Wort
        #expect(WakeWord.command(in: "Ökonomie ist schwer") == nil)
    }

    @Test func kurzeBefehle() {
        #expect(CookingCommand.parse("weiter") == .next)
        #expect(CookingCommand.parse("Nächster Schritt bitte") == .next)
        #expect(CookingCommand.parse("zurück") == .back)
        #expect(CookingCommand.parse("Noch mal") == .repeatStep)
        #expect(CookingCommand.parse("lies den Schritt vor") == .repeatStep)
        #expect(CookingCommand.parse("Was brauch ich?") == .ingredients)
        #expect(CookingCommand.parse("Timer starten") == .startTimer)
        #expect(CookingCommand.parse("Stell den Timer") == .startTimer)
        #expect(CookingCommand.parse("Timer stopp") == .stopTimer)
        #expect(CookingCommand.parse("Timer pausieren") == .stopTimer)
        #expect(CookingCommand.parse("Wie lange noch?") == .timeLeft)
        #expect(CookingCommand.parse("Alles klar") == .okay)
        #expect(CookingCommand.parse("Stopp!") == .okay)
        #expect(CookingCommand.parse("Fertig") == .finish)
    }

    @Test func mengenfrageNimmtNurDieZutat() {
        #expect(CookingCommand.parse("Wie viel Salz?") == .amount("salz"))
        #expect(CookingCommand.parse("Wie viele Zwiebeln brauche ich?") == .amount("zwiebeln"))
        #expect(CookingCommand.parse("Wieviel Olivenöl kommt rein") == .amount("olivenöl"))
        #expect(CookingCommand.parse("Wie viel brauche ich?") == .ingredients)
    }

    @Test func laengereSaetzeSindFragen() {
        #expect(CookingCommand.parse("Kann ich statt Sahne Milch nehmen?") == .question("Kann ich statt Sahne Milch nehmen?"))
        // „weiter“ in einer echten Frage blättert nicht um
        #expect(CookingCommand.parse("Soll ich jetzt weiter rühren oder warten?") == .question("Soll ich jetzt weiter rühren oder warten?"))
        #expect(CookingCommand.parse("äh") == .unknown)
        #expect(CookingCommand.parse("") == .unknown)
    }

    @Test func zutatFinden() {
        let ingredients = [
            Ingredient(name: "Spaghetti", quantity: 200, unit: "g"),
            Ingredient(name: "Knoblauchzehen", quantity: 3, unit: nil),
            Ingredient(name: "rote Zwiebeln", quantity: 2, unit: nil),
            Ingredient(name: "Salz", quantity: nil, unit: nil),
            Ingredient(name: "Olivenöl", quantity: 4, unit: "EL"),
        ]
        #expect(Ingredient.best(matching: "salz", in: ingredients)?.name == "Salz")
        #expect(Ingredient.best(matching: "zwiebel", in: ingredients)?.name == "rote Zwiebeln")
        #expect(Ingredient.best(matching: "knoblauch", in: ingredients)?.name == "Knoblauchzehen")
        #expect(Ingredient.best(matching: "olivenol", in: ingredients)?.name == "Olivenöl")
        #expect(Ingredient.best(matching: "zucker", in: ingredients) == nil)
        #expect(ingredients[3].spokenAmount == "Salz nach Geschmack")
        #expect(ingredients[0].spokenAmount == "200 g Spaghetti")
    }

    @Test func befehlNachSprechpause() {
        var turn = VoiceTurn()
        let start = Date(timeIntervalSince1970: 0)
        #expect(turn.update(text: "Wir brauchen Salz", segment: 0, at: start) == nil)
        #expect(turn.update(text: "Hey Nomi", segment: 1, at: start) == .woke(""))
        #expect(turn.update(text: "Hey Nomi, wie viel", segment: 1, at: start + 0.5) == .heard("wie viel"))
        #expect(turn.tick(at: start + 1.0) == nil)
        #expect(turn.update(text: "Hey Nomi, wie viel Salz?", segment: 1, at: start + 1.2) == .heard("wie viel Salz"))
        #expect(turn.tick(at: start + 2.0) == nil)
        #expect(turn.tick(at: start + 2.5) == .command("wie viel Salz"))
        // Die endgültige Fassung desselben Segments löst nicht noch einmal aus
        #expect(turn.update(text: "Hey Nomi, wie viel Salz?", segment: 1, at: start + 3) == nil)
        #expect(turn.isAwake == false)
    }

    @Test func befehlUeberMehrereSegmente() {
        var turn = VoiceTurn()
        let start = Date(timeIntervalSince1970: 0)
        #expect(turn.update(text: "Hey Nomi.", segment: 4, at: start) == .woke(""))
        // Umgeschrieben ohne Weckwort: bleibt wie es war
        #expect(turn.update(text: "Hey", segment: 4, at: start + 0.2) == nil)
        #expect(turn.update(text: "Timer", segment: 5, at: start + 1) == .heard("Timer"))
        #expect(turn.update(text: "starten", segment: 6, at: start + 1.5) == .heard("Timer starten"))
        #expect(turn.tick(at: start + 3) == .command("Timer starten"))
    }

    @Test func ohneBefehlZurueckZumWarten() {
        var turn = VoiceTurn()
        let start = Date(timeIntervalSince1970: 0)
        _ = turn.update(text: "Hey nomi", segment: 0, at: start)
        #expect(turn.tick(at: start + 3) == nil)
        #expect(turn.tick(at: start + 8) == .timeout)
        #expect(turn.isAwake == false)
    }

    @Test func eigeneStimmeZaehltNicht() {
        var turn = VoiceTurn()
        let start = Date(timeIntervalSince1970: 0)
        turn.ignore(segment: 2)
        #expect(turn.update(text: "Schritt drei. Hey nomi, weiter", segment: 2, at: start) == nil)
        #expect(turn.update(text: "Hey nomi weiter", segment: 3, at: start) == .woke("weiter"))
    }

    @Test func antippenWecktOhneWeckwort() {
        var turn = VoiceTurn()
        let start = Date(timeIntervalSince1970: 0)
        turn.wake(at: start)
        #expect(turn.update(text: "zurück", segment: 0, at: start + 0.3) == .heard("zurück"))
        #expect(turn.tick(at: start + 2) == .command("zurück"))
    }

    @Test func restzeitZumVorlesen() {
        #expect(CookingFormat.spoken(270) == "4 Minuten 30 Sekunden")
        #expect(CookingFormat.spoken(600) == "10 Minuten")
        #expect(CookingFormat.spoken(3900) == "1 Stunde 5 Minuten")
        #expect(CookingFormat.spoken(41) == "41 Sekunden")
        #expect(CookingFormat.spoken(61) == "1 Minute 1 Sekunde")
        #expect(CookingFormat.spoken(0) == "0 Sekunden")
    }
}

struct CookingSpeechTests {
    @Test func abkuerzungenAusschreiben() {
        #expect(CookingSpeech.speakable("2 EL Öl und 200 g Mehl") == "2 Esslöffel Öl und 200 Gramm Mehl")
        #expect(CookingSpeech.speakable("Bei 180 °C ca. 20 Min. backen, 1,5 l Wasser") == "Bei 180 Grad circa 20 Min. backen, 1,5 Liter Wasser")
        #expect(CookingSpeech.speakable("½ TL Salz") == "½ Teelöffel Salz")
        // Nur direkt nach Zahlen – „g“ in Wörtern bleibt
        #expect(CookingSpeech.speakable("Gut umrühren, 3 Eier") == "Gut umrühren, 3 Eier")
        #expect(CookingSpeech.speakable("250g Quark") == "250 Gramm Quark")
    }

    @Test func aufzaehlung() {
        #expect(CookingSpeech.list([]) == "")
        #expect(CookingSpeech.list(["Salz"]) == "Salz")
        #expect(CookingSpeech.list(["Salz", "Pfeffer", "Öl"]) == "Salz, Pfeffer und Öl")
    }
}
