import SwiftUI
import SwiftData
import UserNotifications

/// Wer wurde wann worin unterwiesen, wann ist es wieder faellig.
struct Unterweisungsansicht: View {
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Unterweisung.datum, order: .reverse) private var alle: [Unterweisung]
    @State private var neu = false

    /// Pro Person und Thema nur die letzte Unterweisung zaehlt
    private var aktuell: [Unterweisung] {
        var gesehen = Set<String>()
        var l: [Unterweisung] = []
        for u in alle {
            let k = u.person.lowercased() + "|" + u.thema.lowercased()
            if gesehen.insert(k).inserted { l.append(u) }
        }
        return l.sorted { $0.faellig < $1.faellig }
    }

    var body: some View {
        List {
            let ueberfaellig = aktuell.filter { $0.restTage < 0 }
            let bald = aktuell.filter { (0...30).contains($0.restTage) }
            let ok = aktuell.filter { $0.restTage > 30 }

            if !ueberfaellig.isEmpty {
                Section("Überfällig") { ForEach(ueberfaellig) { Unterweisungszeile(u: $0) } }
            }
            if !bald.isEmpty {
                Section("In den nächsten 30 Tagen") { ForEach(bald) { Unterweisungszeile(u: $0) } }
            }
            if !ok.isEmpty {
                Section("Erledigt") { ForEach(ok) { Unterweisungszeile(u: $0) } }
            }
            if alle.count > aktuell.count {
                Section("Verlauf") {
                    ForEach(alle.filter { u in !aktuell.contains { $0.id == u.id } }) { u in
                        Unterweisungszeile(u: u, verlauf: true)
                    }
                }
            }
        }
        .navigationTitle("Unterweisungen")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { neu = true } label: { Image(systemName: "plus") }
            }
        }
        .overlay {
            if alle.isEmpty {
                Leerzustand(symbol: "person.badge.shield.checkmark",
                            titel: "Noch keine Unterweisungen",
                            text: "Trag ein, wen du wann unterwiesen hast. IVT erinnert 14 Tage vor der nächsten.",
                            knopf: ("Eintragen", { neu = true }))
            }
        }
        .sheet(isPresented: $neu) {
            UnterweisungNeu(personen: Array(Set(alle.map(\.person))).sorted(),
                            themen: Array(Set(alle.map(\.thema) + ["Ladungssicherung", "Flurförderzeuge", "Brandschutz", "Erste Hilfe", "Gefahrgut"])).sorted())
        }
    }
}

private struct Unterweisungszeile: View {
    var u: Unterweisung
    var verlauf = false
    @Environment(\.modelContext) private var kontext

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(farbe)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(u.person).font(.body.weight(.medium))
                Text("\(u.thema) · \(u.datum.datumKurz)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !verlauf {
                Text(restText)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(farbe)
            }
        }
        .swipeActions {
            Button(role: .destructive) {
                Unterweisungserinnerung.absagen(u)
                kontext.delete(u)
                try? kontext.save()
            } label: { Label("Löschen", systemImage: "trash") }
        }
    }

    private var restText: String {
        let t = u.restTage
        if t < 0 { return "seit \(-t) Tg." }
        if t == 0 { return "heute" }
        if t < 60 { return "in \(t) Tg." }
        return u.faellig.datumKurz
    }

    private var farbe: Color {
        if verlauf { return .secondary }
        if u.restTage < 0 { return .red }
        if u.restTage <= 30 { return .orange }
        return .green
    }

    private var symbol: String {
        if verlauf { return "clock.arrow.circlepath" }
        if u.restTage < 0 { return "exclamationmark.circle.fill" }
        if u.restTage <= 30 { return "clock.badge.exclamationmark.fill" }
        return "checkmark.seal.fill"
    }
}

private struct UnterweisungNeu: View {
    var personen: [String]
    var themen: [String]

    @Environment(\.dismiss) private var schliessen
    @Environment(\.modelContext) private var kontext
    @State private var namen = ""
    @State private var thema = "Ladungssicherung"
    @State private var datum = Date()
    @State private var intervall = 12
    @State private var notiz = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Namen, mit Komma getrennt", text: $namen, axis: .vertical)
                    if !personen.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(personen, id: \.self) { p in
                                    Button(p) {
                                        namen = namen.isEmpty ? p : namen + ", " + p
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.footnote)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Wer")
                } footer: {
                    Text("Mehrere auf einmal: jede Person bekommt einen eigenen Eintrag.")
                }
                Section("Was und wann") {
                    Picker("Thema", selection: $thema) {
                        ForEach(themen, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("oder eigenes Thema", text: $thema)
                    DatePicker("Datum", selection: $datum, displayedComponents: .date)
                    Picker("Wiederholen", selection: $intervall) {
                        Text("Halbjährlich").tag(6)
                        Text("Jährlich").tag(12)
                        Text("Alle 2 Jahre").tag(24)
                    }
                    TextField("Notiz", text: $notiz)
                }
            }
            .navigationTitle("Unterweisung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        let liste = namen.split(separator: ",")
                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                            .filter { !$0.isEmpty }
                        for n in liste {
                            let u = Unterweisung(person: n, thema: thema, datum: datum,
                                                 intervallMonate: intervall, notiz: notiz)
                            kontext.insert(u)
                            Unterweisungserinnerung.planen(u)
                        }
                        try? kontext.save()
                        schliessen()
                    }
                    .disabled(namen.trimmingCharacters(in: .whitespaces).isEmpty || thema.isEmpty)
                }
            }
        }
    }
}

enum Unterweisungserinnerung {
    static func planen(_ u: Unterweisung) {
        let k = Calendar.current
        guard let vorher = k.date(byAdding: .day, value: -14, to: u.faellig),
              let zeitpunkt = k.date(bySettingHour: 7, minute: 15, second: 0, of: vorher),
              zeitpunkt > Date() else { return }
        let inhalt = UNMutableNotificationContent()
        inhalt.title = "Unterweisung in 14 Tagen fällig"
        inhalt.body = "\(u.person): \(u.thema) (zuletzt \(u.datum.datumKurz))"
        inhalt.sound = .default
        let ausloeser = UNCalendarNotificationTrigger(
            dateMatching: k.dateComponents([.year, .month, .day, .hour, .minute], from: zeitpunkt),
            repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "unterweisung-\(u.kennung.uuidString)",
                                  content: inhalt, trigger: ausloeser))
    }

    static func absagen(_ u: Unterweisung) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["unterweisung-\(u.kennung.uuidString)"])
    }
}
