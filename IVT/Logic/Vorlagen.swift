import Foundation

/// Alle Dokumentarten, die Enrique per Sprache anlegen kann.
enum Dokumentart: String, CaseIterable, Identifiable {
    case arbeitsanweisung = "Arbeitsanweisung"
    case anleitung = "Anleitung (Schritt für Schritt)"
    case leitfaden = "Leitfaden"
    case protokoll = "Protokoll"
    case aenderung = "Änderungsmitteilung"
    case checkliste = "Checkliste"
    case uebergabe = "Übergabe / Vertretung"
    case unterweisung = "Unterweisung"
    case vorfall = "Vorfallsbericht"
    case eigene = "Freies Dokument"

    var id: String { rawValue }

    var kurz: String {
        switch self {
        case .anleitung: return "Anleitung"
        case .uebergabe: return "Übergabe"
        default: return rawValue
        }
    }

    var symbol: String {
        switch self {
        case .arbeitsanweisung: return "list.bullet.clipboard.fill"
        case .anleitung: return "hand.point.up.left.fill"
        case .leitfaden: return "signpost.right.fill"
        case .protokoll: return "text.bubble.fill"
        case .aenderung: return "arrow.triangle.2.circlepath.circle.fill"
        case .checkliste: return "checklist.checked"
        case .uebergabe: return "person.2.wave.2.fill"
        case .unterweisung: return "person.badge.shield.checkmark.fill"
        case .vorfall: return "exclamationmark.bubble.fill"
        case .eigene: return "doc.text.fill"
        }
    }

    var farbe: String {
        switch self {
        case .arbeitsanweisung, .anleitung: return "blue"
        case .leitfaden, .unterweisung: return "green"
        case .protokoll, .uebergabe: return "indigo"
        case .aenderung: return "orange"
        case .checkliste: return "teal"
        case .vorfall: return "red"
        case .eigene: return "gray"
        }
    }

    /// Wofuer, in einem Satz
    var beschreibung: String {
        switch self {
        case .arbeitsanweisung: return "Wie eine Tätigkeit im Versand gemacht wird, verbindlich."
        case .anleitung: return "Programm oder Gerät bedienen: wo klicken, wo finden."
        case .leitfaden: return "Grundsätze und Vorgehen für wiederkehrende Situationen."
        case .protokoll: return "Besprechung oder Gespräch festhalten, mit Aufgaben."
        case .aenderung: return "Was ab wann anders läuft und was jeder tun muss."
        case .checkliste: return "Punkte zum Abhaken, z. B. vor der Abfahrt."
        case .uebergabe: return "Alles, was die Vertretung wissen muss, wenn du weg bist."
        case .unterweisung: return "Sicherheitsunterweisung mit Gefahren und Maßnahmen."
        case .vorfall: return "Was ist passiert, Ursache, Maßnahmen."
        case .eigene: return "Alles andere, Claude oder die App finden die Form."
        }
    }

