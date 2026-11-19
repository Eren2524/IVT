import Foundation
import SwiftData

// MARK: - Schicht

@Model
final class Schicht {
    var start: Date
    var ende: Date?
    /// true, wenn der Geofence sie gestartet hat (statt Hand)
    var automatischGestartet: Bool
    var automatischBeendet: Bool
    var notiz: String
    var schritte: Int

    @Relationship(deleteRule: .cascade, inverse: \Pause.schicht)
    var pausen: [Pause]

    @Relationship(deleteRule: .cascade, inverse: \Wegpunkt.schicht)
    var wegpunkte: [Wegpunkt]

    init(start: Date,
         ende: Date? = nil,
         automatischGestartet: Bool = false,
         automatischBeendet: Bool = false,
         notiz: String = "",
         schritte: Int = 0) {
        self.start = start
        self.ende = ende
        self.automatischGestartet = automatischGestartet
        self.automatischBeendet = automatischBeendet
        self.notiz = notiz
        self.schritte = schritte
        self.pausen = []
        self.wegpunkte = []
    }

    var laeuft: Bool { ende == nil }

    /// Anwesenheit von Kommen bis Gehen (ohne Pausenabzug)
    var anwesenheit: TimeInterval {
        (ende ?? Date()).timeIntervalSince(start)
    }

    /// Summe aller erfassten Pausen innerhalb der Schicht
    var pausenDauer: TimeInterval {
        pausen.reduce(0) { $0 + $1.dauer }
    }

    /// Bezahlte Arbeitszeit = Anwesenheit minus Pausen
    var arbeitszeit: TimeInterval {
        max(0, anwesenheit - pausenDauer)
    }

    /// Soll fuer den Wochentag dieser Schicht
    var soll: TimeInterval {
        Arbeitsplan.soll(am: start)
    }

    var saldo: TimeInterval {
        guard ende != nil else { return 0 }
        return arbeitszeit - soll
    }
}

// MARK: - Pause

enum PausenArt: String, Codable, CaseIterable {
    case fruehstueck = "Fruehstueck"
    case mittag = "Mittag"
    case zusatz = "Zusaetzlich"

    var anzeige: String {
        switch self {
        case .fruehstueck: return "Frühstückspause"
        case .mittag: return "Mittagspause"
        case .zusatz: return "Zusätzliche Pause"
        }
    }

    var symbol: String {
        switch self {
        case .fruehstueck: return "cup.and.saucer.fill"
        case .mittag: return "fork.knife"
        case .zusatz: return "pause.circle.fill"
        }
    }
}

@Model
final class Pause {
    var von: Date
    var bis: Date?
    var artRoh: String
    /// true, wenn die Stillstandserkennung sie vorgeschlagen hat
    var erkannt: Bool
    var schicht: Schicht?

    init(von: Date, bis: Date? = nil, art: PausenArt = .zusatz, erkannt: Bool = false) {
        self.von = von
        self.bis = bis
        self.artRoh = art.rawValue
        self.erkannt = erkannt
    }

    var art: PausenArt {
        get { PausenArt(rawValue: artRoh) ?? .zusatz }
        set { artRoh = newValue.rawValue }
    }

    var laeuft: Bool { bis == nil }

    var dauer: TimeInterval {
        max(0, (bis ?? Date()).timeIntervalSince(von))
    }
}

// MARK: - Wegpunkt (Route)

@Model
final class Wegpunkt {
    var zeit: Date
    var breite: Double
    var laenge: Double
    var genauigkeit: Double
    var schicht: Schicht?

    init(zeit: Date, breite: Double, laenge: Double, genauigkeit: Double) {
        self.zeit = zeit
        self.breite = breite
        self.laenge = laenge
        self.genauigkeit = genauigkeit
    }
}

// MARK: - Aufgabe / Notiz

enum Wiederholung: String, Codable, CaseIterable, Identifiable {
    case keine, taeglich, jedenMontag, woechentlich, monatsende, quartal

    var id: String { rawValue }

    var anzeige: String {
        switch self {
        case .keine: return "Einmalig"
        case .taeglich: return "Täglich"
        case .jedenMontag: return "Jeden Montag"
        case .woechentlich: return "Wöchentlich"
        case .monatsende: return "Monatsende"
        case .quartal: return "Quartalsweise"
        }
    }
}

