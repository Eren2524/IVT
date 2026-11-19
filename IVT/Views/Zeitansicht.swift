import SwiftUI
import SwiftData

struct Zeitansicht: View {
    @EnvironmentObject private var zeit: Zeitdienst
    @Environment(\.modelContext) private var kontext

    @Query(sort: \Schicht.start, order: .reverse) private var schichten: [Schicht]
    @State private var bearbeite: Schicht?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 0) {
                        Kennzahl(wert: zeit.arbeitszeitWoche.alsStundenMinuten,
                                 beschriftung: "Diese Woche", symbol: "calendar")
                        Kennzahl(wert: (zeit.arbeitszeitWoche - zeit.sollWocheBisHeute).alsSaldo,
                                 beschriftung: "Woche +/-", symbol: "plusminus")
                        Kennzahl(wert: zeit.ueberstunden.alsSaldo,
                                 beschriftung: "Konto", symbol: "banknote")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Überblick")
                } footer: {
                    Text("Soll: Mo–Do 8:30, Fr 6:00. Frühstückspause 9:30–9:40 und Mittagspause 12:30–13:00 werden automatisch abgezogen.")
                }

                ForEach(gruppiert, id: \.woche) { gruppe in
                    Section {
                        ForEach(gruppe.schichten) { s in
                            Button {
                                bearbeite = s
                            } label: {
                                Schichtzeile(schicht: s)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { indizes in
                            for i in indizes { kontext.delete(gruppe.schichten[i]) }
                            try? kontext.save()
                        }
                    } header: {
                        HStack {
                            Text(gruppe.woche)
                            Spacer()
                            Text(gruppe.summe.alsStundenMinuten)
                                .monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("Zeit")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let s = Schicht(start: Arbeitsplan.arbeitsbeginn(am: Date()) ?? Date(),
                                        ende: Arbeitsplan.feierabend(am: Date()))
                        kontext.insert(s)
                        try? kontext.save()
                        bearbeite = s
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $bearbeite) { s in
                Schichtbearbeiten(schicht: s)
            }
            .overlay {
                if schichten.isEmpty {
                    Leerzustand(symbol: "clock",
                                titel: "Noch keine Zeiten",
                                text: "Sobald du das Firmengelände betrittst, startet die Arbeitszeit von selbst. Du kannst sie auch von Hand starten.")
                }
            }
        }
    }

    private struct Wochengruppe {
        var woche: String
        var schichten: [Schicht]
        var summe: TimeInterval
    }

    private var gruppiert: [Wochengruppe] {
        let k = Calendar.current
        let gruppen = Dictionary(grouping: schichten) { s -> String in
            guard let i = k.dateInterval(of: .weekOfYear, for: s.start) else { return "" }
            let bis = k.date(byAdding: .day, value: -1, to: i.end) ?? i.end
            return "\(i.start.datumKurz) – \(bis.datumKurz)"
        }
        return gruppen
            .map { Wochengruppe(woche: $0.key,
                                schichten: $0.value.sorted { $0.start > $1.start },
                                summe: $0.value.reduce(0) { $0 + $1.arbeitszeit }) }
            .sorted { ($0.schichten.first?.start ?? .distantPast) > ($1.schichten.first?.start ?? .distantPast) }
    }
}

private struct Schichtzeile: View {
    var schicht: Schicht

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(schicht.start.wochentag)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(schicht.start.datumKurz)
                    .font(.footnote)
                    .monospacedDigit()
            }
            .frame(width: 74, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(schicht.start.uhrzeit)
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    if let e = schicht.ende {
                        Text(e.uhrzeit)
                    } else {
                        Text("läuft")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .font(.subheadline)
                .monospacedDigit()

                if !schicht.pausen.isEmpty {
                    Text("\(schicht.pausen.count) Pausen · \(schicht.pausenDauer.alsMinuten)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(schicht.arbeitszeit.alsStundenMinuten)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                if schicht.ende != nil {
                    Text(schicht.saldo.alsSaldo)
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(schicht.saldo >= 0 ? .green : .orange)
                }
            }

            if schicht.automatischGestartet || schicht.automatischBeendet {
                Image(systemName: "location.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Schicht korrigieren

struct Schichtbearbeiten: View {
    @Bindable var schicht: Schicht
    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext
    @State private var hatEnde: Bool
    @State private var ende: Date

    init(schicht: Schicht) {
        _schicht = Bindable(schicht)
        _hatEnde = State(initialValue: schicht.ende != nil)
        _ende = State(initialValue: schicht.ende ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kommen und Gehen") {
                    DatePicker("Kommen", selection: $schicht.start)
                    Toggle("Feierabend eingetragen", isOn: $hatEnde)
                    if hatEnde {
                        DatePicker("Gehen", selection: $ende)
                    }
                }

                Section {
                    LabeledContent("Anwesend", value: anwesenheit.alsStundenMinuten)
                    LabeledContent("Pausen", value: schicht.pausenDauer.alsMinuten)
                    LabeledContent("Arbeitszeit", value: arbeitszeit.alsStundenMinuten)
                    LabeledContent("Soll", value: schicht.soll.alsStundenMinuten)
                    LabeledContent("Saldo", value: (arbeitszeit - schicht.soll).alsSaldo)
                } header: {
                    Text("Rechnung")
                }

                if !schicht.pausen.isEmpty {
                    Section("Pausen") {
                        ForEach(schicht.pausen.sorted { $0.von < $1.von }) { p in
                            HStack {
                                Image(systemName: p.art.symbol)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 22)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(p.art.anzeige).font(.subheadline)
                                    Text("\(p.von.uhrzeit) – \(p.bis?.uhrzeit ?? "läuft")")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                Spacer()
                                Text(p.dauer.alsMinuten)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                                if p.erkannt {
                                    Image(systemName: "sparkles")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .onDelete { i in
                            let sortiert = schicht.pausen.sorted { $0.von < $1.von }
                            for index in i { kontext.delete(sortiert[index]) }
                            try? kontext.save()
                        }
                    }
                }

                Section("Notiz") {
                    TextField("Was war an dem Tag?", text: $schicht.notiz, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle(schicht.start.datumKurz)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        schicht.ende = hatEnde ? ende : nil
                        try? kontext.save()
                        schliessen()
                    }
                }
            }
        }
    }

    private var anwesenheit: TimeInterval {
        (hatEnde ? ende : Date()).timeIntervalSince(schicht.start)
    }

    private var arbeitszeit: TimeInterval {
        max(0, anwesenheit - schicht.pausenDauer)
    }
}

