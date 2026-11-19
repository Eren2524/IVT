import Foundation
import SwiftData

/// Alles, was einmal in der Woche an die Arbeitsmail geht.
struct Wochenbericht {
    var von: Date
    var bis: Date

    var schichten: [Schicht]
    var arbeitszeit: TimeInterval
    var soll: TimeInterval
    var kontoGesamt: TimeInterval
    var schritte: Int

    /// Aufgaben mit Termin in der kommenden Woche
    var termine: [Aufgabe]
    /// Alles, was noch offen ist
    var offeneAufgaben: [Aufgabe]
    /// In dieser Woche angelegte Aufgaben und Notizen
    var notizenDerWoche: [Aufgabe]

    var fehler: [Fehlereintrag]
    var schaeden: [Schadensvorgang]

    var saldo: TimeInterval { arbeitszeit - soll }

    var zeitraum: String { "\(von.datumKurz) bis \(bis.datumKurz)" }
    var kurzzeitraum: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "dd.MM."
        return "\(f.string(from: von))–\(bis.datumKurz)"
    }

    var fehlerRang: [(String, Int)] {
        var z: [String: Int] = [:]
        for e in fehler { z[e.kategorie, default: 0] += 1 }
        return z.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { ($0.key, $0.value) }
    }

    var istLeer: Bool {
        schichten.isEmpty && termine.isEmpty && offeneAufgaben.isEmpty
            && notizenDerWoche.isEmpty && fehler.isEmpty && schaeden.isEmpty
    }

    // MARK: Sammeln

    /// Baut den Bericht fuer die Woche, in der `datum` liegt.
    @MainActor
    static func sammeln(kontext: ModelContext,
                        um datum: Date = Date(),
                        kalender: Calendar = .current) -> Wochenbericht {

        let woche = kalender.dateInterval(of: .weekOfYear, for: datum)
            ?? DateInterval(start: datum, duration: 7 * 86400)
        let von = woche.start
        let bis = kalender.date(byAdding: .day, value: -1, to: woche.end) ?? woche.end
        let bisEnde = woche.end

        func hole<T: PersistentModel>(_ beschreibung: FetchDescriptor<T>) -> [T] {
            (try? kontext.fetch(beschreibung)) ?? []
        }

        // Schichten der Woche
        let schichten = hole(FetchDescriptor<Schicht>(
            predicate: #Predicate { $0.start >= von && $0.start < bisEnde },
            sortBy: [SortDescriptor(\.start)]
        ))

        // Soll nur fuer Tage, die schon vorbei sind
        var sollSumme: TimeInterval = 0
        var tag = von
        let heuteEnde = kalender.date(byAdding: .day, value: 1,
                                      to: kalender.startOfDay(for: datum)) ?? datum
        while tag < min(bisEnde, heuteEnde) {
            sollSumme += Arbeitsplan.soll(am: tag, kalender: kalender)
            tag = kalender.date(byAdding: .day, value: 1, to: tag) ?? bisEnde
        }

        // Ueberstundenkonto ueber alles
        let abgeschlossen = hole(FetchDescriptor<Schicht>(
            predicate: #Predicate { $0.ende != nil }
        ))

        // Termine der kommenden Woche
        let naechsteWoche = kalender.date(byAdding: .day, value: 7, to: bisEnde) ?? bisEnde
        // Nil-Coalescing statt Force-Unwrap: distantPast liegt vor jedem
        // Zeitraum, nicht terminierte Aufgaben fallen damit von selbst raus.
        let fern = Date.distantPast
        let termine = hole(FetchDescriptor<Aufgabe>(
            predicate: #Predicate {
                $0.erledigtAm == nil
                && ($0.faellig ?? fern) >= bisEnde
                && ($0.faellig ?? fern) < naechsteWoche
            },
            sortBy: [SortDescriptor(\.faellig)]
        ))

        let offen = hole(FetchDescriptor<Aufgabe>(
            predicate: #Predicate { $0.erledigtAm == nil },
            sortBy: [SortDescriptor(\.angelegt, order: .reverse)]
        ))

        let notizen = hole(FetchDescriptor<Aufgabe>(
            predicate: #Predicate { $0.angelegt >= von && $0.angelegt < bisEnde },
            sortBy: [SortDescriptor(\.angelegt)]
        ))

        let fehler = hole(FetchDescriptor<Fehlereintrag>(
            predicate: #Predicate { $0.zeit >= von && $0.zeit < bisEnde },
            sortBy: [SortDescriptor(\.zeit)]
        ))

        let schaeden = hole(FetchDescriptor<Schadensvorgang>(
            predicate: #Predicate { $0.angelegt >= von && $0.angelegt < bisEnde },
            sortBy: [SortDescriptor(\.angelegt)]
        ))

        // Termine sollen nicht doppelt auch unter "Offen" stehen
        let terminKennungen = Set(termine.map(\.kennung))

        return Wochenbericht(
            von: von,
            bis: bis,
            schichten: schichten,
            arbeitszeit: schichten.reduce(0) { $0 + $1.arbeitszeit },
            soll: sollSumme,
            kontoGesamt: abgeschlossen.reduce(0) { $0 + $1.saldo },
            schritte: schichten.reduce(0) { $0 + $1.schritte },
            termine: termine,
            offeneAufgaben: offen.filter { !terminKennungen.contains($0.kennung) },
            notizenDerWoche: notizen,
            fehler: fehler,
            schaeden: schaeden
        )
    }
}
