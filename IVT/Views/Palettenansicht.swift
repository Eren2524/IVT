import SwiftUI
import SwiftData

/// Vorher pruefen: vier Zahlen eintragen, die App sagt,
/// ob es in den DSV-Zug passt.
struct Palettenansicht: View {
    @EnvironmentObject private var e: Einstellungen
    @Environment(\.modelContext) private var kontext

    @State private var ladung = Ladung.leer
    @State private var zeigeSpeichern = false
    @State private var planName = ""

    private var ergebnis: Ladeergebnis {
        Palettenrechner.rechne(ladung, konfiguration: e.zug)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        Lademeteransicht()
                    } label: {
                        Zeile(symbol: "ruler.fill", farbe: .teal,
                              titel: "Lademeter mit eigenen Maßen", wert: nil)
                    }
                }

                Ergebnisabschnitt(ergebnis: ergebnis)

                Section {
                    Zaehlzeile(titel: "Doppelstock ladbar",
                               hinweis: "etwas darf darauf",
                               wert: $ladung.euroDoppelstock)
                    Zaehlzeile(titel: "Nicht stapelbar",
                               hinweis: "blockiert den Platz darüber",
                               wert: $ladung.euroEinzeln)
                } header: {
                    Text("Europaletten")
                }

                Section {
                    Zaehlzeile(titel: "Doppelstock ladbar",
                               hinweis: "etwas darf darauf",
                               wert: $ladung.halbDoppelstock)
                    Zaehlzeile(titel: "Nicht stapelbar",
                               hinweis: "blockiert den Platz darüber",
                               wert: $ladung.halbEinzeln)
                } header: {
                    Text("Halbpaletten")
                } footer: {
                    Text("Zwei Halbpaletten teilen sich einen Stellplatz. Gepaart wird nur innerhalb derselben Stapelbarkeit, damit keine doppelstockfähige Hälfte blockiert wird.")
                }

                Zugabschnitt(ergebnis: ergebnis)

                Section {
                    Button("Zurücksetzen", role: .destructive) {
                        withAnimation { ladung = .leer }
                    }
                    .disabled(ladung.istLeer)
                }
            }
            .navigationTitle("Laden")
            .scrollDismissesKeyboard(.interactively)
            .zifferntastaturFertig()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        planName = "Ladung \(Date().datumKurz)"
                        zeigeSpeichern = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .disabled(ladung.istLeer)
                }
            }
            .alert("Ladung speichern", isPresented: $zeigeSpeichern) {
                TextField("Name", text: $planName)
                Button("Speichern") {
                    kontext.insert(Ladeplan(name: planName, ladung: ladung))
                    try? kontext.save()
                }
                Button("Abbrechen", role: .cancel) {}
            }
        }
    }
}

// MARK: - Zaehlzeile

/// Eine Zeile: Zahl antippen und tippen, oder Plus/Minus.
private struct Zaehlzeile: View {
    var titel: String
    var hinweis: String
    @Binding var wert: Int

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(titel)
                Text(hinweis)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Zahlenfeld(wert: $wert)
            Stepper("", value: $wert, in: 0...200)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Ergebnis oben

private struct Ergebnisabschnitt: View {
    var ergebnis: Ladeergebnis

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: ergebnis.benoetigt == 0
                          ? "shippingbox"
                          : (ergebnis.passt ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"))
                        .font(.title)
                        .foregroundStyle(symbolfarbe)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(kopf).font(.headline)
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
                        text: "Es gehen noch \(ergebnis.nochMoeglichDoppelstock) doppelstockfähige oder \(ergebnis.nochMoeglichEinzeln) nicht stapelbare Paletten mit."
                    )
                }
            }
            .padding(.vertical, 6)
        }
    }

    /// Verschachtelte Ternaere im Aufruf leitet SwiftUI als
    /// HierarchicalShapeStyle her und faellt dann ueber .green.
    /// Ein benannter Color-Wert ist eindeutig.
    private var symbolfarbe: Color {
        if ergebnis.benoetigt == 0 { return .secondary }
        return ergebnis.passt ? .green : .orange
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
                  nichtStapelbar: ergebnis.bodenEinzeln)
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
