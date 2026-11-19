import SwiftUI
import SwiftData

struct Notizenansicht: View {
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Aufgabe.angelegt, order: .reverse) private var alle: [Aufgabe]

    @State private var neu = false
    @State private var bearbeite: Aufgabe?
    @State private var schnell = ""

    private var offen: [Aufgabe] { alle.filter { !$0.erledigt } }
    private var erledigt: [Aufgabe] { alle.filter(\.erledigt) }

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    TextField("Schnell notieren …", text: $schnell)
                        .submitLabel(.done)
                        .onSubmit(schnellSpeichern)
                    if !schnell.isEmpty {
                        Button("Fertig", action: schnellSpeichern)
                            .font(.footnote.weight(.semibold))
                    }
                }
            } footer: {
                Text("Eine Zeile tippen und abschicken. Erinnerung oder Rhythmus kannst du danach ergänzen.")
            }

            if !offen.isEmpty {
                Section("Offen") {
                    ForEach(offen) { a in
                        Aufgabenzeile(aufgabe: a) { abhaken(a) }
                            .onTapGesture { bearbeite = a }
                    }
                    .onDelete { i in loeschen(offen, i) }
                }
            }

            if !erledigt.isEmpty {
                Section("Erledigt") {
                    ForEach(erledigt.prefix(25)) { a in
                        Aufgabenzeile(aufgabe: a) { wiederOeffnen(a) }
                            .onTapGesture { bearbeite = a }
                    }
                    .onDelete { i in loeschen(Array(erledigt.prefix(25)), i) }
                }
            }
        }
        .navigationTitle("Aufgaben")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { neu = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $neu) { AufgabeBearbeiten(aufgabe: nil) }
        .sheet(item: $bearbeite) { a in AufgabeBearbeiten(aufgabe: a) }
        .overlay {
            if alle.isEmpty {
                Leerzustand(symbol: "checklist",
                            titel: "Nichts notiert",
                            text: "Aufgaben, Notizen und wiederkehrende Sachen wie „jeden Montag Palettenbestand“ landen hier.")
            }
        }
    }

    private func schnellSpeichern() {
        let text = schnell.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        kontext.insert(Aufgabe(titel: text))
        try? kontext.save()
        schnell = ""
    }

    private func abhaken(_ a: Aufgabe) {
        a.erledigtAm = Date()
        Meldungen.shared.aufgabeAbsagen(id: a.kennung)
        // Wiederkehrende Aufgaben legen gleich die naechste an,
        // damit nichts durchfaellt.
        if a.wiederholung != .keine, let naechste = Wiederholungsplan.naechster(
            nach: a.faellig ?? Date(), rhythmus: a.wiederholung) {
            let folge = Aufgabe(titel: a.titel,
                                notiz: a.notiz,
                                faellig: naechste,
                                wiederholung: a.wiederholung,
                                istNotiz: a.istNotiz)
            kontext.insert(folge)
            Meldungen.shared.aufgabePlanen(id: folge.kennung, titel: folge.titel, am: naechste)
        }
        try? kontext.save()
    }

    private func wiederOeffnen(_ a: Aufgabe) {
        a.erledigtAm = nil
        if let f = a.faellig {
            Meldungen.shared.aufgabePlanen(id: a.kennung, titel: a.titel, am: f)
        }
        try? kontext.save()
    }

    private func loeschen(_ liste: [Aufgabe], _ indizes: IndexSet) {
        for i in indizes {
            Meldungen.shared.aufgabeAbsagen(id: liste[i].kennung)
            kontext.delete(liste[i])
        }
        try? kontext.save()
    }
}

