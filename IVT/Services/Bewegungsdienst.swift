import Foundation
import CoreMotion
import Combine

/// Schrittzaehler plus Stillstandserkennung.
///
/// Der Schrittzaehler liest rueckblickend aus dem Bewegungs-Coprozessor,
/// die App muss dafuer nicht laufen. Die Stillstandserkennung vergleicht
/// den Schrittstand in festen Abstaenden: bleibt er ueber die eingestellte
/// Schwelle stehen, war vermutlich Pause.
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
    private var letzterStand: Int = 0
    private var pruefung: Timer?
    private var schonGemeldet = false
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
        self.letzterStand = 0

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
        letzterStand = schritteSchicht
    }

    private func pruefen() {
        let stand = schritteSchicht

        if stand > letzterStand + 15 {
            // Deutlich mehr Schritte: er ist unterwegs
            letzterStand = stand
            stillSeit = nil
            schonGemeldet = false
            return
        }

        // Kaum Bewegung
        if stillSeit == nil {
            stillSeit = Date()
            return
        }

        guard let seit = stillSeit, !schonGemeldet else { return }
        let dauer = Date().timeIntervalSince(seit)
        if dauer >= schwelle {
            schonGemeldet = true
            beiStillstand?(dauer)
        }
    }

    /// Wie lange steht er jetzt schon, fuer die Anzeige.
    var stillstandDauer: TimeInterval {
        guard let stillSeit else { return 0 }
        return Date().timeIntervalSince(stillSeit)
    }
}
