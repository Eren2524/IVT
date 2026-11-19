import SwiftUI
import SwiftData

/// Vorher pruefen: eintragen, was raus muss, und die App sagt,
/// ob es in den DSV-Zug passt.
struct Palettenansicht: View {
    @EnvironmentObject private var e: Einstellungen
    @Environment(\.modelContext) private var kontext

    @State private var positionen: [Ladeposition] = [Ladeposition()]
    @State private var zeigeSpeichern = false
    @State private var planName = ""

    private var ergebnis: Ladeergebnis {
        Palettenrechner.rechne(positionen, konfiguration: e.zug)
    }

    var body: some View {
        NavigationStack {
            List {
                Ergebnisabschnitt(ergebnis: ergebnis)

                Section {
                    ForEach($positionen) { $p in
                        Positionszeile(position: $p)
                    }
                    .onDelete { i in
                        positionen.remove(atOffsets: i)
                        if positionen.isEmpty { positionen = [Ladeposition()] }
                    }

                    Button {
                        withAnimation { positionen.append(Ladeposition()) }
                    } label: {
                        Label("Position hinzufügen", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Was muss raus?")
                } footer: {
                    Text("Stapelbar heißt: es darf etwas darauf gestellt werden. Eine nicht stapelbare Palette belegt einen Bodenplatz und blockiert den Platz darüber.")
                }

                Zugabschnitt(ergebnis: ergebnis)

                Section {
                    Button("Zurücksetzen", role: .destructive) {
                        withAnimation { positionen = [Ladeposition()] }
                    }
                }
            }
            .navigationTitle("Laden")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        planName = "Ladung \(Date().datumKurz)"
                        zeigeSpeichern = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(ergebnis.benoetigt == 0)
                }
            }
            .alert("Ladung speichern", isPresented: $zeigeSpeichern) {
                TextField("Name", text: $planName)
                Button("Speichern") { speichern() }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }

    private func speichern() {
        guard let daten = try? JSONEncoder().encode(positionen),
              let json = String(data: daten, encoding: .utf8) else { return }
        kontext.insert(Ladeplan(name: planName, positionenJSON: json))
        try? kontext.save()
    }
}

// MARK: - Ergebnis oben

private struct Ergebnisabschnitt: View {
    var ergebnis: Ladeergebnis

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: ergebnis.passt ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title)
                        .foregroundStyle(ergebnis.passt ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kopf)
                            .font(.headline)
                        Text(unterzeile)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Stapelbalken(ergebnis: ergebnis)

                HStack(spacing: 0) {
                    Kennzahl(wert: "\(ergebnis.benoetigt)",
                             beschriftung: "Gebraucht", symbol: "shippingbox")
                    Kennzahl(wert: "\(ergebnis.konfiguration.gesamtPlaetze)",
                             beschriftung: "Vorhanden", symbol: "truck.box")
                    Kennzahl(wert: ergebnis.passt ? "\(frei)" : "\(ergebnis.ueberhang)",
                             beschriftung: ergebnis.passt ? "Noch frei" : "Zu viel",
                             symbol: ergebnis.passt ? "plus.square" : "minus.square",
                             farbe: ergebnis.passt ? .primary : .orange)
                }

                if !ergebnis.passt {
                    Hinweiszeile(
                        symbol: "truck.box.badge.clock",
                        text: "\(ergebnis.ueberhang) Stellplätze bleiben stehen. Entweder eine zweite Tour, oder nicht stapelbare Ware umpacken."
                    )
                }

                if ergebnis.blockiert > 0 {
                    Hinweiszeile(
                        symbol: "square.stack.3d.up.slash",
                        text: "\(ergebnis.blockiert) Plätze im zweiten Stock sind blockiert, weil darunter nicht stapelbare Ware steht."
                    )
                }

                ForEach(ergebnis.halbeReste, id: \.self) { h in
                    Hinweiszeile(symbol: "rectangle.split.2x1", text: h)
                }

                if ergebnis.passt, ergebnis.benoetigt > 0 {
                    Hinweiszeile(
                        symbol: "plus.circle",
                        text: "Es gehen noch \(ergebnis.nochMoeglichStapelbar) stapelbare oder \(ergebnis.nochMoeglichNichtStapelbar) nicht stapelbare Paletten mit."
                    )
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var frei: Int {
        ergebnis.konfiguration.gesamtPlaetze - ergebnis.untergebracht
    }

    private var kopf: String {
        if ergebnis.benoetigt == 0 { return "Noch nichts eingetragen" }
        return ergebnis.passt ? "Passt in den Zug" : "Passt nicht"
    }

    private var unterzeile: String {
        if ergebnis.benoetigt == 0 {
            return "\(ergebnis.konfiguration.gesamtPlaetze) Stellplätze stehen bereit."
        }
        let k = ergebnis.proKoffer
        if k.count == 2 {
            return "\(ergebnis.untergebracht) Stellplätze · \(k[0]) im LKW, \(k[1]) im Anhänger"
        }
        return "\(ergebnis.untergebracht) von \(ergebnis.konfiguration.gesamtPlaetze) Stellplätzen"
    }
}

/// Zwei Reihen Kaestchen: unten die Saeulen, oben der zweite Stock.
private struct Stapelbalken: View {
    var ergebnis: Ladeergebnis

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            reihe(titel: "2. Stock",
                  belegt: ergebnis.obenBelegt,
                  nutzbar: ergebnis.obenNutzbar,
                  gesamt: ergebnis.konfiguration.oberPlaetze)
            reihe(titel: "Boden",
                  belegt: ergebnis.bodenBelegt,
                  nutzbar: ergebnis.konfiguration.saeulen,
                  gesamt: ergebnis.konfiguration.saeulen,
                  nichtStapelbar: ergebnis.bodenNichtStapelbar)
        }
    }

