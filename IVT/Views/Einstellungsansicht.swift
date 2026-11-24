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
    @State private var schluesselEingabe = ""
    @State private var schluesselDa = Schluesselbund.vorhanden

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

            // MARK: Arbeitsmail
            Section {
                HStack {
                    Text("Adresse")
                    Spacer()
                    TextField("freilassen und selbst tippen", text: $e.arbeitsmail)
                        .multilineTextAlignment(.trailing)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text("Signatur")
                    Spacer()
                    TextField("Name, Funktion", text: $e.absenderzeile)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Mailempfänger")
            } footer: {
                if !Mailfenster.kannMailen {
                    Text("Auf diesem iPhone ist noch kein Mail-Konto eingerichtet. Ohne Konto kann die App keine Mail öffnen — dann bleibt der Weg über „PDF teilen“.")
                } else if e.mailGesetzt {
                    Text("Entwürfe gehen an diese Adresse. Du kannst sie in der Mail vor dem Senden noch ändern.")
                } else {
                    Text("Ohne Adresse öffnet die Mail mit leerem An-Feld — Text und Anhänge sind trotzdem fertig, du tippst nur den Empfänger. Einmal hier eingetragen, fällt auch das weg.")
                }
            }

            Section {
                Toggle("Nach jedem Schadensfoto", isOn: $e.mailNachSchaden)
            } header: {
                Text("Schadensmeldungen")
            } footer: {
                Text("Sobald ein Foto gespeichert ist, öffnet sich die Mail: Betreff, Text, alle Fotos und das PDF sind drin. Auf Senden tippst du selbst — iOS erlaubt keiner App, im Hintergrund Mails zu verschicken.")
            }

            Section {
                Toggle("Wochenbericht erinnern", isOn: $e.wochenberichtAktiv)

                if e.wochenberichtAktiv {
                    Picker("Tag", selection: $e.wochenberichtTag) {
                        ForEach(Einstellungen.wochentage, id: \.0) { tag in
                            Text(tag.1).tag(tag.0)
                        }
                    }
                    DatePicker("Uhrzeit",
                               selection: Binding(
                                   get: { uhrzeit },
                                   set: { neu in
                                       let t = Calendar.current.dateComponents([.hour, .minute], from: neu)
                                       e.wochenberichtStunde = t.hour ?? 13
                                       e.wochenberichtMinute = t.minute ?? 0
                                   }),
                               displayedComponents: .hourAndMinute)

                    if let naechster = Meldungen.shared.naechsterWochenbericht(
                        wochentag: e.wochenberichtTag,
                        stunde: e.wochenberichtStunde,
                        minute: e.wochenberichtMinute) {
                        LabeledContent("Nächste Erinnerung",
                                       value: "\(naechster.wochentag), \(naechster.datumKurz), \(naechster.uhrzeit)")
                    }
                }
            } header: {
                Text("Wochenbericht")
            } footer: {
                Text("Termine, offene Aufgaben, Notizen, Fehler und Schäden der Woche, dazu Zeiten und Überstunden. Die Erinnerung öffnet den fertigen Entwurf. Voreinstellung Freitag 13:00, dann ist die Woche komplett.")
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

            // MARK: Diktat
            Section {
                Toggle("Nur auf dem iPhone erkennen", isOn: $e.diktatNurAufGeraet)
            } header: {
                Text("Diktat")
            } footer: {
                Text(e.diktatNurAufGeraet
                     ? "Sprache wird auf dem iPhone in Text umgewandelt, nichts verlässt das Gerät. Klappt das auf deinem iPhone nicht, hier ausschalten: dann nutzt iOS die Apple-Spracherkennung."
                     : "Apple-Spracherkennung: Die Aufnahme geht zur Erkennung an Apple. Genauer bei Fachbegriffen, braucht Internet.")
            }

            // MARK: Vorlagen / Claude
            Section {
                if schluesselDa {
                    LabeledContent("API-Schlüssel", value: "hinterlegt")
                    Button("Schlüssel entfernen", role: .destructive) {
                        Schluesselbund.loesche()
                        schluesselDa = false
                    }
                } else {
                    SecureField("sk-ant-…", text: $schluesselEingabe)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Sichern") {
                        let k = schluesselEingabe.trimmingCharacters(in: .whitespacesAndNewlines)
                        if Schluesselbund.speichere(k) {
                            schluesselDa = true
                            schluesselEingabe = ""
                        }
                    }
                    .disabled(schluesselEingabe.trimmingCharacters(in: .whitespaces).count < 20)
                }
                Picker("Modell", selection: $e.claudeModell) {
                    ForEach(Einstellungen.claudeModelle, id: \.id) { m in
                        Text(m.name).tag(m.id)
                    }
                }
            } header: {
                Text("Vorlagen: Mit Claude umschreiben")
            } footer: {
                Text("Optional. Den Schlüssel legst du in der Claude-Konsole an (console.anthropic.com > API Keys); abgerechnet wird über dein API-Guthaben, nicht über das Pro-Abo. Er liegt nur im Schlüsselbund dieses iPhones. Gesendet wird nur der Diktattext, wenn du auf „Mit Claude umschreiben“ tippst.")
            }

            // MARK: Daten
            Section {
                LabeledContent("Speicherort", value: "nur dieses iPhone")
                LabeledContent("Synchronisierung", value: "keine")
            } header: {
                Text("Daten")
            } footer: {
                Text("Alles bleibt lokal. Kein Server, keine iCloud, keine Weitergabe. Was rausgeht, geht über deine eigene Mail-App und nur, wenn du auf Senden tippst. Ausnahmen, nur wenn du sie nutzt: News liest öffentliche Feeds (über dich wird nichts gesendet), „Mit Claude umschreiben“ schickt den einen Diktattext an Anthropic.")
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
        .onChange(of: e.wochenberichtAktiv) { terminSetzen() }
        .onChange(of: e.wochenberichtTag) { terminSetzen() }
        .onChange(of: e.wochenberichtStunde) { terminSetzen() }
        .onChange(of: e.wochenberichtMinute) { terminSetzen() }
    }

    private var uhrzeit: Date {
        Calendar.current.date(bySettingHour: e.wochenberichtStunde,
                              minute: e.wochenberichtMinute,
                              second: 0,
                              of: Date()) ?? Date()
    }

    private func terminSetzen() {
        if e.wochenberichtAktiv {
            Meldungen.shared.wochenberichtPlanen(wochentag: e.wochenberichtTag,
                                                 stunde: e.wochenberichtStunde,
                                                 minute: e.wochenberichtMinute)
        } else {
            Meldungen.shared.wochenberichtAbsagen()
        }
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
