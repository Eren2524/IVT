import Foundation
import CoreLocation

/// Ein Stück Weg, das tatsächlich gegangen wurde.
///
/// Stillstand wird gar nicht erst aufgezeichnet: der Zeitdienst legt
/// einen Wegpunkt erst ab 25 Metern Abstand zum letzten an. Was hier
/// ankommt, ist also schon Bewegung. Zwischen zwei Abschnitten liegt
/// entweder eine Pause oder die Halle — beides zeichnet die Karte nicht.
struct Wegabschnitt: Identifiable {
    let id = UUID()
    var von: Date
    var bis: Date
    var koordinaten: [CLLocationCoordinate2D]
    var meter: Double

    var dauer: TimeInterval { max(0, bis.timeIntervalSince(von)) }
}

struct Wegbild {
    var abschnitte: [Wegabschnitt] = []
    /// Nur was draußen und in Bewegung aufgezeichnet wurde
    var gesamtMeter: Double = 0
    var unterwegs: TimeInterval = 0

    var von: Date? { abschnitte.first?.von }
    var bis: Date? { abschnitte.last?.bis }
    var istLeer: Bool { abschnitte.isEmpty }

    var alleKoordinaten: [CLLocationCoordinate2D] {
        abschnitte.flatMap(\.koordinaten)
    }

    /// Wo war ich zu diesem Zeitpunkt? Zwischen den Stützpunkten wird
    /// linear interpoliert, damit der Regler weich läuft. Fällt die Zeit
    /// in eine Pause, bleibt die letzte bekannte Position stehen — die
    /// Karte erfindet nichts dazu.
    func position(zu zeit: Date) -> CLLocationCoordinate2D? {
        guard !abschnitte.isEmpty else { return nil }
        if let erster = abschnitte.first, zeit <= erster.von {
            return erster.koordinaten.first
        }
        if let letzter = abschnitte.last, zeit >= letzter.bis {
            return letzter.koordinaten.last
        }
        for a in abschnitte where zeit >= a.von && zeit <= a.bis {
            guard a.koordinaten.count > 1, a.dauer > 0 else {
                return a.koordinaten.first
            }
            let anteil = zeit.timeIntervalSince(a.von) / a.dauer
            let stelle = anteil * Double(a.koordinaten.count - 1)
            let i = min(a.koordinaten.count - 2, max(0, Int(stelle)))
            let rest = stelle - Double(i)
            let p = a.koordinaten[i], q = a.koordinaten[i + 1]
            return CLLocationCoordinate2D(
                latitude: p.latitude + (q.latitude - p.latitude) * rest,
                longitude: p.longitude + (q.longitude - p.longitude) * rest
            )
        }
        return abschnitte.last(where: { $0.bis <= zeit })?.koordinaten.last
    }

    /// Liegt der Zeitpunkt in einer Pause, also zwischen zwei Abschnitten?
    func istPause(_ zeit: Date) -> Bool {
        guard !istLeer, let v = von, let b = bis, zeit > v, zeit < b else { return false }
        return !abschnitte.contains { zeit >= $0.von && zeit <= $0.bis }
    }
}

enum Wegauswertung {

    /// Ab dieser Pause zwischen zwei Punkten reißt die Linie ab.
    /// Er hat dann gestanden oder war in der Halle — in beiden Fällen
    /// wäre eine gezeichnete Verbindung erfunden.
    static let rissAb: TimeInterval = 3 * 60
    /// Darüber ist es kein Fußweg mehr, sondern ein GPS-Sprung.
    static let grenzeUnsinn: Double = 8.0

    static func auswerten(_ rohe: [Wegpunkt]) -> Wegbild {
        let punkte = rohe
            .filter { $0.genauigkeit > 0 && $0.genauigkeit <= 60 }
            .sorted { $0.zeit < $1.zeit }
        guard punkte.count > 1 else { return Wegbild() }

        var bild = Wegbild()
        var laufend: Wegabschnitt?

        func abschliessen() {
            // Ein einzelner Punkt ist keine Strecke
            if let a = laufend, a.koordinaten.count > 1 {
                bild.abschnitte.append(a)
                bild.gesamtMeter += a.meter
                bild.unterwegs += a.dauer
            }
            laufend = nil
        }

        for i in 1..<punkte.count {
            let p = punkte[i - 1], q = punkte[i]
            let dt = q.zeit.timeIntervalSince(p.zeit)
            guard dt > 0 else { continue }

            let a = CLLocation(latitude: p.breite, longitude: p.laenge)
            let b = CLLocation(latitude: q.breite, longitude: q.laenge)
            let meter = b.distance(from: a)

            // Zu lange nichts gehört, oder ein unmöglicher Sprung:
            // die Linie reißt ab statt quer über den Hof zu schießen.
            if dt >= rissAb || meter / dt > grenzeUnsinn {
                abschliessen()
                continue
            }

            if laufend == nil {
                laufend = Wegabschnitt(von: p.zeit, bis: q.zeit,
                                       koordinaten: [a.coordinate, b.coordinate],
                                       meter: meter)
            } else {
                laufend!.bis = q.zeit
                laufend!.koordinaten.append(b.coordinate)
                laufend!.meter += meter
            }
        }
        abschliessen()

        return bild
    }

    static func minuten(_ t: TimeInterval) -> String {
        let m = Int((t / 60).rounded())
        if m >= 60 {
            return "\(m / 60):\(String(format: "%02d", m % 60)) h"
        }
        return "\(max(0, m)) min"
    }
}
