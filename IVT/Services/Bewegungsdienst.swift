import Foundation
import CoreMotion
import Combine

/// Schrittzaehler plus Stillstandserkennung.
///
/// Der Schrittzaehler liest rueckblickend aus dem Bewegungs-Coprozessor,
/// die App muss dafuer nicht laufen. Die Stillstandserkennung fragt alle
/// zwei Minuten: wie viele Schritte in den letzten X Minuten (Schwelle)?
/// Fast keine, dann war vermutlich Pause.
@MainActor
final class Bewegungsdienst: ObservableObject {

    @Published private(set) var schritteHeute: Int = 0
    @Published private(set) var schritteSchicht: Int = 0
    @Published private(set) var verfuegbar: Bool = CMPedometer.isStepCountingAvailable()
    @Published private(set) var stillSeit: Date?

    /// Wird gerufen, wenn der Stillstand die Schwelle reisst.
    var beiStillstand: (@MainActor (TimeInterval) -> Void)?

    private let pedometer = CMPedometer()
    private var schichtStart: Date?
    private var pruefung: Timer?
    private var schonGemeldet = false
    /// Ab hier wird gezaehlt: Schichtbeginn oder letzte beantwortete Frage.
    /// So fragt die App nach einem "Nein" erst nach einem vollen neuen Zeitfenster wieder.
    private var zaehlenAb = Date()
    private var schwelle: TimeInterval = 15 * 60

    // MARK: Schritte

    func rechteAnfragen() {
        guard verfuegbar else { return }
        // Der erste Abruf loest den Systemdialog aus
        pedometer.queryPedometerData(from: Date().addingTimeInterval(-60), to: Date()) { _, _ in }
    }

    func heuteLaden() {
        guard verfuegbar else { return }
        let start = Calendar.current.startOfDay(for: Date())
        pedometer.queryPedometerData(from: start, to: Date()) { daten, _ in
            guard let daten else { return }
            Task { @MainActor in
                self.schritteHeute = daten.numberOfSteps.intValue
            }
        }
    }

    func schichtLaden(ab start: Date, bis ende: Date? = nil) {
        guard verfuegbar else { return }
        pedometer.queryPedometerData(from: start, to: ende ?? Date()) { daten, _ in
            guard let daten else { return }
            Task { @MainActor in
                self.schritteSchicht = daten.numberOfSteps.intValue
            }
        }
    }

    // MARK: Stillstandserkennung

    func stillstandsPruefungStarten(schichtStart: Date, schwelleMinuten: Int) {
        guard verfuegbar else { return }
        self.schichtStart = schichtStart
        self.schwelle = TimeInterval(schwelleMinuten * 60)
        self.schonGemeldet = false
        self.stillSeit = nil
        self.zaehlenAb = schichtStart

        pedometer.startUpdates(from: schichtStart) { daten, _ in
            guard let daten else { return }
            Task { @MainActor in
                self.schritteSchicht = daten.numberOfSteps.intValue
            }
        }

        // Alle zwei Minuten vergleichen, das reicht fuer eine 15-Minuten-Schwelle
        // und kostet kaum Akku.
        pruefung?.invalidate()
        let t = Timer(timeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pruefen() }
        }
        RunLoop.main.add(t, forMode: .common)
        pruefung = t
    }

    func stillstandsPruefungBeenden() {
        pruefung?.invalidate()
        pruefung = nil
        pedometer.stopUpdates()
        stillSeit = nil
        schonGemeldet = false
        schichtStart = nil
    }

    /// Nach einer beantworteten Pausenfrage wieder scharf stellen.
    func stillstandZuruecksetzen() {
        stillSeit = nil
        schonGemeldet = false
        zaehlenAb = Date()
    }

    /// Unter so vielen Schritten im ganzen Zeitfenster gilt er als stehend.
    /// Ein paar Schritte am Platz (Ware greifen, umdrehen) zaehlen nicht als Bewegung.
    private let mindestSchritte = 40

    /// Fragt den Schrittzaehler direkt nach dem Zeitfenster der Schwelle.
    /// Live-Updates des Pedometers kommen im Hintergrund nicht an; die
    /// rueckwirkende Abfrage liest dagegen immer den echten Stand aus dem
    /// Bewegungs-Coprozessor. Frueher sah ein eingefrorener Zaehler wie
    /// stundenlanger Stillstand aus.
    private func pruefen() {
        guard schichtStart != nil else { return }
        let jetzt = Date()
        let von = jetzt.addingTimeInterval(-schwelle)
        // Erst pruefen, wenn seit Schichtbeginn bzw. letzter Antwort
        // ein volles Zeitfenster vergangen ist
        if von < zaehlenAb { return }

        pedometer.queryPedometerData(from: von, to: jetzt) { daten, fehler in
            // Ohne Daten keine Aussage, lieber nicht fragen
            guard fehler == nil, let daten else { return }
            let schritte = daten.numberOfSteps.intValue
            Task { @MainActor in self.auswerten(schritte: schritte, von: von, jetzt: jetzt) }
        }
        heuteLaden()
        if let start = schichtStart { schichtLaden(ab: start) }
    }

    private func auswerten(schritte: Int, von: Date, jetzt: Date) {
        if schritte >= mindestSchritte {
            // Unterwegs: alles zuruecksetzen, naechster Stillstand darf wieder fragen
            stillSeit = nil
            schonGemeldet = false
            return
        }
        if stillSeit == nil { stillSeit = von }
        guard !schonGemeldet, let seit = stillSeit else { return }
        schonGemeldet = true
        beiStillstand?(jetzt.timeIntervalSince(seit))
    }

    /// Wie lange steht er jetzt schon, fuer die Anzeige.
    var stillstandDauer: TimeInterval {
        guard let stillSeit else { return 0 }
        return Date().timeIntervalSince(stillSeit)
    }
}
