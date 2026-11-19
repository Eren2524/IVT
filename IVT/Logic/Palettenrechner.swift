import Foundation

// MARK: - Zug-Konfiguration

/// Der DSV-Zug, wie er taeglich bei IEB steht:
/// LKW mit Koffer plus baugleicher Anhaenger.
/// Pro Koffer 18 Bodenplaetze, darueber im zweiten Stock noch einmal 18.
/// Also 36 Stellplaetze je Koffer, 72 im ganzen Zug, davon 36 am Boden.
struct Zugkonfiguration: Codable, Equatable {
    var kofferAnzahl: Int = 2
    var bodenPlaetzeProKoffer: Int = 18
    /// Nebeneinander passen 3 Europaletten -> 6 Reihen je Koffer
    var breiteInPaletten: Int = 3
    var doppelstock: Bool = true

    static let standard = Zugkonfiguration()

    /// Bodenplaetze im ganzen Zug (= Anzahl Stapelsaeulen)
    var saeulen: Int { kofferAnzahl * bodenPlaetzeProKoffer }

    /// Plaetze im zweiten Stock
    var oberPlaetze: Int { doppelstock ? saeulen : 0 }

    var gesamtPlaetze: Int { saeulen + oberPlaetze }

    var reihenProKoffer: Int {
        guard breiteInPaletten > 0 else { return bodenPlaetzeProKoffer }
        return bodenPlaetzeProKoffer / breiteInPaletten
    }
}

// MARK: - Eingabe

enum Palettenart: String, Codable, CaseIterable, Identifiable {
    case euro, halb

    var id: String { rawValue }

    var anzeige: String {
        switch self {
        case .euro: return "Europalette"
        case .halb: return "Halbpalette"
        }
    }

    var kurz: String {
        switch self {
        case .euro: return "Euro"
        case .halb: return "Halb"
        }
    }

    /// Wie viele dieser Paletten teilen sich einen Stellplatz
    var proStellplatz: Int {
        switch self {
        case .euro: return 1
        case .halb: return 2
        }
    }
}

struct Ladeposition: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var bezeichnung: String = ""
    var anzahl: Int = 1
    var art: Palettenart = .euro
    /// Darf etwas darauf gestellt werden?
    var stapelbar: Bool = true
}

// MARK: - Ergebnis

struct Ladeergebnis {
    var konfiguration: Zugkonfiguration

    /// Benoetigte Stellplaetze, nach Stapelbarkeit getrennt
    var stellplaetzeStapelbar: Int
    var stellplaetzeNichtStapelbar: Int

    /// Tatsaechliche Belegung
    var bodenStapelbar: Int
    var bodenNichtStapelbar: Int
    var obenBelegt: Int

    /// Stellplaetze, die nicht mehr in den Zug passen
    var ueberhang: Int

    /// Hinweis, wenn Halbpaletten ungerade aufgehen
    var halbeReste: [String]

    var benoetigt: Int { stellplaetzeStapelbar + stellplaetzeNichtStapelbar }
    var untergebracht: Int { bodenStapelbar + bodenNichtStapelbar + obenBelegt }
    var passt: Bool { ueberhang == 0 }

    var bodenBelegt: Int { bodenStapelbar + bodenNichtStapelbar }
    var bodenFrei: Int { max(0, konfiguration.saeulen - bodenBelegt) }

    /// Oben nutzbar sind nur Saeulen mit stapelbarer Palette darunter
    var obenNutzbar: Int { konfiguration.doppelstock ? bodenStapelbar : 0 }
    var obenFrei: Int { max(0, obenNutzbar - obenBelegt) }

    /// Plaetze, die durch nicht stapelbare Ware blockiert sind
    var blockiert: Int {
        konfiguration.doppelstock ? bodenNichtStapelbar : 0
    }

    /// Wie viel noch zusaetzlich mitkann, wenn es stapelbar ist
    var nochMoeglichStapelbar: Int {
        // Jede freie Saeule nimmt unten + oben eine stapelbare Palette
        bodenFrei * (konfiguration.doppelstock ? 2 : 1) + obenFrei
    }

    /// Wie viel noch mitkann, wenn es NICHT stapelbar ist
    var nochMoeglichNichtStapelbar: Int {
        bodenFrei + obenFrei
    }

    /// Verteilung auf die Koffer, gleichmaessig
    var proKoffer: [Int] {
        let n = max(1, konfiguration.kofferAnzahl)
        let grund = untergebracht / n
        let rest = untergebracht % n
        return (0..<n).map { $0 < rest ? grund + 1 : grund }
    }
}

// MARK: - Rechner

struct Palettenrechner {

    static func rechne(_ positionen: [Ladeposition],
                       konfiguration: Zugkonfiguration = .standard) -> Ladeergebnis {

        var stapelbarStueck = 0
        var nichtStapelbarStueck = 0
        var halbStapelbar = 0
        var halbNicht = 0

        for p in positionen where p.anzahl > 0 {
            switch p.art {
            case .euro:
                if p.stapelbar { stapelbarStueck += p.anzahl }
                else { nichtStapelbarStueck += p.anzahl }
            case .halb:
                if p.stapelbar { halbStapelbar += p.anzahl }
                else { halbNicht += p.anzahl }
            }
        }

        // Halbpaletten werden paarweise auf einen Stellplatz gesetzt.
        // Gepaart wird nur innerhalb derselben Stapelbarkeit, damit keine
        // stapelbare Haelfte durch eine nicht stapelbare blockiert wird.
        var hinweise: [String] = []

        let slotsHalbStapelbar = (halbStapelbar + 1) / 2
        if halbStapelbar % 2 == 1 {
            hinweise.append("Eine stapelbare Halbpalette bleibt als halber Platz übrig.")
        }
        let slotsHalbNicht = (halbNicht + 1) / 2
        if halbNicht % 2 == 1 {
            hinweise.append("Eine nicht stapelbare Halbpalette bleibt als halber Platz übrig.")
        }

        let bedarfStapelbar = stapelbarStueck + slotsHalbStapelbar
        let bedarfNicht = nichtStapelbarStueck + slotsHalbNicht

        // Belegung: stapelbare Ware zuerst auf den Boden, denn nur darauf
        // laesst sich der zweite Stock nutzen.
        let saeulen = konfiguration.saeulen
        let bodenStapelbar = min(bedarfStapelbar, saeulen)
        let bodenNicht = min(bedarfNicht, saeulen - bodenStapelbar)

        let obenNutzbar = konfiguration.doppelstock ? bodenStapelbar : 0
        let restStapelbar = bedarfStapelbar - bodenStapelbar
        let restNicht = bedarfNicht - bodenNicht
        let obenBelegt = min(restStapelbar + restNicht, obenNutzbar)

        let ueberhang = (restStapelbar + restNicht) - obenBelegt

        return Ladeergebnis(
            konfiguration: konfiguration,
            stellplaetzeStapelbar: bedarfStapelbar,
            stellplaetzeNichtStapelbar: bedarfNicht,
            bodenStapelbar: bodenStapelbar,
            bodenNichtStapelbar: bodenNicht,
            obenBelegt: obenBelegt,
            ueberhang: max(0, ueberhang),
            halbeReste: hinweise
        )
    }
}
