import SwiftUI
import SwiftData

/// Der Wochenbericht zum Durchsehen, bevor er rausgeht.
struct Wochenberichtansicht: View {
    @Environment(\.modelContext) private var kontext
    @EnvironmentObject private var e: Einstellungen

    @State private var bericht: Wochenbericht?
    @State private var wocheVersatz = 0
    @State private var entwurf: Mailentwurf?
    @State private var pdfDatei: Teilbare?
    @State private var meldung: String?

    var body: some View {
        List {
            Section {
                Picker("Woche", selection: $wocheVersatz) {
                    Text("Diese Woche").tag(0)
                    Text("Letzte Woche").tag(-1)
                    Text("Vorletzte Woche").tag(-2)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if let b = bericht {
                Section("Zeit") {
                    HStack(spacing: 0) {
                        Kennzahl(wert: b.arbeitszeit.alsStundenMinuten,
                                 beschriftung: "Gearbeitet", symbol: "clock")
                        Kennzahl(wert: b.soll.alsStundenMinuten,
                                 beschriftung: "Soll", symbol: "target")
                        Kennzahl(wert: b.saldo.alsSaldo,
                                 beschriftung: "Saldo", symbol: "plusminus",
                                 farbe: b.saldo >= 0 ? .green : .orange)
                    }
                    .padding(.vertical, 4)
                    LabeledContent("Zeitraum", value: b.zeitraum)
                    LabeledContent("Schichten", value: "\(b.schichten.count)")
                    if b.schritte > 0 {
                        LabeledContent("Schritte", value: "\(b.schritte)")
                    }
                }

                abschnitt("Termine nächste Woche", b.termine.map { a in
                    (a.titel, a.faellig.map { "\($0.wochentag), \($0.uhrzeit)" } ?? "")
                })
                abschnitt("Offen", b.offeneAufgaben.map {
                    ($0.titel, $0.istUeberfaellig ? "überfällig" : "")
                })
                abschnitt("Notizen dieser Woche", b.notizenDerWoche.map { ($0.titel, "") })
                abschnitt("Fehler dieser Woche", b.fehlerRang.map { ($0.0, "\($0.1)×") })
                abschnitt("Schäden dieser Woche", b.schaeden.map {
                    ($0.titel, "\($0.fotos.count) Foto\($0.fotos.count == 1 ? "" : "s")")
                })

                Section {
                    Button {
                        mailVorbereiten(b)
                    } label: {
                        Label("An Arbeitsmail senden", systemImage: "paperplane.fill")
                    }
                    .disabled(!e.mailGesetzt)

                    Button {
                        pdfDatei = Dateiablage
                            .ablegen(PDFBericht.wochenbericht(b),
                                     name: "Wochenbericht \(b.kurzzeitraum).pdf")
                            .map(Teilbare.init)
                    } label: {
                        Label("Nur PDF teilen", systemImage: "doc.richtext")
                    }
                } footer: {
                    if !e.mailGesetzt {
                        Text("Zuerst die Arbeitsmail in den Einstellungen eintragen.")
                    } else {
                        Text("Mail an \(e.arbeitsmail) wird fertig geöffnet — Bericht als PDF im Anhang. Senden bestätigst du selbst, iOS lässt das keine App im Hintergrund.")
                    }
                }
            }
        }
        .navigationTitle("Wochenbericht")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: laden)
        .onChange(of: wocheVersatz) { laden() }
        .sheet(item: $entwurf) { d in
            Mailfenster(entwurf: d) { ergebnis in
                if ergebnis == .sent { meldung = "Wochenbericht ist raus." }
            }
        }
        .sheet(item: $pdfDatei) { datei in
            Teilenblatt(gegenstaende: [datei.url])
        }
        .alert("Mail", isPresented: .init(get: { meldung != nil },
                                          set: { if !$0 { meldung = nil } })) {
            Button("Gut") { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
    }

    @ViewBuilder
    private func abschnitt(_ titel: String, _ eintraege: [(String, String)]) -> some View {
        if !eintraege.isEmpty {
            Section("\(titel) (\(eintraege.count))") {
                ForEach(Array(eintraege.enumerated()), id: \.offset) { _, zeile in
                    HStack(alignment: .top) {
                        Text(zeile.0)
                            .font(.subheadline)
                        Spacer(minLength: 12)
                        if !zeile.1.isEmpty {
                            Text(zeile.1)
                                .font(.caption)
                                .foregroundStyle(zeile.1 == "überfällig" ? .red : .secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
    }

    private func laden() {
        let datum = Calendar.current.date(byAdding: .weekOfYear,
                                          value: wocheVersatz,
                                          to: Date()) ?? Date()
        bericht = Wochenbericht.sammeln(kontext: kontext, um: datum)
    }

    private func mailVorbereiten(_ b: Wochenbericht) {
        guard Mailfenster.kannMailen else {
            meldung = "Auf diesem iPhone ist kein Mail-Konto eingerichtet. Nimm „Nur PDF teilen“."
            return
        }
        entwurf = Mailtexte.wochenbericht(b,
                                          an: e.arbeitsmail,
                                          absender: e.absenderzeile)
    }
}
