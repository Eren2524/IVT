import SwiftUI
import SwiftData

/// Lademeter mit eigenen Palettenmassen
struct Lademeteransicht: View {
    @EnvironmentObject private var e: Einstellungen
    @Environment(\.modelContext) private var kontext
    @Query(sort: \Palettenmass.name) private var gemerkte: [Palettenmass]

    @State private var posten: [Lademeter.Posten] = []
    @State private var eigeneOffen = false
    @State private var bearbeiten: Lademeter.Posten?

    private var ergebnis: Lademeter.Ergebnis {
        Lademeter.rechne(posten, kofferLaenge: e.kofferLaenge, kofferAnzahl: e.kofferAnzahl)
    }

    var body: some View {
        List {
            ergebnisAbschnitt

            Section {
                ForEach($posten) { $p in
                    Postenzeile(posten: $p)
                        .contentShape(Rectangle())
                        .onTapGesture { bearbeiten = p }
                }
                .onDelete { posten.remove(atOffsets: $0) }

                Menu {
                    Section("Standard") {
                        ForEach(Lademeter.vorgaben, id: \.name) { v in
                            Button("\(v.name)  \(v.l) × \(v.b)") {
                                dazu(.init(name: v.name, laengeCm: v.l, breiteCm: v.b, anzahl: 1, stapelbar: false))
                            }
                        }
                    }
                    if !gemerkte.isEmpty {
                        Section("Gemerkt") {
                            ForEach(gemerkte) { m in
                                Button("\(m.name)  \(m.laengeCm) × \(m.breiteCm)") {
                                    dazu(.init(name: m.name, laengeCm: m.laengeCm, breiteCm: m.breiteCm,
                                               anzahl: 1, stapelbar: m.stapelbar, gewichtKg: m.gewichtKg))
                                }
                            }
                        }
                    }
                    Button {
                        eigeneOffen = true
                    } label: {
                        Label("Eigene Maße …", systemImage: "ruler")
                    }
                } label: {
                    Label("Palette hinzufügen", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Ladung")
            } footer: {
                Text("Tippen zum Ändern. „Doppelstock“ heißt: es darf eine zweite darauf, dann zählen zwei Stück als ein Stellplatz.")
            }

            if !gemerkte.isEmpty {
                Section("Gemerkte Maße") {
                    ForEach(gemerkte) { m in
                        HStack {
                            Text(m.name)
                            Spacer()
                            Text("\(m.laengeCm) × \(m.breiteCm) cm")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .onDelete { i in
                        for index in i { kontext.delete(gemerkte[index]) }
                        try? kontext.save()
                    }
                }
            }

            Section {
                HStack {
                    Text("Länge pro Koffer")
                    Spacer()
                    Stepper(Lademeter.meter(e.kofferLaenge), value: $e.kofferLaenge, in: 4...13.6, step: 0.1)
                        .fixedSize()
                }
                Button("Alles leeren", role: .destructive) {
                    withAnimation { posten.removeAll() }
                }
                .disabled(posten.isEmpty)
            } footer: {
                Text("Formel wie bei Spediteuren: Länge × Breite ÷ 2,40 m je Stellplatz. „Real“ stellt Reihe für Reihe über 2,40 m Breite, längs oder quer, was kürzer ist, und teilt keine Reihe auf zwei Koffer.")
            }
        }
        .navigationTitle("Lademeter")
        .scrollDismissesKeyboard(.interactively)
        .zifferntastaturFertig()
        .sheet(isPresented: $eigeneOffen) {
            EigenesMass { p, merken in
                dazu(p)
                if merken {
                    kontext.insert(Palettenmass(name: p.name, laengeCm: p.laengeCm, breiteCm: p.breiteCm,
                                                gewichtKg: p.gewichtKg, stapelbar: p.stapelbar))
                    try? kontext.save()
                }
            }
        }
        .sheet(item: $bearbeiten) { p in
            EigenesMass(vorlage: p) { neu, merken in
                if let i = posten.firstIndex(where: { $0.id == p.id }) {
                    var ersetzt = neu
                    ersetzt.id = p.id
                    posten[i] = ersetzt
                }
                if merken {
                    kontext.insert(Palettenmass(name: neu.name, laengeCm: neu.laengeCm, breiteCm: neu.breiteCm,
                                                gewichtKg: neu.gewichtKg, stapelbar: neu.stapelbar))
                    try? kontext.save()
                }
            }
        }
    }

    private func dazu(_ p: Lademeter.Posten) {
        withAnimation { posten.append(p) }
    }

    @ViewBuilder
    private var ergebnisAbschnitt: some View {
        let r = ergebnis
        Section {
            HStack(alignment: .top) {
                Kennzahl(wert: Lademeter.ldm(r.formelLDM), beschriftung: "Lademeter (Formel)", symbol: "ruler")
                Kennzahl(wert: Lademeter.meter(r.realeLaenge), beschriftung: "Real gestellt", symbol: "square.grid.3x1.below.line.grid.1x2")
            }
            HStack(alignment: .top) {
                Kennzahl(wert: "\(r.stellplaetze)", beschriftung: "Stellplätze", symbol: "square.stack.3d.up")
                Kennzahl(wert: "\(r.stueck)", beschriftung: "Stück", symbol: "shippingbox")
                Kennzahl(wert: r.gewicht > 0 ? gewichtText(r.gewicht) : "–", beschriftung: "Gewicht", symbol: "scalemass")
            }
            if !r.zuBreit.isEmpty {
                Label("Zu breit für 2,40 m: \(r.zuBreit.joined(separator: ", "))", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.footnote)
            }
        }

        if r.stueck > 0 {
            Section("Passt in") {
                ForEach(r.vergleiche) { v in
                    HStack(spacing: 12) {
                        Image(systemName: v.passt ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(v.passt ? Color.green : Color.red)
                            .font(.title3)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(v.fahrzeug.name)
                            if v.fahrzeug.flaechen.count > 1 {
                                Text(v.belegung.enumerated().map { "Koffer \($0.offset + 1): \(Lademeter.meter($0.element))" }
                                        .joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(v.passt ? "\(Lademeter.meter(v.rest)) frei" : "\(Lademeter.meter(-v.rest)) zu viel")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(v.passt ? Color.secondary : Color.red)
                    }
                }
            }
        }
    }

    private func gewichtText(_ kg: Double) -> String {
        kg >= 1000 ? String(format: "%.1f t", kg / 1000).replacingOccurrences(of: ".", with: ",")
                   : "\(Int(kg)) kg"
    }
}

private struct Postenzeile: View {
    @Binding var posten: Lademeter.Posten

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(posten.name.isEmpty ? "Palette" : posten.name)
                    Text("\(posten.laengeCm) × \(posten.breiteCm) cm · \(Lademeter.ldm(posten.formelLDM)) LDM")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                Zahlenfeld(wert: $posten.anzahl)
                Stepper("", value: $posten.anzahl, in: 0...200)
                    .labelsHidden()
            }
            Toggle("Doppelstock ladbar", isOn: $posten.stapelbar)
                .font(.footnote)
                .tint(Color.accentColor)
        }
        .padding(.vertical, 2)
    }
}

/// Eingabe eigener Masse
struct EigenesMass: View {
    var vorlage: Lademeter.Posten?
    var fertig: (Lademeter.Posten, Bool) -> Void

    @Environment(\.dismiss) private var schliessen
    @State private var name = ""
    @State private var laenge = ""
    @State private var breite = ""
    @State private var anzahl = 1
    @State private var gewicht = ""
    @State private var stapelbar = false
    @State private var merken = false

    private var l: Int { Int(laenge) ?? 0 }
    private var b: Int { Int(breite) ?? 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Bezeichnung (z. B. Kiste groß)", text: $name)
                    HStack {
                        Text("Länge")
                        Spacer()
                        TextField("cm", text: $laenge)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Breite")
                        Spacer()
                        TextField("cm", text: $breite)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("cm").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Gewicht pro Stück")
                        Spacer()
                        TextField("optional", text: $gewicht)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kg").foregroundStyle(.secondary)
                    }
                } footer: {
                    if l > 0 && b > 0 {
                        let ldm = (Double(l) / 100) * (Double(b) / 100) / Lademeter.ladebreite
                        Text("Ein Stellplatz = \(Lademeter.ldm(ldm)) Lademeter")
                    }
                }
                Section {
                    HStack {
                        Text("Anzahl")
                        Spacer()
                        Zahlenfeld(wert: $anzahl, bereich: 1...200)
                        Stepper("", value: $anzahl, in: 1...200).labelsHidden()
                    }
                    Toggle("Doppelstock ladbar", isOn: $stapelbar)
                    Toggle("Maß für später merken", isOn: $merken)
                }
            }
            .navigationTitle(vorlage == nil ? "Eigene Maße" : "Ändern")
            .zifferntastaturFertig()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { schliessen() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        let kg = Double(gewicht.replacingOccurrences(of: ",", with: ".")) ?? 0
                        fertig(.init(name: name.isEmpty ? "\(l) × \(b)" : name,
                                     laengeCm: l, breiteCm: b, anzahl: anzahl,
                                     stapelbar: stapelbar, gewichtKg: kg), merken)
                        schliessen()
                    }
                    .disabled(l <= 0 || b <= 0)
                }
            }
            .onAppear {
                guard let v = vorlage else { return }
                name = v.name
                laenge = "\(v.laengeCm)"
                breite = "\(v.breiteCm)"
                anzahl = max(1, v.anzahl)
                stapelbar = v.stapelbar
                gewicht = v.gewichtKg > 0 ? String(format: "%g", v.gewichtKg) : ""
            }
        }
    }
}
