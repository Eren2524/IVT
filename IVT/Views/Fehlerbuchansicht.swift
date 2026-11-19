import SwiftUI
import SwiftData

struct Fehlerbuchansicht: View {
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Fehlereintrag.zeit, order: .reverse) private var eintraege: [Fehlereintrag]

    @State private var neu = false

    var body: some View {
        List {
            if !eintraege.isEmpty {
                Section {
                    NavigationLink {
                        Quartalsauswertung()
                    } label: {
                        Zeile(symbol: "chart.bar.fill", farbe: .indigo,
                              titel: "Quartalsauswertung", wert: aktuellesQuartal)
                    }
                } footer: {
                    Text("Die Auswertung rechnet jedes Quartal von selbst durch und lässt sich als PDF weitergeben.")
                }
            }

            ForEach(nachQuartal, id: \.quartal) { gruppe in
                Section {
                    ForEach(gruppe.eintraege) { e in
                        Fehlerzeile(eintrag: e)
                    }
                    .onDelete { i in
                        for index in i { kontext.delete(gruppe.eintraege[index]) }
                        try? kontext.save()
                    }
                } header: {
                    HStack {
                        Text(lesbar(gruppe.quartal))
                        Spacer()
                        Text("\(gruppe.eintraege.count)")
                    }
                }
            }
        }
        .navigationTitle("Fehlerbuch")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { neu = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $neu) { FehlerErfassen() }
        .overlay {
            if eintraege.isEmpty {
                Leerzustand(symbol: "exclamationmark.triangle",
                            titel: "Noch kein Fehler erfasst",
                            text: "Kategorie wählen, kurz dazuschreiben, fertig. Am Quartalsende steht die Auswertung von selbst da.",
                            knopf: ("Fehler erfassen", { neu = true }))
            }
        }
    }

    private struct Quartalsgruppe {
        var quartal: String
        var eintraege: [Fehlereintrag]
    }

    private var nachQuartal: [Quartalsgruppe] {
        Dictionary(grouping: eintraege, by: \.quartal)
            .map { Quartalsgruppe(quartal: $0.key,
                                  eintraege: $0.value.sorted { $0.zeit > $1.zeit }) }
            .sorted { $0.quartal > $1.quartal }
    }

    private var aktuellesQuartal: String {
        lesbar(Fehlereintrag.quartal(von: Date()))
    }

    private func lesbar(_ q: String) -> String {
        let teile = q.split(separator: "-")
        guard teile.count == 2 else { return q }
        return "\(teile[1])/\(teile[0])"
    }
}

private struct Fehlerzeile: View {
    var eintrag: Fehlereintrag

