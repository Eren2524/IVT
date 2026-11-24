import Foundation
import UserNotifications

/// Wohin die App springen soll, wenn auf eine Mitteilung getippt wird.
@MainActor
final class Wegweiser: ObservableObject {
    static let shared = Wegweiser()

    @Published var zeigeWochenbericht = false
    @Published var zeigeNews = false

    private init() {}
}

/// Nimmt die Tipps auf Mitteilungen an.
/// Ohne Delegate passiert beim Antippen nichts weiter als das Oeffnen der App.
/// UNUserNotificationCenter ruft den Delegate auf dem Hauptthread.
@MainActor
final class Mitteilungsannahme: NSObject, UNUserNotificationCenterDelegate {

    static let shared = Mitteilungsannahme()

    func anmelden() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Mitteilungen auch anzeigen, wenn die App gerade offen ist.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification)
    async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        let info = response.notification.request.content.userInfo
        let kennung = response.notification.request.identifier

        if info["ziel"] as? String == "wochenbericht"
            || kennung == Meldungen.wochenberichtID {
            Wegweiser.shared.zeigeWochenbericht = true
        }
        if info["ziel"] as? String == "news" {
            Wegweiser.shared.zeigeNews = true
        }
    }
}
