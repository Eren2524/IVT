import SwiftUI
import UIKit
import SwiftData
import AVFoundation

// MARK: - Diktat-Blatt (fuer jedes Textfeld)

/// Grosser Aufnahmeknopf, Text laeuft live mit, danach noch korrigierbar.
struct DiktatBlatt: View {
    var titel: String = "Diktieren"
    var mitTon: Bool = false
    /// Text und, falls mit Ton, Datei + Dauer
    var fertig: (_ text: String, _ ton: URL?, _ dauer: TimeInterval) -> Void

    @ObservedObject private var e = Einstellungen.shared
    @Environment(\.dismiss) private var schliessen
    @StateObject private var diktat = Diktierdienst()
    @State private var bearbeitet = ""
    @State private var uebernommen = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Group {
                    if diktat.laeuft {
                        ScrollViewReader { leser in
                            ScrollView {
                                Text(diktat.text.isEmpty ? "Sprich einfach los …" : diktat.text)
                                    .font(.title3)
                                    .foregroundStyle(diktat.text.isEmpty ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("ende")
                            }
                            .onChange(of: diktat.text) { leser.scrollTo("ende", anchor: .bottom) }
                        }
                    } else {
                        TextEditor(text: $bearbeitet)
                            .font(.title3)
                            .scrollContentBackground(.hidden)
                            .overlay(alignment: .topLeading) {
                                if bearbeitet.isEmpty {
                                    Text("Tippe unten auf das Mikrofon und sprich. Danach kannst du hier noch korrigieren.")
                                        .font(.title3)
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Stil.flaeche, in: RoundedRectangle(cornerRadius: Stil.kachelRadius, style: .continuous))

                if let f = diktat.fehler {
                    Label(f, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Aufnahmeknopf(laeuft: diktat.laeuft, pegel: diktat.pegel, start: diktat.startZeit) {
                    if diktat.laeuft {
                        diktat.stoppen()
                        bearbeitet = diktat.text
                    } else {
                        Task {
                            await diktat.starten(mitTon: mitTon, nurAufGeraet: e.diktatNurAufGeraet)
                            if diktat.laeuft, !bearbeitet.isEmpty {
                                // weiterdiktieren haengt an
                                diktat.ersetzeText(bearbeitet)
                            }
                        }
                    }
                }

                Text(e.diktatNurAufGeraet ? "Erkennung nur auf dem iPhone" : "Erkennung über Apple-Spracherkennung")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Stil.hintergrund)
            .navigationTitle(titel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        diktat.verwerfen()
                        schliessen()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Übernehmen") {
                        if diktat.laeuft {
                            diktat.stoppen()
                            bearbeitet = diktat.text
                        }
                        uebernommen = true
                        fertig(bearbeitet.trimmingCharacters(in: .whitespacesAndNewlines),
                               diktat.tonURL, diktat.dauer)
                        schliessen()
                    }
                    .fontWeight(.semibold)
                    .disabled(bearbeitet.isEmpty && diktat.text.isEmpty)
                }
            }
            .onDisappear {
                if !uebernommen { diktat.verwerfen() }
            }
        }
    }
}

/// Runder Aufnahmeknopf mit Pegel und laufender Zeit
struct Aufnahmeknopf: View {
    var laeuft: Bool
    var pegel: Float
    var start: Date?
    var aktion: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: aktion) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.18))
                        .frame(width: 96, height: 96)
                        .scaleEffect(laeuft ? 1 + CGFloat(pegel) * 0.35 : 1)
                        .animation(.easeOut(duration: 0.12), value: pegel)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)
                    Image(systemName: laeuft ? "stop.fill" : "mic.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact, trigger: laeuft)
            .accessibilityLabel(laeuft ? "Aufnahme beenden" : "Aufnahme starten")

            if let start, laeuft {
                TimelineView(.periodic(from: start, by: 1)) { kontext in
                    Text(Date().timeIntervalSince(start).alsUhr)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            } else {
                Text(" ").font(.footnote)
            }
        }
    }
}

extension TimeInterval {
    /// 1:05 fuer Aufnahmedauer
    var alsUhr: String {
        let s = Int(self.rounded())
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}

/// Kleiner Mikrofonknopf neben Textfeldern. Diktierter Text wird angehaengt.
struct DiktatKnopf: View {
    @Binding var text: String
    var titel: String = "Diktieren"
    @State private var offen = false

