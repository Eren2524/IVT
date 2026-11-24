import SwiftUI
import SwiftData

@main
struct IVTApp: App {

    let behaelter: ModelContainer
    @StateObject private var zeit = Zeitdienst()
    @StateObject private var einstellungen = Einstellungen.shared
    @StateObject private var wegweiser = Wegweiser.shared

    init() {
        let schema = Schema([
            Schicht.self, Pause.self, Wegpunkt.self,
            Aufgabe.self,
            Schadensvorgang.self, Schadensfoto.self,
            Fehlereintrag.self, Ladeplan.self,
            Palettenmass.self, Sprachnotiz.self, Vorlagendokument.self,
            Erfolg.self, Unterweisung.self
        ])
        // Alles bleibt auf dem iPhone: keine CloudKit-Konfiguration,
        // kein Server, keine Synchronisierung.
        let konfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        do {
            behaelter = try ModelContainer(for: schema, configurations: [konfiguration])
        } catch {
            fatalError("Datenbank konnte nicht geöffnet werden: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Wurzelansicht()
                .environmentObject(zeit)
                .environmentObject(einstellungen)
                .environmentObject(wegweiser)
                .task {
                    Mitteilungsannahme.shared.anmelden()
                    zeit.starten(kontext: behaelter.mainContext)
                    await Meldungen.shared.rechteAnfragen()
                    Meldungen.shared.quartalsauswertungPlanen()
                    // News mehrmals am Tag im Hintergrund holen (iOS bestimmt den Takt)
                    Nachrichtendienst.hintergrundPlanen()
                    // Termin neu setzen, falls die Einstellung sich geaendert hat
                    if einstellungen.wochenberichtAktiv {
                        Meldungen.shared.wochenberichtPlanen(
                            wochentag: einstellungen.wochenberichtTag,
                            stunde: einstellungen.wochenberichtStunde,
                            minute: einstellungen.wochenberichtMinute)
                    }
                }
        }
        .modelContainer(behaelter)
        .backgroundTask(.appRefresh(Nachrichtendienst.aufgabeID)) {
            await Nachrichtendienst.hintergrundAbruf()
        }
    }
}
