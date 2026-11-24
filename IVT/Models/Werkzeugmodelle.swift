import Foundation
import SwiftData

// MARK: - Eigene Palettenmasse (Lademeter-Rechner)

@Model
final class Palettenmass {
    var name: String
    var laengeCm: Int
    var breiteCm: Int
    /// Gewicht pro Stueck in kg, 0 = unbekannt
    var gewichtKg: Double
    var stapelbar: Bool
    var angelegt: Date

    init(name: String, laengeCm: Int, breiteCm: Int,
         gewichtKg: Double = 0, stapelbar: Bool = false) {
        self.name = name
        self.laengeCm = laengeCm
        self.breiteCm = breiteCm
        self.gewichtKg = gewichtKg
        self.stapelbar = stapelbar
        self.angelegt = Date()
    }
}

// MARK: - Sprachnotiz (Diktat mit Aufnahme)

@Model
final class Sprachnotiz {
    var angelegt: Date
    var text: String
    /// Dateiname im Dokumentenordner der App, nil wenn ohne Ton gespeichert
    var tonDatei: String?
    var dauer: Double

    init(text: String, tonDatei: String?, dauer: Double) {
        self.angelegt = Date()
        self.text = text
        self.tonDatei = tonDatei
        self.dauer = dauer
    }

    var tonURL: URL? {
        guard let tonDatei else { return nil }
        return Ablage.ordner.appendingPathComponent(tonDatei)
    }
}

/// Ordner fuer Tonaufnahmen, bleibt auf dem iPhone.
enum Ablage {
    static var ordner: URL {
        let basis = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = basis.appendingPathComponent("Sprachnotizen", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

// MARK: - Vorlagen (Anweisungen, Protokolle, Leitfaeden ...)

@Model
final class Vorlagendokument {
    var artRoh: String
    var titel: String
    /// Was Enrique gesagt hat, unveraendert
    var rohtext: String
    /// Das fertige Dokument
    var ergebnis: String
    var angelegt: Date
    var geaendert: Date
    var mitClaude: Bool

    init(art: Dokumentart, titel: String, rohtext: String,
         ergebnis: String, mitClaude: Bool) {
        self.artRoh = art.rawValue
        self.titel = titel
        self.rohtext = rohtext
        self.ergebnis = ergebnis
        self.angelegt = Date()
        self.geaendert = Date()
        self.mitClaude = mitClaude
    }

    var art: Dokumentart { Dokumentart(rawValue: artRoh) ?? .eigene }
}

// MARK: - Erfolgs-Logbuch

@Model
final class Erfolg {
    var datum: Date
    var text: String
    var artRoh: String

    init(text: String, art: Erfolgsart, datum: Date = Date()) {
        self.datum = datum
        self.text = text
        self.artRoh = art.rawValue
    }

    var art: Erfolgsart { Erfolgsart(rawValue: artRoh) ?? .sonstiges }
}

enum Erfolgsart: String, CaseIterable, Identifiable {
    case geloest = "Problem gelöst"
    case gespart = "Zeit oder Geld gespart"
    case verbessert = "Ablauf verbessert"
    case lob = "Lob bekommen"
    case team = "Team weitergebracht"
    case sonstiges = "Sonstiges"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .geloest: return "wrench.and.screwdriver.fill"
        case .gespart: return "eurosign.circle.fill"
        case .verbessert: return "arrow.triangle.2.circlepath"
        case .lob: return "hand.thumbsup.fill"
        case .team: return "person.3.fill"
        case .sonstiges: return "star.fill"
        }
    }
}

// MARK: - Unterweisungen im Team

@Model
final class Unterweisung {
    var kennung: UUID
    var person: String
    var thema: String
    var datum: Date
    /// 12 = jaehrlich
    var intervallMonate: Int
    var notiz: String

    init(person: String, thema: String, datum: Date,
         intervallMonate: Int = 12, notiz: String = "") {
        self.kennung = UUID()
        self.person = person
        self.thema = thema
        self.datum = datum
        self.intervallMonate = intervallMonate
        self.notiz = notiz
    }

    var faellig: Date {
        Calendar.current.date(byAdding: .month, value: intervallMonate, to: datum) ?? datum
    }

    /// Tage bis faellig, negativ = ueberfaellig
    var restTage: Int {
        let k = Calendar.current
        return k.dateComponents([.day], from: k.startOfDay(for: Date()),
                                to: k.startOfDay(for: faellig)).day ?? 0
    }
}