    var body: some View {
        Button {
            offen = true
        } label: {
            Image(systemName: "mic.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Diktieren")
        .sheet(isPresented: $offen) {
            DiktatBlatt(titel: titel) { neu, _, _ in
                guard !neu.isEmpty else { return }
                text = text.isEmpty ? neu : text + (text.hasSuffix("\n") ? "" : " ") + neu
            }
        }
    }
}

// MARK: - Sprachnotizen

struct Sprachnotizenansicht: View {
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Sprachnotiz.angelegt, order: .reverse) private var notizen: [Sprachnotiz]
    @StateObject private var abspieler = Abspieler()
    @State private var neu = false
    @State private var suche = ""

    private var gefiltert: [Sprachnotiz] {
        guard !suche.isEmpty else { return notizen }
        return notizen.filter { $0.text.localizedCaseInsensitiveContains(suche) }
    }

    var body: some View {
        List {
            ForEach(gefiltert) { n in
                NavigationLink {
                    SprachnotizDetail(notiz: n, abspieler: abspieler)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(n.text.isEmpty ? "Ohne Text" : n.text)
                            .lineLimit(2)
                        HStack(spacing: 6) {
                            Text(n.angelegt.datumUndZeit)
                            if n.tonDatei != nil {
                                Text("·")
                                Image(systemName: "waveform")
                                Text(n.dauer.alsUhr)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { i in
                for index in i {
                    let n = gefiltert[index]
                    if let url = n.tonURL { try? FileManager.default.removeItem(at: url) }
                    kontext.delete(n)
                }
                try? kontext.save()
            }
        }
        .searchable(text: $suche, prompt: "In Notizen suchen")
        .navigationTitle("Sprachnotizen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { neu = true } label: { Image(systemName: "mic.badge.plus") }
            }
        }
        .overlay {
            if notizen.isEmpty {
                Leerzustand(symbol: "waveform",
                            titel: "Noch keine Sprachnotizen",
                            text: "Aufnehmen, die App schreibt mit. Ton und Text bleiben auf dem iPhone.",
                            knopf: ("Aufnehmen", { neu = true }))
            }
        }
        .sheet(isPresented: $neu) {
            DiktatBlatt(titel: "Sprachnotiz", mitTon: true) { text, ton, dauer in
                kontext.insert(Sprachnotiz(text: text, tonDatei: ton?.lastPathComponent, dauer: dauer))
                try? kontext.save()
            }
        }
        .onDisappear { abspieler.stopp() }
    }
}

struct SprachnotizDetail: View {
    @Bindable var notiz: Sprachnotiz
    @ObservedObject var abspieler: Abspieler
    @Environment(\.modelContext) private var kontext
    @State private var meldung: String?

    var body: some View {
        Form {
            if let url = notiz.tonURL {
                Section {
                    Button {
                        abspieler.umschalten(url)
                    } label: {
                        Label(abspieler.spielt == url ? "Anhalten" : "Abspielen (\(notiz.dauer.alsUhr))",
                              systemImage: abspieler.spielt == url ? "pause.circle.fill" : "play.circle.fill")
                    }
                }
            }
            Section("Text") {
                TextField("Text", text: $notiz.text, axis: .vertical)
                    .lineLimit(4...20)
            }
            Section {
                Button {
                    kontext.insert(Aufgabe(titel: String(notiz.text.prefix(80)), notiz: notiz.text))
                    try? kontext.save()
                    meldung = "Als Aufgabe angelegt."
                } label: {
                    Label("Als Aufgabe übernehmen", systemImage: "checklist")
                }
                Button {
                    UIPasteboard.general.string = notiz.text
                    meldung = "Text kopiert."
                } label: {
                    Label("Text kopieren", systemImage: "doc.on.doc")
                }
                ShareLink(item: notiz.text) {
                    Label("Teilen", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle(notiz.angelegt.datumKurz)
        .navigationBarTitleDisplayMode(.inline)
        .alert(meldung ?? "", isPresented: .init(get: { meldung != nil }, set: { if !$0 { meldung = nil } })) {
            Button("OK") {}
        }
        .onDisappear { try? kontext.save() }
    }
}

@MainActor
final class Abspieler: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var spielt: URL?
    private var spieler: AVAudioPlayer?

    func umschalten(_ url: URL) {
        if spielt == url { stopp(); return }
        stopp()
        try? AVAudioSession.sharedInstance().setCategory(.playback)
        try? AVAudioSession.sharedInstance().setActive(true)
        spieler = try? AVAudioPlayer(contentsOf: url)
        spieler?.delegate = self
        spieler?.play()
        spielt = spieler == nil ? nil : url
    }

    func stopp() {
        spieler?.stop()
        spieler = nil
        spielt = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stopp() }
    }
}
