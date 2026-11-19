import Foundation
import CoreLocation

enum Routenhilfe {

    /// Zurueckgelegte Strecke in Metern.
    static func laenge(_ punkte: [Wegpunkt]) -> Double {
        let sortiert = punkte.sorted { $0.zeit < $1.zeit }
        guard sortiert.count > 1 else { return 0 }
        var summe: Double = 0
        for i in 1..<sortiert.count {
            let a = CLLocation(latitude: sortiert[i-1].breite, longitude: sortiert[i-1].laenge)
            let b = CLLocation(latitude: sortiert[i].breite, longitude: sortiert[i].laenge)
            summe += b.distance(from: a)
        }
        return summe
    }

    static func koordinaten(_ punkte: [Wegpunkt]) -> [CLLocationCoordinate2D] {
        punkte.sorted { $0.zeit < $1.zeit }
            .map { CLLocationCoordinate2D(latitude: $0.breite, longitude: $0.laenge) }
    }
}