@Model
final class Aufgabe {
    /// Stabile Kennung, damit geplante Mitteilungen wiedergefunden werden
    var kennung: String
    var titel: String
    var notiz: String
    var angelegt: Date
    var faellig: Date?
    var erledigtAm: Date?
    var wiederholungRoh: String
    /// Reine Notiz ohne Haken-Charakter
    var istNotiz: Bool

    init(titel: String,
         notiz: String = "",
         faellig: Date? = nil,
         wiederholung: Wiederholung = .keine,
         istNotiz: Bool = false) {
        self.kennung = UUID().uuidString
        self.titel = titel
        self.notiz = notiz
        self.angelegt = Date()
        self.faellig = faellig
        self.erledigtAm = nil
        self.wiederholungRoh = wiederholung.rawValue
        self.istNotiz = istNotiz
    }

    var wiederholung: Wiederholung {
        get { Wiederholung(rawValue: wiederholungRoh) ?? .keine }
        set { wiederholungRoh = newValue.rawValue }
    }

    var erledigt: Bool { erledigtAm != nil }

    var istUeberfaellig: Bool {
        guard let faellig, !erledigt else { return false }
        return faellig < Date()
    }
}

// MARK: - Schadensvorgang

@Model
final class Schadensvorgang {
    var titel: String
    var angelegt: Date
    var spediteur: String
    var lieferschein: String
    var notiz: String
    var abgeschlossen: Bool

    @Relationship(deleteRule: .cascade, inverse: \Schadensfoto.vorgang)
    var fotos: [Schadensfoto]

    init(titel: String,
         spediteur: String = "",
         lieferschein: String = "",
         notiz: String = "") {
        self.titel = titel
        self.angelegt = Date()
        self.spediteur = spediteur
        self.lieferschein = lieferschein
        self.notiz = notiz
        self.abgeschlossen = false
        self.fotos = []
    }
}

@Model
final class Schadensfoto {
    @Attribute(.externalStorage) var daten: Data
    var aufgenommen: Date
    var ortText: String
    var breite: Double?
    var laenge: Double?
    var bemerkung: String
    var vorgang: Schadensvorgang?

    init(daten: Data,
         aufgenommen: Date = Date(),
         ortText: String = "",
         breite: Double? = nil,
         laenge: Double? = nil,
         bemerkung: String = "") {
        self.daten = daten
        self.aufgenommen = aufgenommen
        self.ortText = ortText
        self.breite = breite
        self.laenge = laenge
        self.bemerkung = bemerkung
    }
}

// MARK: - Fehlerprotokollbuch

@Model
final class Fehlereintrag {
    var kategorie: String
    var notiz: String
    var zeit: Date
    var mitarbeiter: String
    @Attribute(.externalStorage) var foto: Data?

    init(kategorie: String,
         notiz: String = "",
         zeit: Date = Date(),
         mitarbeiter: String = "",
         foto: Data? = nil) {
        self.kategorie = kategorie
        self.notiz = notiz
        self.zeit = zeit
        self.mitarbeiter = mitarbeiter
        self.foto = foto
    }

    /// Quartal als "2026-Q4"
    var quartal: String { Fehlereintrag.quartal(von: zeit) }

    static func quartal(von datum: Date, kalender: Calendar = .current) -> String {
        let jahr = kalender.component(.year, from: datum)
        let monat = kalender.component(.month, from: datum)
        return "\(jahr)-Q\((monat - 1) / 3 + 1)"
    }
}

// MARK: - Ladeliste (Palettenrechner, gespeicherte Planung)

@Model
final class Ladeplan {
    var name: String
    var angelegt: Date
    var euroDoppelstock: Int
    var euroEinzeln: Int
    var halbDoppelstock: Int
    var halbEinzeln: Int

    init(name: String, ladung: Ladung) {
        self.name = name
        self.angelegt = Date()
        self.euroDoppelstock = ladung.euroDoppelstock
        self.euroEinzeln = ladung.euroEinzeln
        self.halbDoppelstock = ladung.halbDoppelstock
        self.halbEinzeln = ladung.halbEinzeln
    }

    var ladung: Ladung {
        Ladung(euroDoppelstock: euroDoppelstock,
               euroEinzeln: euroEinzeln,
               halbDoppelstock: halbDoppelstock,
               halbEinzeln: halbEinzeln)
    }
}
