import SwiftUI
import UIKit
import SwiftData

struct Dashboard: View {
    @Query(filter: #Predicate<Aufgabe> { $0.erledigtAm == nil },
           sort: \Aufgabe.angelegt, order: .reverse)
    private var offeneAufgaben: [Aufgabe]

    @Query(sort: \Schadensvorgang.angelegt, order: .reverse)
    private var vorgaenge: [Schadensvorgang]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Stil.abstand) {
                    Zeitkachel()
                    SchnellzugriffReihe()
                    AufgabenKachel(aufgaben: Array(offeneAufgaben.prefix(4)))
                    BewegungKachel()
                    if !vorgaenge.isEmpty {
                        FotoKachel(vorgaenge: Array(vorgaenge.prefix(3)))
                    }
                }
                .padding(.horizontal, Stil.abstand)
                .padding(.bottom, 24)
            }
            .background(Stil.hintergrund)
            .navigationTitle(begruessung)
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var begruessung: String {
        let stunde = Calendar.current.component(.hour, from: Date())
        switch stunde {
        case 0..<5:   return "Nachtschicht"
        case 5..<11:  return "Guten Morgen"
        case 11..<14: return "Mittag"
        case 14..<18: return "Guten Tag"
        default:      return "Guten Abend"
        }
    }
}

// MARK: - Grosse Zeitkachel

private struct Zeitkachel: View {
    @EnvironmentObject private var zeit: Zeitdienst

    var body: some View {
        Karte(titel: statusText, symbol: statusSymbol) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(zeit.arbeitszeitHeute.alsStundenMinuten)
                        .font(.system(size: 46, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("von \(zeit.sollHeute.alsStundenMinuten)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Fortschritt(anteil: anteil)

                HStack(spacing: 0) {
                    Kennzahl(wert: zeit.saldoHeute.alsSaldo,
                             beschriftung: "Heute",
                             symbol: "plusminus",
                             farbe: farbe(zeit.saldoHeute))
                    Kennzahl(wert: zeit.ueberstunden.alsSaldo,
                             beschriftung: "Konto",
                             symbol: "banknote",
                             farbe: farbe(zeit.ueberstunden))
                    Kennzahl(wert: feierabendText,
                             beschriftung: "Feierabend",
                             symbol: "figure.walk.departure")
                }

                Steuerknoepfe()
            }
        }
    }

    private var anteil: Double {
        guard zeit.sollHeute > 0 else { return 0 }
        return min(1, zeit.arbeitszeitHeute / zeit.sollHeute)
    }

    private var statusText: String {
        if zeit.laufendePause != nil { return "Pause läuft" }
        if zeit.laufendeSchicht != nil { return "Arbeitszeit läuft" }
        if !Arbeitsplan.istArbeitstagHeute { return "Heute frei" }
        return zeit.arbeitszeitHeute > 0 ? "Feierabend" : "Noch nicht gestartet"
    }

    private var statusSymbol: String {
        if zeit.laufendePause != nil { return "pause.circle.fill" }
        if zeit.laufendeSchicht != nil { return "clock.fill" }
        return "clock"
    }

    private var feierabendText: String {
        guard let s = zeit.laufendeSchicht else {
            return Arbeitsplan.feierabend(am: Date())?.uhrzeit ?? "frei"
        }
        // Rechnerischer Feierabend: Start + Soll + bereits erfasste Pausen
        let ziel = s.start
            .addingTimeInterval(zeit.sollHeute)
            .addingTimeInterval(s.pausenDauer)
        return ziel.uhrzeit
    }

    private func farbe(_ wert: TimeInterval) -> Color {
        if wert > 60 { return .green }
        if wert < -60 { return .orange }
        return .primary
    }
}

private struct Fortschritt: View {
    var anteil: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.tertiarySystemFill))
                Capsule()
                    .fill(LinearGradient(colors: [.accentColor.opacity(0.75), .accentColor],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, geo.size.width * anteil))
                    .animation(.smooth, value: anteil)
            }
        }
        .frame(height: 8)
    }
}

private struct Steuerknoepfe: View {
    @EnvironmentObject private var zeit: Zeitdienst

