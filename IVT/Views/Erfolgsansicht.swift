import SwiftUI
import SwiftData

/// Erfolge sammeln, fuer Mitarbeitergespraech und schlechte Tage
struct Erfolgsansicht: View {
    @EnvironmentObject private var e: Einstellungen
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Erfolg.datum, order: .reverse) private var erfolge: [Erfolg]

    @State private var text = ""
    @State private var art: Erfolgsart = .geloest
    @State private var entwurf: Mailentwurf?

    private var diesesJahr: [Erfolg] {
        let jahr = Calendar.current.component(.year, from: Date())
        return erfolge.filter { Calendar.current.component(.year, from: $0.datum) == jahr }
    }

    var body: some View {
        List {
            Section {
                HStack(alignment: .top) {
                    TextField("Was hast du geschafft?", text: $text, axis: .vertical)
                        .lineLimit(1...4)
                    DiktatKnopf(text: $text, titel: "Erfolg")
                }
                Picker("Art", selection: $art) {
                    ForEach(Erfolgsart.allCases) { a in
                        Label(a.rawValue, systemImage: a.symbol).tag(a)
                    }
                }
                Button("Eintragen") {
                    kontext.insert(Erfolg(text: text.trimmingCharacters(in: .whitespacesAndNewlines), art: art))
                    try? kontext.save()
                    text = ""
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("Kleine Dinge zählen auch: Fehler verhindert, Tour gerettet, Kollegen eingearbeitet. Beim Mitarbeitergespräch hast du dann alles schwarz auf weiß.")
            }

            if !erfolge.isEmpty {
                Section {
                    HStack {
                        Kennzahl(wert: "\(diesesJahr.count)", beschriftung: "Dieses Jahr", symbol: "star.fill")
                        Kennzahl(wert: "\(erfolge.count)", beschriftung: "Insgesamt", symbol: "trophy.fill")
                    }
                }

                ForEach(monate, id: \.self) { m in
                    Section(m.monatJahr) {
                        ForEach(erfolge.filter { $0.datum.monatAnfang == m }) { erfolg in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: erfolg.art.symbol)
                                    .foregroundStyle(.yellow)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(erfolg.text)
                                    Text("\(erfolg.datum.datumKurz) · \(erfolg.art.rawValue)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { i in
                            let liste = erfolge.filter { $0.datum.monatAnfang == m }
                            for index in i { kontext.delete(liste[index]) }
                            try? kontext.save()
                        }
                    }
                }
            }
        }
        .navigationTitle("Erfolge")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    ShareLink(item: zusammenfassung(erfolge: diesesJahr)) {
                        Label("Dieses Jahr teilen", systemImage: "square.and.arrow.up")
                    }
                    if Mailfenster.kannMailen {
                        Button {
                            entwurf = Mailentwurf(empfaenger: e.mailGesetzt ? [e.arbeitsmail] : [],
                                                  betreff: "Meine Erfolge \(Calendar.current.component(.year, from: Date()))",
                                                  text: zusammenfassung(erfolge: diesesJahr))
                        } label: { Label("An Arbeitsmail", systemImage: "envelope") }
                    }
                } label: { Image(systemName: "square.and.arrow.up") }
                .disabled(erfolge.isEmpty)
            }
        }
        .sheet(item: $entwurf) { d in Mailfenster(entwurf: d) }
        .overlay {
            if erfolge.isEmpty {
                Leerzustand(symbol: "trophy", titel: "Noch nichts eingetragen",
                            text: "Oben den ersten Erfolg notieren.", knopf: nil)
                    .padding(.top, 220)
            }
        }
    }

    private var monate: [Date] {
        var gesehen: [Date] = []
        for erfolg in erfolge where !gesehen.contains(erfolg.datum.monatAnfang) {
            gesehen.append(erfolg.datum.monatAnfang)
        }
        return gesehen
    }

    private func zusammenfassung(erfolge: [Erfolg]) -> String {
        var z = ["Erfolge \(Calendar.current.component(.year, from: Date())) – \(e.absenderzeile)", ""]
        for a in Erfolgsart.allCases {
            let liste = erfolge.filter { $0.art == a }
            guard !liste.isEmpty else { continue }
            z.append("\(a.rawValue) (\(liste.count))")
            for erfolg in liste.sorted(by: { $0.datum < $1.datum }) {
                z.append("- \(erfolg.datum.datumKurz): \(erfolg.text)")
            }
            z.append("")
        }
        return z.joined(separator: "\n")
    }
}

extension Date {
    var monatAnfang: Date {
        Calendar.current.dateInterval(of: .month, for: self)?.start ?? self
    }

    var monatJahr: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: self)
    }
}
