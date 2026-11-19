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

/// Die ganze Eingabe sind vier Zahlen. Keine Bezeichnungen, keine Listen:
/// im Hof zaehlt nur, wie viele Paletten welcher Art rausmuessen und
/// ob etwas darauf gestellt werden darf.
struct Ladung: Codable, Equatable {
    var euroDoppelstock: Int = 0
    var euroEinzeln: Int = 0
    var halbDoppelstock: Int = 0
    var halbEinzeln: Int = 0

    static let leer = Ladung()

    var paletten: Int { euroDoppelstock + euroEinzeln + halbDoppelstock + halbEinzeln }
    var istLeer: Bool { paletten == 0 }
}

// MARK: - Ergebnis

struct Ladeergebnis {
    var konfiguration: Zugkonfiguration
    var ladung: Ladung

    /// Benoetigte Stellplaetze, nach Stapelbarkeit getrennt
    var stellplaetzeDoppelstock: Int
    var stellplaetzeEinzeln: Int

    /// Tatsaechliche Belegung
    var bodenDoppelstock: Int
    var bodenEinzeln: Int
    var obenBelegt: Int

    /// Stellplaetze, die nicht mehr in den Zug passen
    var ueberhang: Int

    /// Hinweis, wenn Halbpaletten ungerade aufgehen
    var halbeReste: [String]

    var benoetigt: Int { stellplaetzeDoppelstock + stellplaetzeEinzeln }
    var untergebracht: Int { bodenDoppelstock + bodenEinzeln + obenBelegt }
    var passt: Bool { ueberhang == 0 }

    var bodenBelegt: Int { bodenDoppelstock + bodenEinzeln }
    var bodenFrei: Int { max(0, konfiguration.saeulen - bodenBelegt) }

    /// Oben nutzbar sind nur Saeulen mit doppelstockfaehiger Palette darunter
    var obenNutzbar: Int { konfiguration.doppelstock ? bodenDoppelstock : 0 }
    var obenFrei: Int { max(0, obenNutzbar - obenBelegt) }

    /// Plaetze, die durch nicht stapelbare Ware blockiert sind
    var blockiert: Int {
        konfiguration.doppelstock ? bodenEinzeln : 0
    }

    /// Wie viel noch zusaetzlich mitkann, wenn es doppelstockfaehig ist
    var nochMoeglichDoppelstock: Int {
        bodenFrei * (konfiguration.doppelstock ? 2 : 1) + obenFrei
    }

    /// Wie viel noch mitkann, wenn es NICHT stapelbar ist
    var nochMoeglichEinzeln: Int {
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

    static func rechne(_ ladung: Ladung,
                       konfiguration: Zugkonfiguration = .standard) -> Ladeergebnis {

        // Halbpaletten werden paarweise auf einen Stellplatz gesetzt.
        // Gepaart wird nur innerhalb derselben Stapelbarkeit, damit keine
        // doppelstockfaehige Haelfte durch eine nicht stapelbare blockiert wird.
        var hinweise: [String] = []

        let slotsHalbDoppel = (ladung.halbDoppelstock + 1) / 2
        if ladung.halbDoppelstock % 2 == 1 {
            hinweise.append("Eine doppelstockfähige Halbpalette bleibt als halber Platz übrig.")
        }
        let slotsHalbEinzeln = (ladung.halbEinzeln + 1) / 2
        if ladung.halbEinzeln % 2 == 1 {
            hinweise.append("Eine nicht stapelbare Halbpalette bleibt als halber Platz übrig.")
        }

        let bedarfDoppel = ladung.euroDoppelstock + slotsHalbDoppel
        let bedarfEinzeln = ladung.euroEinzeln + slotsHalbEinzeln

        // Belegung: doppelstockfaehige Ware zuerst auf den Boden, denn nur
        // darauf laesst sich der zweite Stock nutzen.
        let saeulen = konfiguration.saeulen
        let bodenDoppel = min(bedarfDoppel, saeulen)
        let bodenEinzeln = min(bedarfEinzeln, saeulen - bodenDoppel)

        let obenNutzbar = konfiguration.doppelstock ? bodenDoppel : 0
        let restDoppel = bedarfDoppel - bodenDoppel
        let restEinzeln = bedarfEinzeln - bodenEinzeln
        let obenBelegt = min(restDoppel + restEinzeln, obenNutzbar)

        let ueberhang = (restDoppel + restEinzeln) - obenBelegt

        return Ladeergebnis(
            konfiguration: konfiguration,
            ladung: ladung,
            stellplaetzeDoppelstock: bedarfDoppel,
            stellplaetzeEinzeln: bedarfEinzeln,
            bodenDoppelstock: bodenDoppel,
            bodenEinzeln: bodenEinzeln,
            obenBelegt: obenBelegt,
            ueberhang: max(0, ueberhang),
            halbeReste: hinweise
        )
    }
}
