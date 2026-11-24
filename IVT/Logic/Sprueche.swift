import Foundation

/// Ein Spruch pro Tag, selbst geschrieben, fuer den Versandalltag.
enum Sprueche {

    static let alle = [
        "Die Palette ist nicht schief. Sie hat Charakter.",
        "Ladungssicherung ist wie Zähneputzen: Merkt man erst, wenn man es vergessen hat.",
        "Heute schon einen Spediteur pünktlich gesehen? Dann Lotto spielen.",
        "Stretchfolie hält mehr zusammen als manche Teams.",
        "Ein Lieferschein ohne Fehler ist wie ein Einhorn: schön, wenn man einen sieht.",
        "Doppelstock ist kein Lebensstil. Außer im Versand.",
        "Wer zuletzt lädt, lädt am längsten.",
        "Der Gabelstapler hat keine schlechte Laune. Nur leere Akkus. Zum Glück baut ihr die Ladegeräte.",
        "„Ist das eilig?“ – Im Versand ist alles eilig, was gestern hätte rausgehen sollen.",
        "Kaffee rein, Paletten raus.",
        "Ordnung ist das halbe Leben. Die andere Hälfte ist Packband suchen.",
        "Spediteur sagt 10 Uhr. Versand hört: irgendwann vor Feierabend.",
        "Ein guter Versandleiter sieht eine Lücke im Koffer, bevor sie entsteht.",
        "Wenn der Zug voll ist, ist er voll. Physik verhandelt nicht.",
        "Etiketten kleben immer da, wo man gerade nicht hinsieht.",
        "Heute wird nichts beschädigt. Außer vielleicht die Nerven.",
        "Die schnellste Palette ist die, die richtig beschriftet ist.",
        "Ein Zurrgurt zu viel hat noch nie jemanden geärgert. Einer zu wenig schon.",
        "Montag: Die Woche lädt. Bitte warten.",
        "Teamwork heißt: Einer hält, einer wickelt, einer filmt nicht.",
        "Der Spediteur ist nicht zu spät. Er ist nur sehr früh für morgen.",
        "Fehler im Fehlerbuch sind keine Schande. Fehler ohne Fehlerbuch schon.",
        "Wer sauber übergibt, wird im Urlaub nicht angerufen.",
        "Rampe frei, Kopf frei.",
        "72 Plätze. Kein einziger für Ausreden.",
        "Guter Versand fällt nicht auf. Schlechter steht auf der Autobahn.",
        "Heute ist ein guter Tag, um eine Anweisung zu schreiben, die keiner falsch verstehen kann.",
        "Die Waage lügt nicht. Der Lieferschein manchmal.",
        "Erst sichern, dann winken.",
        "Ein Plan ist gut. Ein Ladeplan ist besser.",
        "Wer Antirutschmatten belächelt, hat noch keine Notbremsung erlebt.",
        "Pausen sind auch Ladungssicherung. Für dich.",
        "Kein Stress: Es ist nur Versand. Ohne den würde allerdings gar nichts ankommen.",
        "Lob kostet nichts und wickelt keine Palette ab. Trotzdem verteilen.",
        "Die beste Tour ist die, nach der niemand anruft.",
        "Halbpaletten sind auch Paletten. Nur mit weniger Ego.",
        "Ein voller Koffer ist ein schöner Koffer.",
        "Heute einen Fehler verhindert? Ins Erfolgs-Logbuch damit.",
        "Wer fragt, lädt nicht falsch.",
        "Sicher geladen ist halb gefahren."
    ]

    static let freitag = [
        "Freitag. Der Zug fährt, du bald auch.",
        "Freitag: Heute wird nicht geschoben, heute wird verabschiedet.",
        "Kurzer Tag, klare Ansage: Alles raus, dann Wochenende.",
        "Freitag ist der Beweis, dass auch eine Woche irgendwann voll geladen ist."
    ]

    static func heute(_ datum: Date = Date(), kalender: Calendar = .current) -> String {
        let tag = kalender.ordinality(of: .day, in: .year, for: datum) ?? 1
        let jahr = kalender.component(.year, from: datum)
        if kalender.component(.weekday, from: datum) == 6 {
            return freitag[(tag + jahr) % freitag.count]
        }
        return alle[(tag * 7 + jahr) % alle.count]
    }
}
