import Foundation
import CoreLocation
import Combine

/// Alle Vorgaben an einer Stelle, in den Einstellungen aenderbar.
/// Liegt in UserDefaults, verlaesst das iPhone nicht.
@MainActor
final class Einstellungen: ObservableObject {

    static let shared = Einstellungen()

    private let d = UserDefaults.standard

    // MARK: Firma / Geofence

    @Published var firmaBreite: Double {
        didSet { d.set(firmaBreite, forKey: "firmaBreite") }
    }
    @Published var firmaLaenge: Double {
        didSet { d.set(firmaLaenge, forKey: "firmaLaenge") }
    }
    /// Radius des Geofence in Metern
    @Published var firmaRadius: Double {
        didSet { d.set(firmaRadius, forKey: "firmaRadius") }
    }
    @Published var firmaName: String {
        didSet { d.set(firmaName, forKey: "firmaName") }
    }

    var firmaGesetzt: Bool { firmaBreite != 0 || firmaLaenge != 0 }

    var firmaOrt: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: firmaBreite, longitude: firmaLaenge)
    }

    // MARK: Zeiterfassung

    /// Minuten Stillstand, bis die App nach einer Pause fragt
    @Published var pauseSchwelleMinuten: Int {
        didSet { d.set(pauseSchwelleMinuten, forKey: "pauseSchwelleMinuten") }
    }
    /// Feste Pausen laut Arbeitsplan automatisch abziehen
    @Published var festePausenAbziehen: Bool {
        didSet { d.set(festePausenAbziehen, forKey: "festePausenAbziehen") }
    }
    @Published var geofenceAktiv: Bool {
        didSet { d.set(geofenceAktiv, forKey: "geofenceAktiv") }
    }
    /// Route nur im Freien aufzeichnen (in der Halle ist GPS unbrauchbar)
    @Published var routeAufzeichnen: Bool {
        didSet { d.set(routeAufzeichnen, forKey: "routeAufzeichnen") }
    }

    // MARK: Zug

    @Published var kofferAnzahl: Int {
        didSet { d.set(kofferAnzahl, forKey: "kofferAnzahl") }
    }
    @Published var bodenPlaetzeProKoffer: Int {
        didSet { d.set(bodenPlaetzeProKoffer, forKey: "bodenPlaetzeProKoffer") }
    }
    @Published var doppelstock: Bool {
        didSet { d.set(doppelstock, forKey: "doppelstock") }
    }

    var zug: Zugkonfiguration {
        Zugkonfiguration(kofferAnzahl: kofferAnzahl,
                         bodenPlaetzeProKoffer: bodenPlaetzeProKoffer,
                         breiteInPaletten: 3,
                         doppelstock: doppelstock)
    }

    // MARK: Arbeitsmail

    @Published var arbeitsmail: String {
        didSet { d.set(arbeitsmail, forKey: "arbeitsmail") }
    }
    /// Name unter der Mail
    @Published var absenderzeile: String {
        didSet { d.set(absenderzeile, forKey: "absenderzeile") }
    }
    /// Nach jedem Schadensfoto gleich den Mailentwurf oeffnen
    @Published var mailNachSchaden: Bool {
        didSet { d.set(mailNachSchaden, forKey: "mailNachSchaden") }
    }
    @Published var wochenberichtAktiv: Bool {
        didSet { d.set(wochenberichtAktiv, forKey: "wochenberichtAktiv") }
    }
    /// 1 = Sonntag, 2 = Montag ... 6 = Freitag
    @Published var wochenberichtTag: Int {
        didSet { d.set(wochenberichtTag, forKey: "wochenberichtTag") }
    }
    @Published var wochenberichtStunde: Int {
        didSet { d.set(wochenberichtStunde, forKey: "wochenberichtStunde") }
    }
    @Published var wochenberichtMinute: Int {
        didSet { d.set(wochenberichtMinute, forKey: "wochenberichtMinute") }
    }

    var mailGesetzt: Bool {
        let m = arbeitsmail.trimmingCharacters(in: .whitespaces)
        return m.contains("@") && m.contains(".") && !m.hasPrefix("@")
    }

    static let wochentage: [(Int, String)] = [
        (2, "Montag"), (3, "Dienstag"), (4, "Mittwoch"), (5, "Donnerstag"),
        (6, "Freitag"), (7, "Samstag"), (1, "Sonntag")
    ]

    // MARK: Fehlerbuch

    @Published var fehlerKategorien: [String] {
        didSet { d.set(fehlerKategorien, forKey: "fehlerKategorien") }
    }

    static let standardKategorien = [
        "Falsche Ware verladen",
        "Menge falsch",
        "Lieferschein fehlt oder falsch",
        "Beschädigung beim Verladen",
        "Ladungssicherung mangelhaft",
        "Palette falsch gepackt",
        "Etikett falsch oder fehlt",
        "Zu spät fertig",
        "Falscher Spediteur",
        "Sonstiges"
    ]

    // MARK: Init

    private init() {
        firmaBreite = d.double(forKey: "firmaBreite")
        firmaLaenge = d.double(forKey: "firmaLaenge")
        firmaRadius = d.object(forKey: "firmaRadius") as? Double ?? 150
        firmaName = d.string(forKey: "firmaName") ?? "IEB Brilon"

        pauseSchwelleMinuten = d.object(forKey: "pauseSchwelleMinuten") as? Int ?? 15
        festePausenAbziehen = d.object(forKey: "festePausenAbziehen") as? Bool ?? true
        geofenceAktiv = d.object(forKey: "geofenceAktiv") as? Bool ?? true
        routeAufzeichnen = d.object(forKey: "routeAufzeichnen") as? Bool ?? true

        kofferAnzahl = d.object(forKey: "kofferAnzahl") as? Int ?? 2
        bodenPlaetzeProKoffer = d.object(forKey: "bodenPlaetzeProKoffer") as? Int ?? 18
        doppelstock = d.object(forKey: "doppelstock") as? Bool ?? true

        arbeitsmail = d.string(forKey: "arbeitsmail") ?? ""
        absenderzeile = d.string(forKey: "absenderzeile") ?? "Enrique Diaz, Versandleiter"
        mailNachSchaden = d.object(forKey: "mailNachSchaden") as? Bool ?? false
        wochenberichtAktiv = d.object(forKey: "wochenberichtAktiv") as? Bool ?? false
        // Freitag 13:00: nach dem kurzen Freitag, Woche ist vollstaendig
        wochenberichtTag = d.object(forKey: "wochenberichtTag") as? Int ?? 6
        wochenberichtStunde = d.object(forKey: "wochenberichtStunde") as? Int ?? 13
        wochenberichtMinute = d.object(forKey: "wochenberichtMinute") as? Int ?? 0

        fehlerKategorien = d.stringArray(forKey: "fehlerKategorien")
            ?? Einstellungen.standardKategorien
    }
}
