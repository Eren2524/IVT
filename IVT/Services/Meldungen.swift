import Foundation
import UserNotifications

/// Lokale Mitteilungen: Pausenfrage, Feierabend, Aufgabenerinnerungen.
/// Nichts davon verlaesst das iPhone.
@MainActor
final class Meldungen: ObservableObject {

    static let shared = Meldungen()

    @Published private(set) var erlaubt = false

    private let zentrale = UNUserNotificationCenter.current()

    private init() {}

    func rechteAnfragen() async {
        do {
            let ok = try await zentrale.requestAuthorization(options: [.alert, .sound, .badge])
            erlaubt = ok
        } catch {
            erlaubt = false
        }
    }

    func standPruefen() async {
        let s = await zentrale.notificationSettings()
        erlaubt = s.authorizationStatus == .authorized
            || s.authorizationStatus == .provisional
    }

    // MARK: Sofortmeldungen

    func pausenfrage(stillstand: TimeInterval) {
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Pause?"
        inhalt.body = "Du stehst seit \(stillstand.alsMinuten) still. Pause eintragen?"
        inhalt.sound = .default
        inhalt.categoryIdentifier = "PAUSE"
        senden(inhalt, id: "pause.\(Int(Date().timeIntervalSince1970))")
    }

    func schichtGestartet(_ zeit: Date) {
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Arbeitszeit läuft"
        inhalt.body = "Kommen um \(zeit.uhrzeit) erfasst."
        senden(inhalt, id: "kommen.\(Int(zeit.timeIntervalSince1970))")
    }

    func schichtBeendet(_ zeit: Date, arbeitszeit: TimeInterval, saldo: TimeInterval) {
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Feierabend"
        inhalt.body = "\(arbeitszeit.alsStundenMinuten) gearbeitet, \(saldo.alsSaldo) auf dem Konto."
        inhalt.sound = .default
        senden(inhalt, id: "gehen.\(Int(zeit.timeIntervalSince1970))")
    }

    // MARK: Aufgaben

    func aufgabePlanen(id: String, titel: String, am zeit: Date) {
        guard zeit > Date() else { return }
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Aufgabe"
        inhalt.body = titel
        inhalt.sound = .default

        let teile = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: zeit)
        let aus = UNCalendarNotificationTrigger(dateMatching: teile, repeats: false)
        zentrale.add(UNNotificationRequest(identifier: "aufgabe.\(id)",
                                           content: inhalt,
                                           trigger: aus))
    }

    func aufgabeAbsagen(id: String) {
        zentrale.removePendingNotificationRequests(withIdentifiers: ["aufgabe.\(id)"])
    }

    /// Quartalsauswertung des Fehlerbuchs: am 1. des Quartals um 7 Uhr.
    func quartalsauswertungPlanen() {
        let id = "fehlerbuch.quartal"
        zentrale.removePendingNotificationRequests(withIdentifiers: [id])

        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Fehlerbuch"
        inhalt.body = "Neues Quartal. Die Auswertung des letzten Quartals liegt in der App bereit."
        inhalt.sound = .default

        // Ein Termin je Quartalsanfang, jaehrlich wiederkehrend
        for monat in [1, 4, 7, 10] {
            var teile = DateComponents()
            teile.month = monat
            teile.day = 1
            teile.hour = 7
            teile.minute = 0
            let aus = UNCalendarNotificationTrigger(dateMatching: teile, repeats: true)
            zentrale.add(UNNotificationRequest(identifier: "\(id).\(monat)",
                                               content: inhalt,
                                               trigger: aus))
        }
    }

    // MARK: Wochenbericht

    static let wochenberichtID = "ivt.wochenbericht"

    /// Wiederkehrende Erinnerung, die den fertigen Mailentwurf oeffnet.
    func wochenberichtPlanen(wochentag: Int, stunde: Int, minute: Int) {
        wochenberichtAbsagen()

        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Wochenbericht"
        inhalt.body = "Der Bericht für die Arbeitsmail ist fertig. Tippen, prüfen, senden."
        inhalt.sound = .default
        inhalt.userInfo = ["ziel": "wochenbericht"]

        var teile = DateComponents()
        teile.weekday = wochentag
        teile.hour = stunde
        teile.minute = minute

        let aus = UNCalendarNotificationTrigger(dateMatching: teile, repeats: true)
        zentrale.add(UNNotificationRequest(identifier: Self.wochenberichtID,
                                           content: inhalt,
                                           trigger: aus))
    }

    func wochenberichtAbsagen() {
        zentrale.removePendingNotificationRequests(withIdentifiers: [Self.wochenberichtID])
    }

    /// Wann die Erinnerung das naechste Mal kommt, fuer die Anzeige.
    func naechsterWochenbericht(wochentag: Int, stunde: Int, minute: Int) -> Date? {
        var teile = DateComponents()
        teile.weekday = wochentag
        teile.hour = stunde
        teile.minute = minute
        return Calendar.current.nextDate(after: Date(),
                                         matching: teile,
                                         matchingPolicy: .nextTime)
    }

    private func senden(_ inhalt: UNNotificationContent, id: String) {
        guard erlaubt else { return }
        zentrale.add(UNNotificationRequest(identifier: id, content: inhalt, trigger: nil))
    }
}
