import SwiftUI

struct Wurzelansicht: View {
    @EnvironmentObject private var zeit: Zeitdienst
    @EnvironmentObject private var einstellungen: Einstellungen
    @EnvironmentObject private var wegweiser: Wegweiser
    @State private var auswahl: Reiter = .start

    enum Reiter: Hashable { case start, zeit, laden, vorlagen, mehr }

    var body: some View {
        TabView(selection: $auswahl) {
            Dashboard()
                .tabItem { Label("Start", systemImage: "square.grid.2x2.fill") }
                .tag(Reiter.start)

            Zeitansicht()
                .tabItem { Label("Zeit", systemImage: "clock.fill") }
                .tag(Reiter.zeit)

            Palettenansicht()
                .tabItem { Label("Laden", systemImage: "shippingbox.fill") }
                .tag(Reiter.laden)

            Vorlagenansicht()
                .tabItem { Label("Vorlagen", systemImage: "doc.text.fill") }
                .tag(Reiter.vorlagen)

            Mehransicht()
                .tabItem { Label("Mehr", systemImage: "ellipsis.circle.fill") }
                .tag(Reiter.mehr)
        }
        .tint(.accentColor)
        // Tipp auf die Wochenbericht-Mitteilung fuehrt direkt dorthin
        .onChange(of: wegweiser.zeigeWochenbericht) {
            if wegweiser.zeigeWochenbericht { auswahl = .mehr }
        }
        .onChange(of: wegweiser.zeigeNews) {
            if wegweiser.zeigeNews { auswahl = .mehr }
        }
        // Pausenfrage als Systemdialog, damit sie nicht zu uebersehen ist
        .alert("Pause?", isPresented: .init(
            get: { zeit.pausenfrageOffen != nil },
            set: { if !$0 { zeit.pausenfrageAblehnen() } }
        )) {
            Button("Pause eintragen") { zeit.pausenfrageBejahen() }
            Button("Nein, ich arbeite", role: .cancel) { zeit.pausenfrageAblehnen() }
        } message: {
            if let d = zeit.pausenfrageOffen {
                Text("Seit \(d.alsMinuten) keine Bewegung. Soll die Zeit als Pause abgezogen werden?")
            }
        }
    }
}

/// Reiter "Mehr": Notizen, Fehlerbuch, Bewegung, Einstellungen
struct Mehransicht: View {
    @EnvironmentObject private var wegweiser: Wegweiser
    @EnvironmentObject private var e: Einstellungen

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        Schadensansicht()
                    } label: {
                        Zeile(symbol: "camera.fill", farbe: .blue,
                              titel: "Schäden", wert: nil)
                    }
                    NavigationLink {
                        Sprachnotizenansicht()
                    } label: {
                        Zeile(symbol: "waveform", farbe: .red,
                              titel: "Sprachnotizen", wert: nil)
                    }
                    NavigationLink {
                        Newsansicht()
                    } label: {
                        Zeile(symbol: "newspaper.fill", farbe: .indigo,
                              titel: "News", wert: nil)
                    }
                }
                Section {
                    NavigationLink {
                        Erfolgsansicht()
                    } label: {
                        Zeile(symbol: "trophy.fill", farbe: .yellow,
                              titel: "Erfolgs-Logbuch", wert: nil)
                    }
                    NavigationLink {
                        Unterweisungsansicht()
                    } label: {
                        Zeile(symbol: "person.badge.shield.checkmark.fill", farbe: .green,
                              titel: "Unterweisungen", wert: nil)
                    }
                    NavigationLink {
                        Feiertagsansicht()
                    } label: {
                        Zeile(symbol: "calendar", farbe: .pink,
                              titel: "Feiertage NRW",
                              wert: Feiertage.naechster().map { $0.datum.datumKurz })
                    }
                }
                Section {
                    NavigationLink {
                        Wochenberichtansicht()
                    } label: {
                        Zeile(symbol: "envelope.fill", farbe: .blue,
                              titel: "Wochenbericht",
                              wert: e.wochenberichtAktiv ? nil : "aus")
                    }
                }
                Section {
                    NavigationLink {
                        Notizenansicht()
                    } label: {
                        Zeile(symbol: "checklist", farbe: .orange,
                              titel: "Aufgaben und Notizen", wert: nil)
                    }
                    NavigationLink {
                        Fehlerbuchansicht()
                    } label: {
                        Zeile(symbol: "exclamationmark.triangle.fill", farbe: .red,
                              titel: "Fehlerprotokollbuch", wert: nil)
                    }
                    NavigationLink {
                        Bewegungsansicht()
                    } label: {
                        Zeile(symbol: "figure.walk", farbe: .green,
                              titel: "Bewegung und Route", wert: nil)
                    }
                }
                Section {
                    NavigationLink {
                        Einstellungsansicht()
                    } label: {
                        Zeile(symbol: "gearshape.fill", farbe: .gray,
                              titel: "Einstellungen", wert: nil)
                    }
                }
            }
            .navigationTitle("Mehr")
            // Tipp auf die Mitteilung oeffnet den Bericht direkt
            .navigationDestination(isPresented: $wegweiser.zeigeWochenbericht) {
                Wochenberichtansicht()
            }
            .navigationDestination(isPresented: $wegweiser.zeigeNews) {
                Newsansicht()
            }
        }
    }
}