    var body: some View {
        HStack(spacing: 10) {
            if zeit.laufendeSchicht == nil {
                Button {
                    zeit.kommen()
                } label: {
                    Label("Kommen", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                if zeit.laufendePause == nil {
                    Button {
                        zeit.pauseStarten()
                    } label: {
                        Label("Pause", systemImage: "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        zeit.pauseBeenden()
                    } label: {
                        Label("Weiter", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    zeit.gehen()
                } label: {
                    Label("Gehen", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .controlSize(.large)
    }
}

// MARK: - Schnellzugriff

private struct SchnellzugriffReihe: View {
    @State private var zeigeFehler = false
    @State private var zeigeNotiz = false
    @State private var zeigeFoto = false

    var body: some View {
        HStack(spacing: 10) {
            Schnellknopf(symbol: "exclamationmark.triangle.fill",
                         titel: "Fehler", farbe: .red) { zeigeFehler = true }
            Schnellknopf(symbol: "square.and.pencil",
                         titel: "Notiz", farbe: .orange) { zeigeNotiz = true }
            Schnellknopf(symbol: "camera.fill",
                         titel: "Schaden", farbe: .blue) { zeigeFoto = true }
        }
        .sheet(isPresented: $zeigeFehler) { FehlerErfassen() }
        .sheet(isPresented: $zeigeNotiz) { AufgabeBearbeiten(aufgabe: nil) }
        .sheet(isPresented: $zeigeFoto) { VorgangBearbeiten(vorgang: nil) }
    }
}

private struct Schnellknopf: View {
    var symbol: String
    var titel: String
    var farbe: Color
    var aktion: () -> Void

    var body: some View {
        Button(action: aktion) {
            VStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(farbe)
                Text(titel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Stil.flaeche,
                        in: RoundedRectangle(cornerRadius: Stil.kachelRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Aufgaben

private struct AufgabenKachel: View {
    var aufgaben: [Aufgabe]
    @Environment(\.modelContext) private var kontext

    var body: some View {
        Karte(titel: "Offen", symbol: "checklist") {
            if aufgaben.isEmpty {
                Text("Nichts offen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(aufgaben) { a in
                        HStack(spacing: 11) {
                            Button {
                                a.erledigtAm = Date()
                                Meldungen.shared.aufgabeAbsagen(id: a.kennung)
                                try? kontext.save()
                            } label: {
                                Image(systemName: "circle")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(a.titel)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                if let f = a.faellig {
                                    Text(f.datumUndZeit)
                                        .font(.caption2)
                                        .foregroundStyle(a.istUeberfaellig ? .red : .secondary)
                                }
                            }
                            Spacer()
                            if a.wiederholung != .keine {
                                Image(systemName: "repeat")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 7)
                        if a.id != aufgaben.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Bewegung

private struct BewegungKachel: View {
    @EnvironmentObject private var zeit: Zeitdienst

    var body: some View {
        Karte(titel: "Bewegung", symbol: "figure.walk") {
            HStack(spacing: 0) {
                Kennzahl(wert: "\(zeit.bewegung.schritteSchicht)",
                         beschriftung: "Schicht", symbol: "shoeprints.fill")
                Kennzahl(wert: "\(zeit.bewegung.schritteHeute)",
                         beschriftung: "Heute", symbol: "sun.max.fill")
                Kennzahl(wert: strecke,
                         beschriftung: "Route", symbol: "map.fill")
            }
        }
    }

    private var strecke: String {
        guard let s = zeit.laufendeSchicht else { return "—" }
        let km = Routenhilfe.laenge(s.wegpunkte) / 1000
        return km < 0.1 ? "—" : String(format: "%.1f km", km)
    }
}

// MARK: - Letzte Fotos

private struct FotoKachel: View {
    var vorgaenge: [Schadensvorgang]

    var body: some View {
        Karte(titel: "Letzte Schäden", symbol: "camera") {
            VStack(spacing: 10) {
                ForEach(vorgaenge) { v in
                    NavigationLink {
                        VorgangDetail(vorgang: v)
                    } label: {
                        HStack(spacing: 11) {
                            if let erstes = v.fotos.first,
                               let bild = UIImage(data: erstes.daten) {
                                Image(uiImage: bild)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 44, height: 44)
                                    .overlay(Image(systemName: "photo").foregroundStyle(.secondary))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(v.titel).font(.subheadline).lineLimit(1)
                                Text("\(v.fotos.count) Foto\(v.fotos.count == 1 ? "" : "s") · \(v.angelegt.datumKurz)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