    /// Was Enrique beim Reden erzaehlen sollte
    var sprechhilfe: [String] {
        switch self {
        case .arbeitsanweisung:
            return ["Wofür ist das und wann macht man es?",
                    "Was braucht man dafür (Programm, Werkzeug, Papiere)?",
                    "Jeden Schritt der Reihe nach: was du machst, wo, womit.",
                    "Worauf man achten muss, was oft schiefgeht.",
                    "Wen man fragt, wenn es nicht klappt."]
        case .anleitung:
            return ["Welches Programm oder Gerät, und was am Ende rauskommen soll.",
                    "Wo du anfängst: welches Fenster, welcher Menüpunkt.",
                    "Jeden Klick und jede Eingabe: worauf du drückst, was du einträgst.",
                    "Wo man etwas findet, wenn es nicht direkt zu sehen ist.",
                    "Woran man erkennt, dass es geklappt hat."]
        case .leitfaden:
            return ["Für welche Situation ist der Leitfaden?",
                    "Was ist dir dabei wichtig, was sind die Regeln?",
                    "Wie geht man typischerweise vor?",
                    "Was soll man auf keinen Fall machen?"]
        case .protokoll:
            return ["Worum ging es, wann, wer war dabei?",
                    "Was wurde besprochen, Punkt für Punkt?",
                    "Was wurde entschieden?",
                    "Wer macht was bis wann?"]
        case .aenderung:
            return ["Was ändert sich genau?",
                    "Ab wann gilt das?",
                    "Warum wird es geändert?",
                    "Wer ist betroffen und was muss jeder jetzt anders machen?"]
        case .checkliste:
            return ["Wofür ist die Checkliste?",
                    "Zähl alle Punkte auf, die geprüft werden müssen, in der richtigen Reihenfolge."]
        case .uebergabe:
            return ["Für wann und für wen ist die Übergabe?",
                    "Was läuft gerade, was ist offen?",
                    "Welche Termine, Abholungen, Spediteure stehen an?",
                    "Wo liegt was, welche Zugänge oder Ordner braucht man?",
                    "Wen ruft man bei Problemen an?"]
        case .unterweisung:
            return ["Zu welchem Thema, für wen?",
                    "Welche Gefahren gibt es?",
                    "Welche Schutzmaßnahmen und Regeln gelten?",
                    "Was tun im Notfall?"]
        case .vorfall:
            return ["Was ist passiert, wann und wo?",
                    "Wer war beteiligt, gab es Schaden?",
                    "Was war die Ursache, soweit bekannt?",
                    "Was wurde sofort gemacht, was muss noch passieren?"]
        case .eigene:
            return ["Erzähl einfach, worum es geht und für wen es ist."]
        }
    }

    /// Gliederung des fertigen Dokuments
    var abschnitte: [String] {
        switch self {
        case .arbeitsanweisung:
            return ["Zweck", "Geltungsbereich", "Zuständig", "Benötigt", "Arbeitsschritte",
                    "Darauf achten", "Bei Problemen"]
        case .anleitung:
            return ["Ziel", "Voraussetzungen", "Schritte", "So prüfst du das Ergebnis", "Häufige Fehler"]
        case .leitfaden:
            return ["Wofür", "Grundsätze", "Vorgehen", "Nicht machen", "Ansprechpartner"]
        case .protokoll:
            return ["Anlass", "Datum und Teilnehmer", "Besprochen", "Entscheidungen",
                    "Aufgaben (Wer – Was – Bis wann)"]
        case .aenderung:
            return ["Was ändert sich", "Gültig ab", "Grund", "Betroffen", "Was ist zu tun",
                    "Ansprechpartner"]
        case .checkliste:
            return ["Wofür", "Prüfpunkte"]
        case .uebergabe:
            return ["Zeitraum und Vertretung", "Laufende Vorgänge", "Termine und Abholungen",
                    "Wo liegt was", "Wichtige Kontakte", "Offene Punkte"]
        case .unterweisung:
            return ["Thema und Zielgruppe", "Gefährdungen", "Schutzmaßnahmen und Regeln",
                    "Verhalten im Notfall", "Bestätigung der Unterweisung"]
        case .vorfall:
            return ["Was ist passiert", "Zeit und Ort", "Beteiligte und Schaden", "Ursache",
                    "Sofortmaßnahmen", "Weitere Maßnahmen"]
        case .eigene:
            return ["Inhalt"]
        }
    }

    /// In welchen Abschnitt der gesprochene Ablauf ohne KI gehoert
    var hauptabschnitt: String {
        switch self {
        case .arbeitsanweisung: return "Arbeitsschritte"
        case .anleitung: return "Schritte"
        case .leitfaden: return "Vorgehen"
        case .protokoll: return "Besprochen"
        case .aenderung: return "Was ändert sich"
        case .checkliste: return "Prüfpunkte"
        case .uebergabe: return "Laufende Vorgänge"
        case .unterweisung: return "Schutzmaßnahmen und Regeln"
        case .vorfall: return "Was ist passiert"
        case .eigene: return "Inhalt"
        }
    }

