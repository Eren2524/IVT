import SwiftUI
import SafariServices

struct Newsansicht: View {
    @EnvironmentObject private var e: Einstellungen
    @ObservedObject private var dienst = Nachrichtendienst.shared
    @State private var filter: Filter = .alle
    @State private var offen: Nachricht?
    @State private var zeigeEinstellungen = false
    @State private var suche = ""

    enum Filter: String, CaseIterable, Identifiable {
        case alle = "Alle", recht = "Recht", treffer = "Stichworte", gemerkt = "Gemerkt"
        var id: String { rawValue }
    }

    private var liste: [Nachricht] {
        var l = dienst.nachrichten
        switch filter {
        case .alle: break
        case .recht: l = l.filter { Nachrichtendienst.istRecht($0) }
        case .treffer: l = l.filter { !Nachrichtendienst.treffer($0, e.newsStichworte).isEmpty }
        case .gemerkt: l = l.filter { dienst.gemerkt.contains($0.id) }
        }
        if !suche.isEmpty {
            l = l.filter { ($0.titel + " " + $0.text).localizedCaseInsensitiveContains(suche) }
        }
        return l
    }

    var body: some View {
        List {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            } footer: {
                VStack(alignment: .leading, spacing: 2) {
                    if let s = dienst.stand {
                        Text("Stand \(s.datumUndZeit) · \(dienst.nachrichten.count) Meldungen")
                    }
                    if !dienst.fehlerQuellen.isEmpty {
                        Text("Nicht erreicht: \(dienst.fehlerQuellen.joined(separator: ", "))")
                    }
                }
            }

            ForEach(liste) { n in
                Button {
                    dienst.gelesen(n)
                    offen = n
                } label: {
                    Newszeile(nachricht: n,
                              treffer: Nachrichtendienst.treffer(n, e.newsStichworte),
                              gelesen: dienst.gelesen.contains(n.id),
                              gemerkt: dienst.gemerkt.contains(n.id))
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button {
                        dienst.merken(n)
                    } label: {
                        Label(dienst.gemerkt.contains(n.id) ? "Vergessen" : "Merken",
                              systemImage: "bookmark")
                    }
                    .tint(.orange)
                }
                .contextMenu {
                    Button { dienst.merken(n) } label: { Label("Merken", systemImage: "bookmark") }
                    if let url = URL(string: n.link) {
                        ShareLink(item: url) { Label("Teilen", systemImage: "square.and.arrow.up") }
                    }
                }
            }
        }
        .searchable(text: $suche, prompt: "In News suchen")
        .navigationTitle("News")
        .refreshable { await dienst.aktualisieren(e) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { zeigeEinstellungen = true } label: { Image(systemName: "bell.badge") }
            }
        }
        .overlay {
            if liste.isEmpty {
                if dienst.laedt {
                    ProgressView("Lade News …")
                } else {
                    Leerzustand(symbol: "newspaper",
                                titel: filter == .alle ? "Noch keine News" : "Nichts gefunden",
                                text: filter == .alle ? "Zum Laden nach unten ziehen." : "In diesem Filter gibt es gerade keine Meldung.",
                                knopf: nil)
                }
            }
        }
        .task {
            // Beim Oeffnen frisch holen, wenn der Stand aelter als 20 Minuten ist
            if (dienst.stand ?? .distantPast) < Date().addingTimeInterval(-1200) {
                await dienst.aktualisieren(e)
            }
        }
        .sheet(item: $offen) { n in
            if let url = URL(string: n.link), url.scheme?.hasPrefix("http") == true {
                Safariansicht(url: url).ignoresSafeArea()
            } else {
                Text(n.text).padding()
            }
        }
        .sheet(isPresented: $zeigeEinstellungen) {
            NewsEinstellungen()
        }
    }
}

struct Newszeile: View {
    var nachricht: Nachricht
    var treffer: [String]
    var gelesen: Bool
    var gemerkt: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(nachricht.quelle)
                if let d = nachricht.datum {
                    Text("·")
                    Text(d, style: .relative)
                }
                Spacer()
                if gemerkt { Image(systemName: "bookmark.fill").foregroundStyle(.orange) }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(nachricht.titel)
                .font(.body.weight(gelesen ? .regular : .semibold))
                .foregroundStyle(gelesen ? .secondary : .primary)
                .multilineTextAlignment(.leading)

            if !nachricht.text.isEmpty {
                Text(nachricht.text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            if !treffer.isEmpty {
                HStack(spacing: 6) {
                    ForEach(treffer.prefix(3), id: \.self) { w in
                        Text(w)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

struct Safariansicht: UIViewControllerRepresentable {
    var url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let c = SFSafariViewController(url: url)
        c.dismissButtonStyle = .close
        return c
    }
    func updateUIViewController(_ c: SFSafariViewController, context: Context) {}
}

/// Stichworte fuer Mitteilungen und Quellen an/aus
struct NewsEinstellungen: View {
    @ObservedObject private var e = Einstellungen.shared
    @Environment(\.dismiss) private var schliessen
    @State private var neuesWort = ""
    @State private var neueQuelle = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Mitteilung bei Stichwort", isOn: $e.newsAlarmAktiv)
                } footer: {
                    Text("IVT schaut beim Öffnen und mehrmals am Tag im Hintergrund nach. Wann genau, entscheidet iOS (meist alle paar Stunden, öfter wenn du die App oft nutzt).")
                }

                Section("Stichworte") {
                    ForEach(e.newsStichworte, id: \.self) { w in Text(w) }
                        .onDelete { e.newsStichworte.remove(atOffsets: $0) }
                    HStack {
                        TextField("Neues Stichwort", text: $neuesWort)
                            .onSubmit(wortDazu)
                        Button("Dazu", action: wortDazu).disabled(neuesWort.isEmpty)
                    }
                }

                Section {
                    ForEach(Nachrichtendienst.standardQuellen) { q in
                        Toggle(q.name, isOn: Binding(
                            get: { !e.newsQuellenAus.contains(q.adresse) },
                            set: { an in
                                if an { e.newsQuellenAus.removeAll { $0 == q.adresse } }
                                else { e.newsQuellenAus.append(q.adresse) }
                            }))
                    }
                    ForEach(e.newsEigeneQuellen, id: \.self) { a in
                        Text(a).font(.footnote)
                    }
                    .onDelete { e.newsEigeneQuellen.remove(atOffsets: $0) }
                    HStack {
                        TextField("Eigene RSS-Adresse (https://…)", text: $neueQuelle)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Dazu", action: quelleDazu)
                            .disabled(!neueQuelle.lowercased().hasPrefix("https://"))
                    }
                } header: {
                    Text("Quellen")
                } footer: {
                    Text("Nur öffentliche Feeds. IVT liest dort nur, es wird nichts über dich verschickt.")
                }
            }
            .navigationTitle("News-Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fertig") { schliessen() } }
            }
        }
    }

    private func wortDazu() {
        let w = neuesWort.trimmingCharacters(in: .whitespaces)
        guard !w.isEmpty, !e.newsStichworte.contains(w) else { return }
        e.newsStichworte.append(w)
        neuesWort = ""
    }

    private func quelleDazu() {
        let q = neueQuelle.trimmingCharacters(in: .whitespaces)
        guard q.lowercased().hasPrefix("https://"), !e.newsEigeneQuellen.contains(q) else { return }
        e.newsEigeneQuellen.append(q)
        neueQuelle = ""
    }
}
