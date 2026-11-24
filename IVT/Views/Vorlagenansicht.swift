import SwiftUI
import SwiftData
import UIKit

// MARK: - Reiter "Vorlagen"

struct Vorlagenansicht: View {
    @Query(sort: \Vorlagendokument.geaendert, order: .reverse)
    private var dokumente: [Vorlagendokument]
    @Environment(\.modelContext) private var kontext

    private let spalten = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Stil.abstand) {
                    Text("Art wählen, losreden, fertig. Aus deinen Worten wird ein Dokument, nach dem jemand anderes arbeiten kann, wenn du nicht da bist.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: spalten, spacing: 10) {
                        ForEach(Dokumentart.allCases) { art in
                            NavigationLink {
                                VorlageErstellen(art: art)
                            } label: {
                                Artkachel(art: art)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if !dokumente.isEmpty {
                        Text("Zuletzt")
                            .font(.footnote.weight(.semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .padding(.top, 6)
                        VStack(spacing: 0) {
                            ForEach(dokumente.prefix(30)) { d in
                                NavigationLink {
                                    VorlageDetail(dokument: d)
                                } label: {
                                    Dokumentzeile(dokument: d)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        kontext.delete(d)
                                        try? kontext.save()
                                    } label: { Label("Löschen", systemImage: "trash") }
                                }
                                if d.id != dokumente.prefix(30).last?.id {
                                    Divider().padding(.leading, 52)
                                }
                            }
                        }
                        .background(Stil.flaeche, in: RoundedRectangle(cornerRadius: Stil.kachelRadius, style: .continuous))
                    }
                }
                .padding(.horizontal, Stil.abstand)
                .padding(.bottom, 24)
            }
            .background(Stil.hintergrund)
            .navigationTitle("Vorlagen")
        }
    }
}

extension Dokumentart {
    var systemfarbe: Color {
        switch farbe {
        case "blue": return .blue
        case "green": return .green
        case "indigo": return .indigo
        case "orange": return .orange
        case "teal": return .teal
        case "red": return .red
        default: return .gray
        }
    }
}

private struct Artkachel: View {
    var art: Dokumentart
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: art.symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(art.systemfarbe, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(art.kurz)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(art.beschreibung)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(Stil.flaeche, in: RoundedRectangle(cornerRadius: Stil.kachelRadius, style: .continuous))
        .contentShape(Rectangle())
    }
}