    var body: some View {
        HStack(spacing: 12) {
            if let daten = eintrag.foto, let bild = UIImage(data: daten) {
                Image(uiImage: bild)
                    .resizable().scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(eintrag.kategorie)
                    .font(.subheadline.weight(.medium))
                if !eintrag.notiz.isEmpty {
                    Text(eintrag.notiz)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    Text(eintrag.zeit.datumUndZeit)
                    if !eintrag.mitarbeiter.isEmpty {
                        Text("· \(eintrag.mitarbeiter)")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Erfassen

struct FehlerErfassen: View {
    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext
    @EnvironmentObject private var e: Einstellungen

    @State private var kategorie = ""
    @State private var notiz = ""
    @State private var mitarbeiter = ""
    @State private var zeit = Date()
    @State private var bild: UIImage?
    @State private var zeigeKamera = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Was ist passiert?") {
                    Picker("Kategorie", selection: $kategorie) {
                        Text("Bitte wählen").tag("")
                        ForEach(e.fehlerKategorien, id: \.self) { k in
                            Text(k).tag(k)
                        }
                    }
                    TextField("Kurz dazu", text: $notiz, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Dazu") {
                    DatePicker("Zeitpunkt", selection: $zeit)
                    TextField("Wer war beteiligt (freiwillig)", text: $mitarbeiter)
                }

                Section {
                    if let bild {
                        Image(uiImage: bild)
                            .resizable().scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        Button("Foto entfernen", role: .destructive) { self.bild = nil }
                    } else {
                        Button {
                            zeigeKamera = true
                        } label: {
                            Label("Foto dazu", systemImage: "camera")
                        }
                    }
                }
            }
            .navigationTitle("Fehler erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(kategorie.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $zeigeKamera) {
                Kameraaufnahme(quelle: .kamera) { aufnahme in
                    bild = Fotostempel.verkleinern(aufnahme, maxKante: 1400)
                }
                .ignoresSafeArea()
            }
        }
    }

    private func speichern() {
        let daten = bild.flatMap { Fotostempel.jpeg($0, guete: 0.7) }
        kontext.insert(Fehlereintrag(kategorie: kategorie,
                                     notiz: notiz,
                                     zeit: zeit,
                                     mitarbeiter: mitarbeiter,
                                     foto: daten))
        try? kontext.save()
        schliessen()
    }
}

// MARK: - Auswertung

struct Quartalsauswertung: View {
    @Query(sort: \Fehlereintrag.zeit, order: .reverse) private var alle: [Fehlereintrag]
    @State private var quartal = Fehlereintrag.quartal(von: Date())
    @State private var pdfDatei: Teilbare?

    private var quartale: [String] {
        Array(Set(alle.map(\.quartal))).sorted(by: >)
    }

    private var eintraege: [Fehlereintrag] {
        alle.filter { $0.quartal == quartal }
    }

    private var rang: [(kategorie: String, anzahl: Int)] {
        var z: [String: Int] = [:]
        for e in eintraege { z[e.kategorie, default: 0] += 1 }
        return z.sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { (kategorie: $0.key, anzahl: $0.value) }
    }

    var body: some View {
        List {
            if quartale.count > 1 {
                Section {
                    Picker("Quartal", selection: $quartal) {
                        ForEach(quartale, id: \.self) { q in Text(q).tag(q) }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section {
                HStack(spacing: 0) {
                    Kennzahl(wert: "\(eintraege.count)",
                             beschriftung: "Fehler", symbol: "number")
                    Kennzahl(wert: "\(rang.count)",
                             beschriftung: "Kategorien", symbol: "tag")
                    Kennzahl(wert: rang.first.map { "\($0.anzahl)" } ?? "—",
                             beschriftung: "Häufigster", symbol: "arrow.up")
                }
                .padding(.vertical, 4)
            }

            if let spitze = rang.first {
                Section {
                    Text(spitze.kategorie)
                        .font(.headline)
                    Text("\(spitze.anzahl) von \(eintraege.count) Fällen, das sind \(prozent(spitze.anzahl)) %. Da lohnt es sich, im Team genauer hinzuschauen.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Größter Hebel")
                }
            }

            Section("Häufigkeit") {
                ForEach(rang, id: \.kategorie) { zeile in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(zeile.kategorie)
                                .font(.subheadline)
                            Spacer()
                            Text("\(zeile.anzahl) · \(prozent(zeile.anzahl)) %")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill))
                                Capsule()
                                    .fill(Color.accentColor)
                                    .frame(width: max(4, geo.size.width * anteil(zeile.anzahl)))
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.vertical, 3)
                }
            }

            Section {
                Button {
                    let daten = PDFBericht.quartalsauswertung(quartal: quartal, eintraege: eintraege)
                    pdfDatei = Dateiablage.ablegen(daten, name: "Fehlerauswertung \(quartal).pdf")
                        .map(Teilbare.init)
                } label: {
                    Label("Auswertung als PDF teilen", systemImage: "doc.richtext")
                }
                .disabled(eintraege.isEmpty)
            }
        }
        .navigationTitle("Auswertung")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pdfDatei) { datei in
            Teilenblatt(gegenstaende: [datei.url])
        }
    }

    private func prozent(_ anzahl: Int) -> String {
        guard !eintraege.isEmpty else { return "0" }
        return String(format: "%.0f", Double(anzahl) / Double(eintraege.count) * 100)
    }

    private func anteil(_ anzahl: Int) -> Double {
        guard let max = rang.first?.anzahl, max > 0 else { return 0 }
        return Double(anzahl) / Double(max)
    }
}