private struct Aufgabenzeile: View {
    var aufgabe: Aufgabe
    var umschalten: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: umschalten) {
                Image(systemName: aufgabe.erledigt ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(aufgabe.erledigt ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(aufgabe.titel)
                    .font(.subheadline)
                    .strikethrough(aufgabe.erledigt, color: .secondary)
                    .foregroundStyle(aufgabe.erledigt ? .secondary : .primary)
                HStack(spacing: 7) {
                    if let f = aufgabe.faellig {
                        Label(f.datumUndZeit, systemImage: "bell")
                            .foregroundStyle(aufgabe.istUeberfaellig ? .red : .secondary)
                    }
                    if aufgabe.wiederholung != .keine {
                        Label(aufgabe.wiederholung.anzeige, systemImage: "repeat")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption2)
                .monospacedDigit()

                if !aufgabe.notiz.isEmpty {
                    Text(aufgabe.notiz)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
        .padding(.vertical, 2)
    }
}

// MARK: - Bearbeiten

struct AufgabeBearbeiten: View {
    var aufgabe: Aufgabe?
    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext

    @State private var titel = ""
    @State private var notiz = ""
    @State private var mitErinnerung = false
    @State private var faellig = Date()
    @State private var rhythmus: Wiederholung = .keine

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Was ist zu tun?", text: $titel)
                        .textInputAutocapitalization(.sentences)
                    TextField("Notiz", text: $notiz, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section {
                    Toggle("Erinnern", isOn: $mitErinnerung)
                    if mitErinnerung {
                        DatePicker("Wann", selection: $faellig)
                    }
                }

                Section {
                    Picker("Wiederholung", selection: $rhythmus) {
                        ForEach(Wiederholung.allCases) { w in
                            Text(w.anzeige).tag(w)
                        }
                    }
                } footer: {
                    if rhythmus != .keine {
                        Text("Nach dem Abhaken legt die App die nächste Aufgabe von selbst an.")
                    }
                }
            }
            .navigationTitle(aufgabe == nil ? "Neue Aufgabe" : "Aufgabe")
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
                guard let a = aufgabe else { return }
                titel = a.titel
                notiz = a.notiz
                rhythmus = a.wiederholung
                if let f = a.faellig {
                    mitErinnerung = true
                    faellig = f
                }
            }
        }
    }

    private func speichern() {
        let ziel: Aufgabe
        if let a = aufgabe {
            ziel = a
            a.titel = titel
            a.notiz = notiz
            a.faellig = mitErinnerung ? faellig : nil
            a.wiederholung = rhythmus
            Meldungen.shared.aufgabeAbsagen(id: a.kennung)
        } else {
            ziel = Aufgabe(titel: titel,
                           notiz: notiz,
                           faellig: mitErinnerung ? faellig : nil,
                           wiederholung: rhythmus)
            kontext.insert(ziel)
        }
        if mitErinnerung {
            Meldungen.shared.aufgabePlanen(id: ziel.kennung, titel: titel, am: faellig)
        }
        try? kontext.save()
        schliessen()
    }
}

// MARK: - Rhythmus

enum Wiederholungsplan {

    /// Naechster Termin fuer einen Rhythmus.
    static func naechster(nach datum: Date,
                          rhythmus: Wiederholung,
                          kalender: Calendar = .current) -> Date? {
        switch rhythmus {
        case .keine:
            return nil
        case .taeglich:
            return kalender.date(byAdding: .day, value: 1, to: datum)
        case .woechentlich:
            return kalender.date(byAdding: .weekOfYear, value: 1, to: datum)
        case .jedenMontag:
            return naechsterWochentag(2, nach: datum, kalender: kalender)
        case .monatsende:
            return naechstesMonatsende(nach: datum, kalender: kalender)
        case .quartal:
            guard let drei = kalender.date(byAdding: .month, value: 3, to: datum) else { return nil }
            return drei
        }
    }

    private static func naechsterWochentag(_ tag: Int,
                                           nach datum: Date,
                                           kalender: Calendar) -> Date? {
        var teile = kalender.dateComponents([.hour, .minute], from: datum)
        teile.weekday = tag
        return kalender.nextDate(after: datum,
                                 matching: teile,
                                 matchingPolicy: .nextTimePreservingSmallerComponents)
    }

    private static func naechstesMonatsende(nach datum: Date, kalender: Calendar) -> Date? {
        // Erster des Folgemonats minus ein Tag, Uhrzeit beibehalten
        guard let erster = kalender.date(from: kalender.dateComponents([.year, .month], from: datum)),
              let naechsterErster = kalender.date(byAdding: .month, value: 1, to: erster),
              let ende = kalender.date(byAdding: .day, value: -1, to: naechsterErster)
        else { return nil }

        let uhrzeit = kalender.dateComponents([.hour, .minute], from: datum)
        var ziel = kalender.date(bySettingHour: uhrzeit.hour ?? 9,
                                 minute: uhrzeit.minute ?? 0,
                                 second: 0, of: ende)
        // Liegt das Monatsende schon hinter uns, direkt das naechste nehmen
        if let z = ziel, z <= datum,
           let folge = kalender.date(byAdding: .month, value: 1, to: naechsterErster),
           let endeFolge = kalender.date(byAdding: .day, value: -1, to: folge) {
            ziel = kalender.date(bySettingHour: uhrzeit.hour ?? 9,
                                 minute: uhrzeit.minute ?? 0,
                                 second: 0, of: endeFolge)
        }
        return ziel
    }
}
