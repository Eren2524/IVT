import Foundation

/// Lademeter mit frei eingegebenen Palettenmassen.
///
/// Zwei Zahlen, weil beide in der Praxis vorkommen:
///  - Formel: Laenge x Breite / 2,4 m je Stellplatz. So rechnen Spediteure ab.
///  - Real: wie lang die Ladung wirklich wird, wenn man Reihe fuer Reihe
///    ueber 2,40 m Breite stellt (laengs oder quer, was kuerzer ist).
enum Lademeter {

    static let ladebreite = 2.40    // m
    static let sattelLaenge = 13.6  // m, voller Sattelzug

    struct Posten: Identifiable, Equatable {
        var id = UUID()
        var name: String
        var laengeCm: Int
        var breiteCm: Int
        var anzahl: Int
        /// Darf eine zweite Palette darauf (Doppelstock)
        var stapelbar: Bool
        var gewichtKg: Double = 0

        var stellplaetze: Int {
            guard anzahl > 0 else { return 0 }
            return stapelbar ? Int((Double(anzahl) / 2).rounded(.up)) : anzahl
        }

        /// Lademeter je Stellplatz nach der Formel
        var ldmProPlatz: Double {
            (Double(laengeCm) / 100) * (Double(breiteCm) / 100) / ladebreite
        }

        var formelLDM: Double { Double(stellplaetze) * ldmProPlatz }

        var gewicht: Double { gewichtKg * Double(anzahl) }

        /// Beste Stellung: wie viele nebeneinander, wie tief eine Reihe ist
        var stellung: (nebeneinander: Int, tiefe: Double, quer: Bool)? {
            let l = Double(laengeCm) / 100, b = Double(breiteCm) / 100
            guard l > 0, b > 0 else { return nil }
            typealias Stellung = (nebeneinander: Int, tiefe: Double, quer: Bool)
            let laengs: Stellung = (Int((ladebreite + 0.001) / b), l, false)
            let quer: Stellung = (Int((ladebreite + 0.001) / l), b, true)
            let kandidaten: [Stellung] = [laengs, quer].filter { $0.nebeneinander > 0 }
            guard let erste = kandidaten.first else { return nil }
            var beste = erste
            for k in kandidaten.dropFirst()
            where k.tiefe / Double(k.nebeneinander) < beste.tiefe / Double(beste.nebeneinander) {
                beste = k
            }
            return beste
        }

        var reihen: Int {
            guard let s = stellung, stellplaetze > 0 else { return 0 }
            return Int((Double(stellplaetze) / Double(s.nebeneinander)).rounded(.up))
        }

        var realeLaenge: Double {
            guard let s = stellung else { return 0 }
            return Double(reihen) * s.tiefe
        }

        var zuBreit: Bool { laengeCm > 0 && breiteCm > 0 && stellung == nil }
    }

    struct Fahrzeug: Identifiable {
        var name: String
        /// Ladeflaechen; Gliederzug hat zwei
        var flaechen: [Double]
        var id: String { name }
        var gesamt: Double { flaechen.reduce(0, +) }
    }

    struct Vergleich: Identifiable {
        var fahrzeug: Fahrzeug
        var passt: Bool
        /// Freie Meter (negativ = so viel zu lang)
        var rest: Double
        /// Belegte Meter je Flaeche (fuer den Zug)
        var belegung: [Double]
        var id: String { fahrzeug.id }
    }

    struct Ergebnis {
        var formelLDM: Double
        var realeLaenge: Double
        var stellplaetze: Int
        var stueck: Int
        var gewicht: Double
        var vergleiche: [Vergleich]
        var zuBreit: [String]
    }

    static func fahrzeuge(kofferLaenge: Double, kofferAnzahl: Int) -> [Fahrzeug] {
        [
            Fahrzeug(name: "Zug (\(kofferAnzahl) × \(meter(kofferLaenge)))",
                     flaechen: Array(repeating: kofferLaenge, count: max(1, kofferAnzahl))),
            Fahrzeug(name: "Sattelzug 13,60 m", flaechen: [sattelLaenge]),
            Fahrzeug(name: "Motorwagen 7,20 m", flaechen: [7.2]),
            Fahrzeug(name: "7,5-Tonner 6,00 m", flaechen: [6.0]),
            Fahrzeug(name: "Transporter 4,20 m", flaechen: [4.2])
        ]
    }

    static func rechne(_ posten: [Posten], kofferLaenge: Double, kofferAnzahl: Int) -> Ergebnis {
        let gueltig = posten.filter { $0.anzahl > 0 && $0.laengeCm > 0 && $0.breiteCm > 0 }

        // Alle Reihen der Reihe nach, fuer das Verteilen auf mehrere Flaechen
        var reihenTiefen: [Double] = []
        for p in gueltig {
            guard let s = p.stellung else { continue }
            reihenTiefen += Array(repeating: s.tiefe, count: p.reihen)
        }

        let vergleiche = fahrzeuge(kofferLaenge: kofferLaenge, kofferAnzahl: kofferAnzahl).map { f in
            verteile(reihenTiefen, auf: f)
        }

        return Ergebnis(
            formelLDM: gueltig.reduce(0) { $0 + $1.formelLDM },
            realeLaenge: gueltig.reduce(0) { $0 + $1.realeLaenge },
            stellplaetze: gueltig.reduce(0) { $0 + $1.stellplaetze },
            stueck: gueltig.reduce(0) { $0 + $1.anzahl },
            gewicht: gueltig.reduce(0) { $0 + $1.gewicht },
            vergleiche: vergleiche,
            zuBreit: gueltig.filter(\.zuBreit).map(\.name)
        )
    }

    /// Reihen nacheinander auf die Flaechen stellen; eine Reihe wird nie geteilt.
    static func verteile(_ reihen: [Double], auf f: Fahrzeug) -> Vergleich {
        var belegung = Array(repeating: 0.0, count: f.flaechen.count)
        var index = 0
        var uebrig = 0.0
        for t in reihen {
            while index < f.flaechen.count && belegung[index] + t > f.flaechen[index] + 0.0001 {
                index += 1
            }
            if index < f.flaechen.count {
                belegung[index] += t
            } else {
                uebrig += t
            }
        }
        let frei = zip(f.flaechen, belegung).reduce(0) { $0 + ($1.0 - $1.1) }
        let passt = uebrig == 0
        return Vergleich(fahrzeug: f, passt: passt,
                         rest: passt ? frei : -uebrig, belegung: belegung)
    }

    static func meter(_ m: Double) -> String {
        String(format: "%.2f m", m).replacingOccurrences(of: ".", with: ",")
    }

    static func ldm(_ w: Double) -> String {
        String(format: "%.2f", w).replacingOccurrences(of: ".", with: ",")
    }

    /// Vorgaben zum schnellen Hinzufuegen
    static let vorgaben: [(name: String, l: Int, b: Int)] = [
        ("Europalette", 120, 80),
        ("Halbpalette", 80, 60),
        ("Viertelpalette", 60, 40),
        ("Industriepalette", 120, 100),
        ("Gitterbox", 124, 84)
    ]
}
