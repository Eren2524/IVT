import Foundation
import CoreLocation
import Combine

/// Geofence um die Firma plus Routenaufzeichnung.
///
/// Region Monitoring laeuft auch bei beendeter App weiter und weckt sie,
/// darum startet und beendet es die Schicht zuverlaessiger als ein Timer.
/// In der Halle ist GPS praktisch unbrauchbar, die Route ist also nur
/// im Freien belastbar - das steht so auch in der Oberflaeche.
@MainActor
final class Standortdienst: NSObject, ObservableObject {

    static let regionID = "ivt.firma"

    @Published private(set) var rechte: CLAuthorizationStatus = .notDetermined
    @Published private(set) var inDerFirma: Bool?
    @Published private(set) var letzterOrt: CLLocation?
    @Published private(set) var fehler: String?

    /// Wird gerufen, wenn der Geofence betreten oder verlassen wird.
    var beiBetreten: (@MainActor () -> Void)?
    var beiVerlassen: (@MainActor () -> Void)?
    /// Neuer Wegpunkt waehrend einer laufenden Schicht
    var beiWegpunkt: (@MainActor (CLLocation) -> Void)?

    private let manager = CLLocationManager()
    private var zeichnetAuf = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        // iOS meldet erst ab dieser Strecke. Beim Stehen kommt damit
        // gar nichts an - das ist der Punkt.
        manager.distanceFilter = 25
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .other
        rechte = manager.authorizationStatus
    }

    // MARK: Rechte

    func rechteAnfragen() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Fuer den Geofence im Hintergrund braucht es "Immer"
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    var hatHintergrundrechte: Bool {
        manager.authorizationStatus == .authorizedAlways
    }

    // MARK: Geofence

    func geofenceSetzen(_ ort: CLLocationCoordinate2D, radius: Double) {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            fehler = "Dieses iPhone unterstützt keine Standortbereiche."
            return
        }
        geofenceEntfernen()

        // iOS deckelt den Radius geraeteabhaengig; 100-200 m sind praxistauglich
        let r = min(max(radius, 80), manager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: ort, radius: r, identifier: Self.regionID)
        region.notifyOnEntry = true
        region.notifyOnExit = true
        manager.startMonitoring(for: region)
        manager.requestState(for: region)
    }

    func geofenceEntfernen() {
        for region in manager.monitoredRegions where region.identifier == Self.regionID {
            manager.stopMonitoring(for: region)
        }
        inDerFirma = nil
    }

    var geofenceAktiv: Bool {
        manager.monitoredRegions.contains { $0.identifier == Self.regionID }
    }

    // MARK: Route

    func routeStarten() {
        guard !zeichnetAuf else { return }
        zeichnetAuf = true
        manager.startUpdatingLocation()
    }

    func routeBeenden() {
        zeichnetAuf = false
        manager.stopUpdatingLocation()
    }

    func einmalOrten() {
        manager.requestLocation()
    }
}

// CLLocationManager ruft seinen Delegate nicht zwingend auf dem
// Hauptthread. Weil die Klasse @MainActor ist, waeren diese Methoden
// sonst isoliert und erfuellen die Anforderung des Protokolls nicht -
// in Swift 6 ein Fehler. Darum nonisolated; die Rumpfe springen selbst
// auf den MainActor.
extension Standortdienst: CLLocationManagerDelegate {

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            rechte = manager.authorizationStatus
            if rechte == .authorizedAlways || rechte == .authorizedWhenInUse {
                fehler = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard region.identifier == Self.regionID else { return }
        Task { @MainActor in
            inDerFirma = true
            beiBetreten?()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard region.identifier == Self.regionID else { return }
        Task { @MainActor in
            inDerFirma = false
            beiVerlassen?()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                         didDetermineState state: CLRegionState,
                         for region: CLRegion) {
        guard region.identifier == Self.regionID else { return }
        Task { @MainActor in
            switch state {
            case .inside:  inDerFirma = true
            case .outside: inDerFirma = false
            case .unknown: inDerFirma = nil
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let ort = locations.last else { return }
        Task { @MainActor in
            letzterOrt = ort
            // In der Halle liefert GPS Phantomwerte; alles ueber 60 m
            // Ungenauigkeit fliegt raus, statt die Route zu verfaelschen.
            if zeichnetAuf, ort.horizontalAccuracy > 0, ort.horizontalAccuracy <= 60 {
                beiWegpunkt?(ort)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if (error as? CLError)?.code == .denied {
                fehler = "Standortzugriff ist abgelehnt. In den iPhone-Einstellungen freigeben."
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                         monitoringDidFailFor region: CLRegion?,
                         withError error: Error) {
        Task { @MainActor in
            fehler = "Standortbereich konnte nicht überwacht werden."
        }
    }
}
