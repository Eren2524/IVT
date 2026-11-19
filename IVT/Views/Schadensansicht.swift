import SwiftUI
import UIKit
import SwiftData
import CoreLocation

struct Schadensansicht: View {
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Schadensvorgang.angelegt, order: .reverse)
    private var vorgaenge: [Schadensvorgang]

    @State private var neu = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(vorgaenge) { v in
                    NavigationLink {
                        VorgangDetail(vorgang: v)
                    } label: {
                        Vorgangszeile(vorgang: v)
                    }
                }
                .onDelete { i in
                    for index in i { kontext.delete(vorgaenge[index]) }
                    try? kontext.save()
                }
            }
            .navigationTitle("Schäden")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { neu = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $neu) { VorgangBearbeiten(vorgang: nil) }
            .overlay {
                if vorgaenge.isEmpty {
                    Leerzustand(symbol: "camera",
                                titel: "Keine Schäden erfasst",
                                text: "Jedes Foto bekommt Datum, Uhrzeit und Ort ins Bild gebrannt. Am Ende fällt ein PDF für die Reklamation raus.",
                                knopf: ("Vorgang anlegen", { neu = true }))
                }
            }
        }
    }
}

private struct Vorgangszeile: View {
    var vorgang: Schadensvorgang

    var body: some View {
        HStack(spacing: 12) {
            if let erstes = vorgang.fotos.sorted(by: { $0.aufgenommen < $1.aufgenommen }).first,
               let bild = UIImage(data: erstes.daten) {
                Image(uiImage: bild)
                    .resizable().scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(vorgang.titel)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(untertitel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if vorgang.abgeschlossen {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .font(.footnote)
            }
        }
        .padding(.vertical, 2)
    }

    private var untertitel: String {
        var teile = [vorgang.angelegt.datumKurz,
                     "\(vorgang.fotos.count) Foto\(vorgang.fotos.count == 1 ? "" : "s")"]
        if !vorgang.spediteur.isEmpty { teile.append(vorgang.spediteur) }
        return teile.joined(separator: " · ")
    }
}

// MARK: - Vorgang anlegen oder umbenennen

struct VorgangBearbeiten: View {
    var vorgang: Schadensvorgang?
    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext

    @State private var titel = ""
    @State private var spediteur = ""
    @State private var lieferschein = ""
    @State private var notiz = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Vorgang") {
                    TextField("Worum geht es?", text: $titel)
                        .textInputAutocapitalization(.sentences)
                    TextField("Spediteur", text: $spediteur)
                    TextField("Lieferschein oder Auftrag", text: $lieferschein)
                }
                Section("Beschreibung") {
                    TextField("Was ist passiert?", text: $notiz, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle(vorgang == nil ? "Neuer Schaden" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { schliessen() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { speichern() }
                        .disabled(titel.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard let v = vorgang else { return }
                titel = v.titel
                spediteur = v.spediteur
                lieferschein = v.lieferschein
                notiz = v.notiz
            }
        }
    }

    private func speichern() {
        if let v = vorgang {
            v.titel = titel
            v.spediteur = spediteur
            v.lieferschein = lieferschein
            v.notiz = notiz
        } else {
            kontext.insert(Schadensvorgang(titel: titel,
                                           spediteur: spediteur,
                                           lieferschein: lieferschein,
                                           notiz: notiz))
        }
        try? kontext.save()
        schliessen()
    }
}

// MARK: - Vorgang mit Fotos

struct VorgangDetail: View {
    @Bindable var vorgang: Schadensvorgang
    @Environment(\.modelContext) private var kontext
    @EnvironmentObject private var zeit: Zeitdienst
    @EnvironmentObject private var e: Einstellungen

    @State private var zeigeKamera = false
    @State private var zeigeBibliothek = false
    @State private var zeigeBearbeiten = false
    @State private var pdfDatei: Teilbare?
    @State private var entwurf: Mailentwurf?
    @State private var meldung: String?
    @State private var baut = false

    init(vorgang: Schadensvorgang) {
        _vorgang = Bindable(vorgang)
    }

    private var fotos: [Schadensfoto] {
        vorgang.fotos.sorted { $0.aufgenommen < $1.aufgenommen }
    }

    var body: some View {
        List {
            Section {
                if !vorgang.spediteur.isEmpty {
                    LabeledContent("Spediteur", value: vorgang.spediteur)
                }
                if !vorgang.lieferschein.isEmpty {
                    LabeledContent("Lieferschein", value: vorgang.lieferschein)
                }
                LabeledContent("Angelegt", value: vorgang.angelegt.datumUndZeit)
                Toggle("Abgeschlossen", isOn: $vorgang.abgeschlossen)
                if !vorgang.notiz.isEmpty {
                    Text(vorgang.notiz)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack(spacing: 10) {
                    Button {
                        zeigeKamera = true
                    } label: {
                        Label("Foto machen", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        zeigeBibliothek = true
                    } label: {
                        Image(systemName: "photo.on.rectangle")
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            } footer: {
                Text("Datum, Uhrzeit und Ort werden unten ins Bild gebrannt, damit das Foto im Streitfall etwas wert ist.")
            }

            if !fotos.isEmpty {
                Section("Fotos") {
                    ForEach(fotos) { f in
                        Fotozeile(foto: f)
                    }
                    .onDelete { i in
                        for index in i { kontext.delete(fotos[index]) }
                        try? kontext.save()
                    }
                }

                Section {
                    Button {
                        mailVorbereiten()
                    } label: {
                        Label(e.mailGesetzt ? "An Arbeitsmail senden" : "Als Mail senden",
                              systemImage: "paperplane.fill")
                    }

                    Button {
                        pdfBauen()
                    } label: {
                        HStack {
                            Label("Als PDF teilen", systemImage: "doc.richtext")
                            if baut {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(baut)
                } footer: {
                    if e.mailGesetzt {
                        Text(e.mailNachSchaden
                             ? "Nach jedem Foto wird die Mail an \(e.arbeitsmail) fertig geöffnet — Fotos und PDF schon dran."
                             : "Mail an \(e.arbeitsmail) mit Fotos und PDF im Anhang.")
                    } else {
                        Text("Mail wird fertig geöffnet, Fotos und PDF schon dran — nur der Empfänger fehlt. Trag ihn in den Einstellungen ein, dann fällt auch das weg.")
                    }
                }
            }
        }
        .navigationTitle(vorgang.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") { zeigeBearbeiten = true }
            }
        }
        .sheet(isPresented: $zeigeBearbeiten) { VorgangBearbeiten(vorgang: vorgang) }
        .fullScreenCover(isPresented: $zeigeKamera) {
            Kameraaufnahme(quelle: .kamera) { bild in aufnehmen(bild) }
                .ignoresSafeArea()
        }
        .sheet(isPresented: $zeigeBibliothek) {
            Kameraaufnahme(quelle: .bibliothek) { bild in aufnehmen(bild) }
        }
        .sheet(item: $pdfDatei) { datei in
            Teilenblatt(gegenstaende: [datei.url])
        }
        .sheet(item: $entwurf) { d in
            Mailfenster(entwurf: d) { ergebnis in
                if ergebnis == .sent { meldung = "Schadensmeldung ist raus." }
            }
        }
        .alert("Mail", isPresented: .init(get: { meldung != nil },
                                          set: { if !$0 { meldung = nil } })) {
            Button("Gut") { meldung = nil }
        } message: {
            Text(meldung ?? "")
        }
        .onChange(of: vorgang.abgeschlossen) { try? kontext.save() }
    }

    private func aufnehmen(_ bild: UIImage) {
        let jetzt = Date()
        let ort = zeit.standort.letzterOrt
        let ortText = ort == nil ? "" : Einstellungen.shared.firmaName

        let verkleinert = Fotostempel.verkleinern(bild)
        let gestempelt = Fotostempel.stempeln(verkleinert, mit: .init(
            zeit: jetzt,
            ortText: ortText,
            koordinate: ort?.coordinate,
            zusatz: vorgang.lieferschein.isEmpty ? nil : "LS \(vorgang.lieferschein)"
        ))

        guard let daten = Fotostempel.jpeg(gestempelt) else { return }

        let foto = Schadensfoto(daten: daten,
                                aufgenommen: jetzt,
                                ortText: ortText,
                                breite: ort?.coordinate.latitude,
                                laenge: ort?.coordinate.longitude)
        foto.vorgang = vorgang
        kontext.insert(foto)
        try? kontext.save()

        // Fuer das naechste Foto einen frischen Ort holen
        zeit.standort.einmalOrten()

        // Wenn gewuenscht, gleich die Meldung fertig hinlegen.
        // Eine hinterlegte Adresse ist dafuer nicht noetig; ohne sie
        // oeffnet Mail nur mit leerem An-Feld.
        if e.mailNachSchaden {
            mailVorbereiten()
        }
    }

    private func mailVorbereiten() {
        guard Mailfenster.kannMailen else {
            meldung = "Auf diesem iPhone ist kein Mail-Konto eingerichtet. Nimm „Als PDF teilen“."
            return
        }
        guard !vorgang.fotos.isEmpty else {
            meldung = "Noch kein Foto im Vorgang."
            return
        }
        entwurf = Mailtexte.schadensmeldung(vorgang,
                                            an: e.arbeitsmail,
                                            absender: e.absenderzeile)
    }

    private func pdfBauen() {
        baut = true
        // UIGraphicsPDFRenderer zeichnet mit UIKit und gehoert auf den
        // Hauptthread. Ein Vorgang hat selten mehr als ein Dutzend Fotos,
        // das dauert keine Sekunde.
        Task { @MainActor in
            let daten = PDFBericht.schadensbericht(vorgang)
            let url = Dateiablage.ablegen(daten, name: "Schadensbericht \(vorgang.titel).pdf")
            baut = false
            pdfDatei = url.map(Teilbare.init)
        }
    }
}

private struct Fotozeile: View {
    var foto: Schadensfoto
    @State private var gross = false

    var body: some View {
        Button {
            gross = true
        } label: {
            HStack(spacing: 12) {
                if let bild = UIImage(data: foto.daten) {
                    Image(uiImage: bild)
                        .resizable().scaledToFill()
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(foto.aufgenommen.datumUndZeit)
                        .font(.footnote.weight(.medium))
                        .monospacedDigit()
                    if !foto.ortText.isEmpty {
                        Text(foto.ortText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let b = foto.breite, let l = foto.laenge {
                        Text(String(format: "%.5f, %.5f", b, l))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $gross) {
            if let bild = UIImage(data: foto.daten) {
                NavigationStack {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: bild)
                            .resizable()
                            .scaledToFit()
                    }
                    .background(.black)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: Image(uiImage: bild),
                                      preview: SharePreview(foto.aufgenommen.datumUndZeit,
                                                            image: Image(uiImage: bild)))
                        }
                    }
                }
            }
        }
    }
}