private struct Dokumentzeile: View {
    var dokument: Vorlagendokument
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: dokument.art.symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(dokument.art.systemfarbe, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(dokument.titel).lineLimit(1)
                Text("\(dokument.art.kurz) · \(dokument.geaendert.datumKurz)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            let l = Vorlagenschreiber.luecken(dokument.ergebnis)
            if l > 0 {
                Text("\(l) offen")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.orange)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - Neues Dokument

struct VorlageErstellen: View {
    var art: Dokumentart

    @EnvironmentObject private var e: Einstellungen
    @Environment(\.modelContext) private var kontext
    @State private var titel = ""
    @State private var roh = ""
    @State private var diktieren = false
    @State private var arbeitet = false
    @State private var fehler: String?
    @State private var fertig: Vorlagendokument?

    private var kopf: Vorlagenschreiber.Kopf {
        Vorlagenschreiber.Kopf(titel: titel.isEmpty ? art.kurz : titel, art: art,
                               ersteller: e.absenderzeile, firma: e.firmaName)
    }

    var body: some View {
        Form {
            Section {
                TextField("Titel, z. B. Lieferschein im ERP buchen", text: $titel)
            } header: {
                Text("Titel")
            }

            Section {
                ForEach(art.sprechhilfe, id: \.self) { hilfe in
                    Label(hilfe, systemImage: "text.bubble")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Das solltest du erzählen")
            }

            Section {
                Button {
                    diktieren = true
                } label: {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text(roh.isEmpty ? "Jetzt reden" : "Weiterreden")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                TextField("Oder hier tippen …", text: $roh, axis: .vertical)
                    .lineLimit(4...16)
            } header: {
                Text("Dein Diktat")
            } footer: {
                Text("Rede so, wie du es einem neuen Kollegen erklären würdest: wo du anfängst, worauf du drückst, wo du etwas findest. Ähs und Wiederholungen sind egal.")
            }

            if let fehler {
                Section {
                    Label(fehler, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.footnote)
                }
            }

            Section {
                Button {
                    Task { await mitClaude() }
                } label: {
                    Label("Mit Claude umschreiben", systemImage: "sparkles")
                }
                .disabled(roh.isEmpty || arbeitet || !Schluesselbund.vorhanden)

                Button {
                    ohneInternet()
                } label: {
                    Label("Ohne Internet ordnen", systemImage: "list.number")
                }
                .disabled(roh.isEmpty || arbeitet)
            } footer: {
                if Schluesselbund.vorhanden {
                    Text("„Mit Claude umschreiben“ schickt nur diesen Diktattext an Anthropic und rechnet über dein API-Guthaben ab. „Ohne Internet ordnen“ bleibt komplett auf dem iPhone, macht aber nur Schritte und Gliederung, kein echtes Umformulieren.")
                } else {
                    Text("Für echtes Umschreiben einmal deinen Claude-API-Schlüssel in Einstellungen > Vorlagen hinterlegen. Bis dahin ordnet die App ohne Internet: Füllwörter raus, Schritte, Gliederung.")
                }
            }
        }
        .navigationTitle(art.kurz)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if arbeitet {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Claude schreibt …").font(.subheadline)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .sheet(isPresented: $diktieren) {
            DiktatBlatt(titel: art.kurz) { neu, _, _ in
                guard !neu.isEmpty else { return }
                roh = roh.isEmpty ? neu : roh + "\n" + neu
            }
        }
        .navigationDestination(item: $fertig) { d in
            VorlageDetail(dokument: d)
        }
    }

    private func speichern(_ text: String, claude: Bool) {
        let d = Vorlagendokument(art: art, titel: kopf.titel, rohtext: roh,
                                 ergebnis: text, mitClaude: claude)
        kontext.insert(d)
        try? kontext.save()
        fertig = d
    }

    private func ohneInternet() {
        speichern(Vorlagenschreiber.ordnen(roh, kopf: kopf), claude: false)
    }

    private func mitClaude() async {
        arbeitet = true
        fehler = nil
        defer { arbeitet = false }
        do {
            let text = try await Claudedienst.schreibe(
                system: Vorlagenschreiber.systemanweisung(kopf),
                nutzer: Vorlagenschreiber.nutzertext(roh),
                modell: e.claudeModell)
            speichern(text, claude: true)
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

// MARK: - Fertiges Dokument

struct VorlageDetail: View {
    @Bindable var dokument: Vorlagendokument

    @EnvironmentObject private var e: Einstellungen
    @Environment(\.modelContext) private var kontext
    @State private var ansicht: Ansicht = .lesen
    @State private var nachdiktieren = false
    @State private var arbeitet = false
    @State private var fehler: String?
    @State private var entwurf: Mailentwurf?
    @State private var pdfURL: URL?
    @State private var meldung: String?

    enum Ansicht: String, CaseIterable, Identifiable {
        case lesen = "Dokument", bearbeiten = "Bearbeiten", diktat = "Diktat"
        var id: String { rawValue }
    }

    private var kopf: Vorlagenschreiber.Kopf {
        Vorlagenschreiber.Kopf(titel: dokument.titel, art: dokument.art,
                               ersteller: e.absenderzeile, firma: e.firmaName)
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Ansicht", selection: $ansicht) {
                ForEach(Ansicht.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            let l = Vorlagenschreiber.luecken(dokument.ergebnis)
            if l > 0 && ansicht == .lesen {
                Label("\(l) Stelle\(l == 1 ? "" : "n") noch ergänzen (rot markiert)", systemImage: "pencil.and.list.clipboard")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
            if let fehler {
                Text(fehler).font(.footnote).foregroundStyle(.orange).padding(.horizontal)
            }

            switch ansicht {
            case .lesen:
                ScrollView {
                    Dokumentleser(text: dokument.ergebnis)
                        .padding()
                }
                .background(Stil.flaeche)
            case .bearbeiten:
                TextEditor(text: $dokument.ergebnis)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 8)
            case .diktat:
                ScrollView {
                    Text(dokument.rohtext)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .background(Stil.hintergrund)
        .navigationTitle(dokument.titel)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { pdfTeilen() } label: { Label("Als PDF teilen", systemImage: "doc.richtext") }
                    Button { mailen() } label: { Label("Per Mail", systemImage: "envelope") }
                    Button {
                        UIPasteboard.general.string = dokument.ergebnis
                        meldung = "Text kopiert."
                    } label: { Label("Text kopieren", systemImage: "doc.on.doc") }
                    Divider()
                    Button { nachdiktieren = true } label: {
                        Label("Etwas ergänzen (reden)", systemImage: "mic.badge.plus")
                    }
                    if Schluesselbund.vorhanden {
                        Button { Task { await neuMitClaude() } } label: {
                            Label("Nochmal mit Claude", systemImage: "sparkles")
                        }
                    }
                    Button {
                        dokument.ergebnis = Vorlagenschreiber.ordnen(dokument.rohtext, kopf: kopf)
                        dokument.mitClaude = false
                        aenderung()
                    } label: { Label("Neu ordnen ohne Internet", systemImage: "list.number") }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .disabled(arbeitet)
            }
        }
        .overlay {
            if arbeitet {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Claude schreibt …").font(.subheadline)
                }
                .padding(24)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .onChange(of: dokument.ergebnis) { dokument.geaendert = Date() }
        .onDisappear { try? kontext.save() }
        .sheet(isPresented: $nachdiktieren) {
            DiktatBlatt(titel: "Ergänzen") { neu, _, _ in
                guard !neu.isEmpty else { return }
                dokument.rohtext += "\n" + neu
                Task {
                    if Schluesselbund.vorhanden {
                        await neuMitClaude()
                    } else {
                        dokument.ergebnis = Vorlagenschreiber.ordnen(dokument.rohtext, kopf: kopf)
                        aenderung()
                    }
                }
            }
        }
        .sheet(item: $entwurf) { d in
            Mailfenster(entwurf: d) { ergebnis in
                if ergebnis == .sent { meldung = "Mail ist raus." }
            }
        }
        .sheet(isPresented: .init(get: { pdfURL != nil }, set: { if !$0 { pdfURL = nil } })) {
            if let pdfURL { Teilenblatt(gegenstaende: [pdfURL]) }
        }
        .alert(meldung ?? "", isPresented: .init(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK") {}
        }
    }

    private func aenderung() {
        dokument.geaendert = Date()
        try? kontext.save()
    }

    private var pdfDaten: Data {
        DokumentPDF.erstelle(text: dokument.ergebnis, titel: dokument.titel)
    }

    private var dateiname: String {
        "\(dokument.art.kurz) - \(dokument.titel).pdf"
    }

    private func pdfTeilen() {
        pdfURL = Dateiablage.ablegen(pdfDaten, name: dateiname)
    }

    private func mailen() {
        guard Mailfenster.kannMailen else {
            pdfTeilen()
            return
        }
        entwurf = Mailentwurf(
            empfaenger: e.mailGesetzt ? [e.arbeitsmail] : [],
            betreff: "\(dokument.art.kurz): \(dokument.titel)",
            text: "Hallo,\n\nanbei \(dokument.art.kurz) „\(dokument.titel)“ (Stand \(Date().datumKurz)).\n\nViele Grüße\n\(e.absenderzeile)",
            anhaenge: [.init(daten: pdfDaten, typ: "application/pdf", name: dateiname)])
    }

    private func neuMitClaude() async {
        arbeitet = true
        fehler = nil
        defer { arbeitet = false }
        do {
            dokument.ergebnis = try await Claudedienst.schreibe(
                system: Vorlagenschreiber.systemanweisung(kopf),
                nutzer: Vorlagenschreiber.nutzertext(dokument.rohtext),
                modell: e.claudeModell)
            dokument.mitClaude = true
            aenderung()
        } catch {
            fehler = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

/// Zeigt das einfache Markdown huebsch an
struct Dokumentleser: View {
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, roh in
                zeile(roh.trimmingCharacters(in: .whitespaces))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func zeile(_ z: String) -> some View {
        if z.isEmpty {
            Spacer().frame(height: 4)
        } else if z.hasPrefix("## ") {
            Text(inline(String(z.dropFirst(3)))).font(.headline).padding(.top, 8)
        } else if z.hasPrefix("# ") {
            Text(inline(String(z.dropFirst(2)))).font(.title2.weight(.bold))
        } else if z.hasPrefix("- ") || z.hasPrefix("• ") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("•")
                Text(inline(String(z.dropFirst(2))))
            }
        } else if z.hasPrefix("☐ ") {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: "square")
                Text(inline(String(z.dropFirst(2))))
            }
        } else if let r = z.range(of: "^\\d+[.)] ", options: .regularExpression) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(z[r]).trimmingCharacters(in: .whitespaces))
                    .font(.body.monospacedDigit().weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 22, alignment: .trailing)
                Text(inline(String(z[r.upperBound...])))
            }
        } else if ["Dokumentart:", "Bereich:", "Erstellt von:", "Stand:", "Version:"].contains(where: { z.hasPrefix($0) }) {
            Text(z).font(.caption).foregroundStyle(.secondary)
        } else {
            Text(inline(z))
        }
    }

    private func inline(_ s: String) -> AttributedString {
        var ergebnis = AttributedString()
        var rest = Substring(s)
        while true {
            let kandidaten = ["[ERGÄNZEN", "[PRÜFEN"].compactMap { rest.range(of: $0) }
            guard let start = kandidaten.min(by: { $0.lowerBound < $1.lowerBound }) else {
                ergebnis.append(markdown(String(rest)))
                break
            }
            ergebnis.append(markdown(String(rest[..<start.lowerBound])))
            let ende = rest[start.lowerBound...].firstIndex(of: "]").map { rest.index(after: $0) } ?? rest.endIndex
            // Luecken rot
            var marke = AttributedString(String(rest[start.lowerBound..<ende]))
            marke.foregroundColor = Color.red
            ergebnis.append(marke)
            rest = rest[ende...]
        }
        return ergebnis
    }

    private func markdown(_ s: String) -> AttributedString {
        (try? AttributedString(markdown: s, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
            ?? AttributedString(s)
    }
}
