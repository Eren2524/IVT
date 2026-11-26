import Foundation
import SwiftData
import CoreLocation
import Combine

/// Haelt die Zeiterfassung zusammen: Geofence startet und beendet die
/// Schicht, die feste Pause zieht sich selbst ab, laengerer Stillstand
/// fragt nach einer zusaetzlichen Pause.
@MainActor
final class Zeitdienst: ObservableObject {

    @Published private(set) var laufendeSchicht: Schicht?
    @Published private(set) var laufendePause: Pause?
    @Published var pausenfrageOffen: TimeInterval?
    @Published private(set) var hinweis: String?

    let standort = Standortdienst()
    let bewegung = Bewegungsdienst()

    private var kontext: ModelContext?
    private let e = Einstellungen.shared
    private var takt: Timer?
    private var weiterleitungen: Set<AnyCancellable> = []

    // MARK: Start

    private var gestartet = false

    func starten(kontext: ModelContext) {
        // Doppelstart wuerde Timer und Weiterleitungen verdoppeln
        guard !gestartet else { return }
        gestartet = true
        self.kontext = kontext

        laufendeSchicht = offeneSchichtSuchen()
        laufendePause = laufendeSchicht?.pausen.first(where: { $0.laeuft })

        standort.beiBetreten = { [weak self] in self?.kommen(automatisch: true) }
        standort.beiVerlassen = { [weak self] in self?.gehen(automatisch: true) }
        standort.beiWegpunkt = { [weak self] ort in self?.wegpunktSpeichern(ort) }

        bewegung.beiStillstand = { [weak self] dauer in
            guard let self, self.laufendeSchicht != nil, self.laufendePause == nil else { return }
            // Stillstand in der festen Fruehstuecks- oder Mittagspause ist normal
            let jetzt = Date()
            let von = jetzt.addingTimeInterval(-dauer)
            let inFesterPause = Arbeitsplan.pausenZeiten(am: jetzt).contains { p in
                p.von < jetzt && p.bis > von
            }
            if inFesterPause {
                self.bewegung.stillstandZuruecksetzen()
                return
            }
            self.pausenfrageOffen = dauer
            Meldungen.shared.pausenfrage(stillstand: dauer)
        }

        if e.geofenceAktiv, e.firmaGesetzt {
            standort.geofenceSetzen(e.firmaOrt, radius: e.firmaRadius)
        }

        if let s = laufendeSchicht {
            bewegung.schichtLaden(ab: s.start)
            bewegung.stillstandsPruefungStarten(schichtStart: s.start,
                                                schwelleMinuten: e.pauseSchwelleMinuten)
            if e.routeAufzeichnen { standort.routeStarten() }
        }
        bewegung.heuteLaden()

        // Standort und Bewegung sind eigene ObservableObjects. Ihre
        // Aenderungen muessen weitergereicht werden, sonst sehen die
        // Ansichten sie erst beim naechsten Takt.
        standort.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &weiterleitungen)
        bewegung.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &weiterleitungen)

        taktStarten()
    }

    private func taktStarten() {
        takt?.invalidate()
        let t = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        takt = t
    }

    private func tick() {
        festePausenNachtragen()
        objectWillChange.send()
    }

    // MARK: Kommen und Gehen

    func kommen(automatisch: Bool = false) {
        guard laufendeSchicht == nil, let kontext else { return }

        // Wenn heute schon eine Schicht beendet wurde und der Geofence
        // nur kurz geflackert hat, nicht gleich eine zweite anfangen.
        if automatisch, let letzte = letzteSchichtHeute(),
           let ende = letzte.ende, Date().timeIntervalSince(ende) < 600 {
            hinweis = "Kommen ignoriert, Feierabend war gerade erst."
            return
        }

        let s = Schicht(start: Date(), automatischGestartet: automatisch)
        kontext.insert(s)
        sichern()
        laufendeSchicht = s

        bewegung.stillstandsPruefungStarten(schichtStart: s.start,
                                            schwelleMinuten: e.pauseSchwelleMinuten)
        if e.routeAufzeichnen { standort.routeStarten() }
        if automatisch { Meldungen.shared.schichtGestartet(s.start) }
    }

    func gehen(automatisch: Bool = false) {
        guard let s = laufendeSchicht else { return }

        pauseBeenden()
        festePausenNachtragen()

        s.ende = Date()
        s.automatischBeendet = automatisch
        s.schritte = bewegung.schritteSchicht
        sichern()

        bewegung.stillstandsPruefungBeenden()
        standort.routeBeenden()
        pausenfrageOffen = nil
        laufendeSchicht = nil

        if automatisch {
            Meldungen.shared.schichtBeendet(s.ende!,
                                            arbeitszeit: s.arbeitszeit,
                                            saldo: s.saldo)
        }
    }

    /// Von Hand korrigieren, falls der Geofence etwas verpasst hat.
    func schichtKorrigieren(_ s: Schicht, start: Date, ende: Date?) {
        s.start = start
        s.ende = ende
        sichern()
        if ende == nil { laufendeSchicht = s }
        else if laufendeSchicht === s { laufendeSchicht = nil }
    }

    // MARK: Pausen

    func pauseStarten(art: PausenArt = .zusatz, erkannt: Bool = false, von: Date = Date()) {
        guard let s = laufendeSchicht, laufendePause == nil, let kontext else { return }
        let p = Pause(von: von, art: art, erkannt: erkannt)
        p.schicht = s
        kontext.insert(p)
        sichern()
        laufendePause = p
        pausenfrageOffen = nil
    }

    func pauseBeenden() {
        guard let p = laufendePause else { return }
        p.bis = Date()
        sichern()
        laufendePause = nil
        bewegung.stillstandZuruecksetzen()
    }

    /// Antwort auf die Pausenfrage: ja, rueckwirkend ab Beginn des Stillstands.
    func pausenfrageBejahen() {
        guard let dauer = pausenfrageOffen else { return }
        pauseStarten(art: .zusatz, erkannt: true, von: Date().addingTimeInterval(-dauer))
    }

    func pausenfrageAblehnen() {
        pausenfrageOffen = nil
        bewegung.stillstandZuruecksetzen()
    }

    /// Feste Pausen laut Arbeitsplan eintragen, sobald sie vorbei sind.
    private func festePausenNachtragen() {
        guard e.festePausenAbziehen,
              let s = laufendeSchicht ?? letzteSchichtHeute(),
              let kontext else { return }

        let jetzt = Date()
        for fenster in Arbeitsplan.pausenZeiten(am: s.start) {
            // Nur Pausen, die vollstaendig in der Schicht liegen und schon vorbei sind
            guard fenster.bis <= jetzt,
                  fenster.von >= s.start,
                  fenster.bis <= (s.ende ?? jetzt) else { continue }
            let schonDa = s.pausen.contains {
                $0.art == fenster.art &&
                Calendar.current.isDate($0.von, inSameDayAs: fenster.von)
            }
            guard !schonDa else { continue }

            let p = Pause(von: fenster.von, bis: fenster.bis, art: fenster.art)
            p.schicht = s
            kontext.insert(p)
        }
        sichern()
    }

    // MARK: Route

    private func wegpunktSpeichern(_ ort: CLLocation) {
        guard let s = laufendeSchicht, let kontext else { return }
        // Nicht jeden Meter speichern: erst ab 25 m Abstand zum letzten Punkt
        if let letzter = s.wegpunkte.max(by: { $0.zeit < $1.zeit }) {
            let vorher = CLLocation(latitude: letzter.breite, longitude: letzter.laenge)
            guard ort.distance(from: vorher) >= 25 else { return }
        }
        let w = Wegpunkt(zeit: ort.timestamp,
                         breite: ort.coordinate.latitude,
                         laenge: ort.coordinate.longitude,
                         genauigkeit: ort.horizontalAccuracy)
        w.schicht = s
        kontext.insert(w)
        sichern()
    }

    /// "Wo war ich um 14:30?" - naechster Wegpunkt zur Uhrzeit.
    func wegpunkt(nahe zeit: Date, toleranzMinuten: Int = 10) -> Wegpunkt? {
        guard let kontext else { return nil }
        let von = zeit.addingTimeInterval(-Double(toleranzMinuten) * 60)
        let bis = zeit.addingTimeInterval(Double(toleranzMinuten) * 60)
        let abfrage = FetchDescriptor<Wegpunkt>(
            predicate: #Predicate { $0.zeit >= von && $0.zeit <= bis }
        )
        let treffer = (try? kontext.fetch(abfrage)) ?? []
        return treffer.min {
            abs($0.zeit.timeIntervalSince(zeit)) < abs($1.zeit.timeIntervalSince(zeit))
        }
    }

    // MARK: Auswertung

    var arbeitszeitHeute: TimeInterval {
        schichtenHeute().reduce(0) { $0 + $1.arbeitszeit }
    }

    var sollHeute: TimeInterval { Arbeitsplan.soll(am: Date()) }

    var saldoHeute: TimeInterval {
        // Waehrend der Schicht laufend mitrechnen, damit er sieht, wo er steht
        arbeitszeitHeute - sollHeute
    }

    var arbeitszeitWoche: TimeInterval {
        schichtenDerWoche().reduce(0) { $0 + $1.arbeitszeit }
    }

    var sollWocheBisHeute: TimeInterval {
        let k = Calendar.current
        guard let woche = k.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        var summe: TimeInterval = 0
        var tag = woche.start
        let heuteEnde = k.date(byAdding: .day, value: 1, to: k.startOfDay(for: Date())) ?? Date()
        while tag < min(woche.end, heuteEnde) {
            summe += Arbeitsplan.soll(am: tag)
            tag = k.date(byAdding: .day, value: 1, to: tag) ?? woche.end
        }
        return summe
    }

    /// Ueberstundenkonto ueber alle abgeschlossenen Schichten.
    var ueberstunden: TimeInterval {
        guard let kontext else { return 0 }
        let abfrage = FetchDescriptor<Schicht>(predicate: #Predicate { $0.ende != nil })
        let alle = (try? kontext.fetch(abfrage)) ?? []
        return alle.reduce(0) { $0 + $1.saldo }
    }

    func schichtenHeute() -> [Schicht] {
        schichten(von: Calendar.current.startOfDay(for: Date()), bis: Date())
    }

    func schichtenDerWoche() -> [Schicht] {
        guard let woche = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else { return [] }
        return schichten(von: woche.start, bis: woche.end)
    }

    func schichten(von: Date, bis: Date) -> [Schicht] {
        guard let kontext else { return [] }
        let abfrage = FetchDescriptor<Schicht>(
            predicate: #Predicate { $0.start >= von && $0.start <= bis },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        return (try? kontext.fetch(abfrage)) ?? []
    }

    private func offeneSchichtSuchen() -> Schicht? {
        guard let kontext else { return nil }
        let abfrage = FetchDescriptor<Schicht>(
            predicate: #Predicate { $0.ende == nil },
            sortBy: [SortDescriptor(\.start, order: .reverse)]
        )
        return (try? kontext.fetch(abfrage))?.first
    }

    private func letzteSchichtHeute() -> Schicht? {
        schichtenHeute().first
    }

    private func sichern() {
        try? kontext?.save()
    }
}