    private func reihe(titel: String,
                       belegt: Int,
                       nutzbar: Int,
                       gesamt: Int,
                       nichtStapelbar: Int = 0) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(titel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(belegt) / \(gesamt)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack(spacing: 2) {
                ForEach(0..<max(gesamt, 1), id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(farbe(index: i, belegt: belegt, nutzbar: nutzbar,
                                    nichtStapelbar: nichtStapelbar))
                        .frame(height: 16)
                }
            }
        }
    }

    private func farbe(index: Int, belegt: Int, nutzbar: Int, nichtStapelbar: Int) -> Color {
        if index < belegt {
            // Die letzten Plaetze der Bodenreihe sind die nicht stapelbaren
            if nichtStapelbar > 0, index >= belegt - nichtStapelbar {
                return .orange
            }
            return .accentColor
        }
        if index >= nutzbar { return Color(.quaternarySystemFill) }
        return Color(.tertiarySystemFill)
    }
}

private struct Hinweiszeile: View {
    var symbol: String
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Eingabezeile

private struct Positionszeile: View {
    @Binding var position: Ladeposition

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                TextField("Bezeichnung, zum Beispiel Jungheinrich", text: $position.bezeichnung)
                    .textInputAutocapitalization(.sentences)
                Stepper(value: $position.anzahl, in: 0...200) {
                    Text("\(position.anzahl)")
                        .monospacedDigit()
                        .frame(minWidth: 28, alignment: .trailing)
                }
                .labelsHidden()
                .fixedSize()
            }

            HStack(spacing: 10) {
                Picker("Art", selection: $position.art) {
                    ForEach(Palettenart.allCases) { a in
                        Text(a.kurz).tag(a)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Toggle(isOn: $position.stapelbar) {
                    Text("stapelbar")
                        .font(.footnote)
                }
                .toggleStyle(.switch)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Zug-Abschnitt

private struct Zugabschnitt: View {
    var ergebnis: Ladeergebnis

    var body: some View {
        Section {
            LabeledContent("Koffer", value: "\(ergebnis.konfiguration.kofferAnzahl)")
            LabeledContent("Bodenplätze je Koffer",
                           value: "\(ergebnis.konfiguration.bodenPlaetzeProKoffer)")
            LabeledContent("Reihen je Koffer",
                           value: "\(ergebnis.konfiguration.reihenProKoffer) × 3 nebeneinander")
            LabeledContent("Stellplätze gesamt",
                           value: "\(ergebnis.konfiguration.gesamtPlaetze)")
        } header: {
            Text("Der Zug")
        } footer: {
            Text("LKW und Anhänger sind baugleich: 18 Plätze am Boden, 18 im zweiten Stock, also 36 je Koffer und 72 im ganzen Zug. Zu ändern unter Einstellungen.")
        }
    }
}
