import SwiftUI
import SwiftData
import CoreLocation
import MapKit

struct Einstellungsansicht: View {
    @EnvironmentObject private var e: Einstellungen
    @EnvironmentObject private var zeit: Zeitdienst
    @ObservedObject private var meldungen = Meldungen.shared
    @Environment(\.modelContext) private var kontext

    @State private var zeigeKategorien = false
    @State private var neueKategorie = ""

    var body: some View {
        List {
            // MARK: Firma
            Section {
                HStack {
                    Text("Name")
                    Spacer()
                    TextField("Firma", text: $e.firmaName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }

                if e.firmaGesetzt {
                    LabeledContent("Standort",
                                   value: String(format: "%.5f, %.5f", e.firmaBreite, e.firmaLaenge))
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Radius")
                            Spacer()
                            Text("\(Int(e.firmaRadius)) m")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $e.firmaRadius, in: 80...500, step: 10)
                    }
                } else {
                    Text("Noch nicht gesetzt")
                        .foregroundStyle(.secondary)
                }

                Button {
                    firmaHierSetzen()
                } label: {
                    Label(e.firmaGesetzt ? "Standort neu setzen" : "Ich stehe jetzt in der Firma",
                          systemImage: "mappin.and.ellipse")
                }
            } header: {
                Text("Firmengelände")
            } footer: {
                Text("Einmal auf dem Hof stehen und tippen. Danach startet die Arbeitszeit beim Betreten und endet beim Verlassen.")
            }

            // MARK: Zeiterfassung
            Section {
                Toggle("Automatisch per Standort", isOn: $e.geofenceAktiv)
                Toggle("Feste Pausen abziehen", isOn: $e.festePausenAbziehen)
                Toggle("Route aufzeichnen", isOn: $e.routeAufzeichnen)

                Picker("Pause fragen nach", selection: $e.pauseSchwelleMinuten) {
                    ForEach([5, 10, 15, 20, 30, 45], id: \.self) { m in
                        Text("\(m) Minuten").tag(m)
                    }
                }
            } header: {
                Text("Zeiterfassung")
            } footer: {
                Text("Nach so langem Stillstand fragt die App, ob es eine Pause war.")
            }

            // MARK: Arbeitszeiten (fest, zur Kontrolle)
            Section {
                LabeledContent("Mo – Do", value: "6:30 – 15:40")
                LabeledContent("Freitag", value: "6:30 – 12:40")
                LabeledContent("Frühstück", value: "9:30 – 9:40")
                LabeledContent("Mittag (Mo–Do)", value: "12:30 – 13:00")
                Divider()
                LabeledContent("Soll Mo – Do", value: Arbeitsplan.langerTag.sollMinuten.alsStundenText)
                LabeledContent("Soll Freitag", value: Arbeitsplan.freitag.sollMinuten.alsStundenText)
                LabeledContent("Soll Woche", value: wochensoll)
            } header: {
                Text("Arbeitszeiten")
            } footer: {
                Text("So steht es im Vertrag. Einzelne Tage korrigierst du im Reiter Zeit direkt an der Schicht.")
            }

            // MARK: Zug
            Section {
                Stepper("Koffer: \(e.kofferAnzahl)", value: $e.kofferAnzahl, in: 1...4)
                Stepper("Bodenplätze je Koffer: \(e.bodenPlaetzeProKoffer)",
                        value: $e.bodenPlaetzeProKoffer, in: 1...40)
                Toggle("Doppelstock", isOn: $e.doppelstock)
                LabeledContent("Stellplätze gesamt", value: "\(e.zug.gesamtPlaetze)")
            } header: {
                Text("DSV-Zug")
            } footer: {
                Text("Standard: 2 Koffer mit je 18 Bodenplätzen, doppelt gestapelt also 72 Stellplätze.")
            }

            // MARK: Fehlerkategorien
            Section {
                ForEach(e.fehlerKategorien, id: \.self) { k in
                    Text(k)
                }
                .onDelete { i in
                    e.fehlerKategorien.remove(atOffsets: i)
                }
                .onMove { von, nach in
                    e.fehlerKategorien.move(fromOffsets: von, toOffset: nach)
                }

                HStack {
                    TextField("Neue Kategorie", text: $neueKategorie)
                        .onSubmit(kategorieHinzufuegen)
                    Button("Hinzufügen", action: kategorieHinzufuegen)
                        .font(.footnote.weight(.semibold))
                        .disabled(neueKategorie.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Button("Auf Standard zurücksetzen") {
                    e.fehlerKategorien = Einstellungen.standardKategorien
                }
                .foregroundStyle(.red)
            } header: {
                Text("Fehlerkategorien")
            }

            // MARK: Rechte
            Section {
                Zeile(symbol: "location.fill", farbe: .blue,
                      titel: "Standort", wert: standortText)
                Zeile(symbol: "figure.walk", farbe: .green,
                      titel: "Bewegung", wert: zeit.bewegung.verfuegbar ? "verfügbar" : "nicht verfügbar")
                Zeile(symbol: "bell.fill", farbe: .red,
                      titel: "Mitteilungen", wert: meldungen.erlaubt ? "erlaubt" : "aus")

                Button {
                    zeit.standort.rechteAnfragen()
                    zeit.bewegung.rechteAnfragen()
                    Task { await Meldungen.shared.rechteAnfragen() }
                } label: {
                    Label("Rechte anfragen", systemImage: "hand.raised")
                }

                if let url = URL(string: UIApplication.openSettingsURLString) {
                    Link(destination: url) {
                        Label("iPhone-Einstellungen öffnen", systemImage: "gear")
                    }
                }
            } header: {
                Text("Berechtigungen")
            } footer: {
                if !zeit.standort.hatHintergrundrechte {
                    Text("Für Kommen und Gehen im Hintergrund muss der Standort auf „Immer“ stehen. Sonst erkennt die App es nur, wenn die App offen ist.")
                }
            }

            // MARK: Daten
            Section {
                LabeledContent("Speicherort", value: "nur dieses iPhone")
                LabeledContent("Synchronisierung", value: "keine")
            } header: {
                Text("Daten")
            } footer: {
                Text("Alles bleibt lokal. Kein Server, keine iCloud, keine Weitergabe. Was du teilst, teilst du selbst als PDF oder Foto.")
            }

            Section {
                LabeledContent("Version", value: version)
                LabeledContent("Name", value: "IVT — IEB-Versand-Team")
            }
        }
        .navigationTitle("Einstellungen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
        }
        .task { await meldungen.standPruefen() }
    }

    private var wochensoll: String {
        let minuten = Arbeitsplan.langerTag.sollMinuten * 4 + Arbeitsplan.freitag.sollMinuten
        return minuten.alsStundenText
    }

    private var standortText: String {
        switch zeit.standort.rechte {
        case .authorizedAlways:     return "immer"
        case .authorizedWhenInUse:  return "nur bei Nutzung"
        case .denied:               return "abgelehnt"
        case .restricted:           return "gesperrt"
        default:                    return "nicht gefragt"
        }
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private func firmaHierSetzen() {
        zeit.standort.rechteAnfragen()
        zeit.standort.einmalOrten()
        // Kurz warten, bis eine Position da ist, dann uebernehmen
        Task { @MainActor in
            for _ in 0..<20 {
                if let ort = zeit.standort.letzterOrt {
                    e.firmaBreite = ort.coordinate.latitude
                    e.firmaLaenge = ort.coordinate.longitude
                    zeit.standort.geofenceSetzen(e.firmaOrt, radius: e.firmaRadius)
                    return
                }
                try? await Task.sleep(for: .milliseconds(400))
            }
        }
    }

    private func kategorieHinzufuegen() {
        let k = neueKategorie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty, !e.fehlerKategorien.contains(k) else { return }
        e.fehlerKategorien.append(k)
        neueKategorie = ""
    }
}

private extension Int {
    /// Minuten als "8:30"
    var alsStundenText: String {
        String(format: "%d:%02d", self / 60, self % 60)
    }
}