    var nummeriert: Bool {
        switch self {
        case .arbeitsanweisung, .anleitung, .leitfaden: return true
        default: return false
        }
    }
}

/// Macht aus gesprochenem Text ein ordentliches Dokument.
/// Ohne Internet: Fuellwoerter raus, in Schritte teilen, in die Gliederung setzen.
/// Mit Claude: echtes Umschreiben (siehe Claudedienst).
enum Vorlagenschreiber {

    struct Kopf {
        var titel: String
        var art: Dokumentart
        var ersteller: String
        var firma: String
        var datum: Date = Date()
    }

    // MARK: Ohne Internet

    static func ordnen(_ roh: String, kopf: Kopf) -> String {
        let schritte = inSchritte(roh)
        var z: [String] = []
        z.append("# \(kopf.titel)")
        z.append("")
        z += kopfzeilen(kopf)
        z.append("")
        for abschnitt in kopf.art.abschnitte {
            z.append("## \(abschnitt)")
            if abschnitt == kopf.art.hauptabschnitt {
                if schritte.isEmpty { z.append("[ERGÄNZEN]") }
                for (i, s) in schritte.enumerated() {
                    switch kopf.art {
                    case .checkliste: z.append("☐ \(s)")
                    case _ where kopf.art.nummeriert: z.append("\(i + 1). \(s)")
                    default: z.append("- \(s)")
                    }
                }
            } else if abschnitt == "Bestätigung der Unterweisung" {
                z.append("Name, Datum, Unterschrift: ______________________________")
                z.append("Name, Datum, Unterschrift: ______________________________")
                z.append("Unterwiesen durch: \(kopf.ersteller)")
            } else {
                z.append("[ERGÄNZEN]")
            }
            z.append("")
        }
        return z.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func kopfzeilen(_ k: Kopf) -> [String] {
        ["Dokumentart: \(k.art.kurz)",
         "Bereich: Versand · \(k.firma)",
         "Erstellt von: \(k.ersteller)",
         "Stand: \(k.datum.datumKurz)",
         "Version: 1.0"]
    }

    static let fuellwoerter = [
        "äh", "ähm", "äähm", "öhm", "hm", "hmm", "halt", "sozusagen", "quasi", "gell",
        "irgendwie", "und so", "oder so", "weißt du", "weisst du", "ne\\?", "na ja", "naja", "okay", "ok"
    ]

    /// Verbinder, an denen ein neuer Schritt beginnt ("..., und dann ...")
    static let verbinder = "dann|danach|anschließend|als nächstes|jetzt"
    /// Zaehlwoerter am Satzanfang, die wegfallen
    static let aufzaehler = "zuerst|als erstes|erstens|zweitens|drittens|viertens|zum schluss|zuletzt|und zwar|dann|danach|anschließend|als nächstes|jetzt"

    /// Gesprochenen Text in einzelne, saubere Saetze bzw. Schritte teilen
    static func inSchritte(_ roh: String) -> [String] {
        var t = " " + roh.replacingOccurrences(of: "\n", with: ". ") + " "
        for w in fuellwoerter {
            t = t.replacingOccurrences(of: "(?i)[ ,]+\(w)(?=[ ,.!?])", with: "", options: .regularExpression)
        }
        // Neuer Schritt nach Komma oder "und": "..., dann klicke ich" -> ". klicke ich"
        t = t.replacingOccurrences(of: "(?i)(,\\s*|\\s+und\\s+)(\(verbinder))\\b,?", with: ".", options: .regularExpression)
        // Satzanfaenge: "also", "zuerst", "erstens" weg
        t = t.replacingOccurrences(of: "(?i)(^\\s*|[.!?]\\s*)(also|\(aufzaehler))\\b,?\\s*", with: "$1", options: .regularExpression)

        let teile = t.components(separatedBy: CharacterSet(charactersIn: ".!?;"))
        var schritte: [String] = []
        for teil in teile {
            var s = teil.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ",-")))
            // "ich" als erstes oder zweites Wort raus: "ich klicke" -> "Klicke", "gehe ich" -> "Gehe"
            s = s.replacingOccurrences(of: "(?i)^ich ", with: "", options: .regularExpression)
            s = s.replacingOccurrences(of: "(?i)^(\\p{L}+) ich ", with: "$1 ", options: .regularExpression)
            s = s.replacingOccurrences(of: "(?i)^(da|hier|dort) (\\p{L}+) ich ", with: "$1 $2 ", options: .regularExpression)
            guard s.count >= 3 else { continue }
            s = s.prefix(1).uppercased() + s.dropFirst()
            if !s.hasSuffix(":") { s += "." }
            if schritte.last != s { schritte.append(s) }
        }
        return schritte
    }

    // MARK: Mit Claude

    static func systemanweisung(_ k: Kopf) -> String {
        """
        Du bist Redakteur für betriebliche Dokumente in der Versandabteilung eines Industrieunternehmens (\(k.firma)). \
        Du bekommst ein frei gesprochenes, automatisch per Spracherkennung abgeschriebenes Diktat des Versandleiters. \
        Schreibe daraus ein Dokument der Art „\(k.art.kurz)“, das eine Person ohne Vorwissen genau befolgen kann, \
        wenn der Versandleiter nicht da ist.

        Regeln:
        - Deutsch, klar, kurze Sätze. Handlungsschritte in der Du-Form als Aufforderung („Öffne …“, „Klicke auf …“, „Trage … ein“).
        - Erfinde nichts. Verwende nur, was im Diktat steht. Fehlt etwas, das man zum Ausführen braucht \
        (welcher Menüpunkt, welche Menge, wer zuständig ist, wo etwas liegt), schreibe an die Stelle [ERGÄNZEN: konkrete Frage].
        - Offensichtliche Fehler der Spracherkennung korrigierst du, wenn der Sinn eindeutig ist. Wenn nicht eindeutig: [PRÜFEN: was gemeint sein könnte].
        - Füllwörter, Wiederholungen und Umwege weglassen. Die Reihenfolge der Schritte beibehalten.
        - Programme, Masken, Knöpfe, Menüs, Fächer und Orte genau so benennen, wie sie gesagt wurden, und in „…“ setzen.
        - Ein Schritt pro Nummer. Wenn ein Schritt eine Entscheidung enthält, schreibe „Wenn …, dann …“.
        - Gliederung mit diesen Abschnitten als „## “-Überschriften: \(k.art.abschnitte.joined(separator: ", ")). \
        Abschnitte, zu denen nichts gesagt wurde, die aber für dieses Dokument nötig sind, bekommen [ERGÄNZEN: …].
        - Format: nur Markdown mit #/## Überschriften, nummerierten Listen, „- “-Aufzählungen und **fett** für Warnungen. \
        \(k.art == .checkliste ? "Prüfpunkte beginnen mit „☐ “. " : "")Keine Tabellen, keine Emojis.
        - Antworte nur mit dem Dokument, ohne Einleitung oder Schlussbemerkung.

        Kopf des Dokuments, genau so beginnen:
        # \(k.titel)

        \(kopfzeilen(k).joined(separator: "\n"))
        """
    }

    static func nutzertext(_ roh: String) -> String {
        "Hier ist mein Diktat:\n\n\(roh)"
    }

    /// Wie viele Stellen noch ausgefuellt werden muessen
    static func luecken(_ text: String) -> Int {
        text.components(separatedBy: "[ERGÄNZEN").count - 1
            + text.components(separatedBy: "[PRÜFEN").count - 1
    }
}
