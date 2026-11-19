import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Die Route einer Schicht: Schritte, Karte, und Infopunkte da,
/// wo etwas auffällig war. Keine Tempostufen.
struct Routenansicht: View {
    var schicht: Schicht
    /// Schrittzahl, bei laufender Schicht vom Bewegungsdienst durchgereicht
    var schritte: Int?

    @State private var bild = Wegbild()
    @State private var reglerZeit: Date = .distantPast
    @State private var gewaehlt: Auffaelligkeit?
    @State private var kamera: MapCameraPosition = .automatic
    @State private var folgtRegler = false

    var body: some View {
        VStack(spacing: 0) {
            karte.frame(maxHeight: .infinity)

            if !bild.istLeer, let von = bild.von, let bis = bild.bis, bis > von {
                regler(von: von, bis: bis)
            }

            liste
        }
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: laden)
    }

    // MARK: Karte

    private var karte: some View {
        Map(position: $kamera) {
            ForEach(bild.abschnitte) { a in
                if a.koordinaten.count > 1 {
                    if a.gangart == .luecke {
                        // Gestrichelt: hier ist nichts bekannt. Eine
                        // durchgezogene Linie wäre eine Behauptung.
                        MapPolyline(coordinates: a.koordinaten)
                            .stroke(.secondary.opacity(0.4),
                                    style: StrokeStyle(lineWidth: 3, dash: [5, 7]))
                    } else {
                        MapPolyline(coordinates: a.koordinaten)
                            .stroke(.accentColor,
                                    style: StrokeStyle(lineWidth: 5.5,
                                                       lineCap: .round, lineJoin: .round))
                    }
                }
            }

            ForEach(bild.auffaelligkeiten) { p in
                Annotation(p.titel, coordinate: p.ort) {
                    Button {
                        waehle(p)
                    } label: {
                        Image(systemName: p.art.symbol)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(punktfarbe(p.art), in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: gewaehlt?.id == p.id ? 3 : 1.5))
                            .shadow(radius: 2, y: 1)
                            .scaleEffect(gewaehlt?.id == p.id ? 1.25 : 1)
                            .animation(.bouncy, value: gewaehlt?.id)
                    }
                }
                .annotationTitles(.hidden)
            }

            if folgtRegler, let ort = bild.position(zu: reglerZeit) {
                Annotation("", coordinate: ort) {
                    ZStack {
                        Circle().fill(.white).frame(width: 20, height: 20)
                        Circle().fill(.accentColor).frame(width: 13, height: 13)
                    }
                    .shadow(radius: 3)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
        .overlay {
            if bild.istLeer {
                ContentUnavailableView(
                    "Keine Route",
                    systemImage: "map",
                    description: Text("Für diese Schicht wurden keine brauchbaren Standorte aufgezeichnet. In der Halle ist das normal — die Schritte zählt das iPhone trotzdem weiter."))
                    .background(.background)
            }
        }
    }

    // MARK: Regler

    private func regler(von: Date, bis: Date) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(von.uhrzeit)
                Spacer()
                Text(reglerZeit.uhrzeit)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(folgtRegler ? .primary : .secondary)
                Spacer()
                Text(bis.uhrzeit)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()

            Slider(value: Binding(
                get: { reglerZeit.timeIntervalSince(von) },
                set: { neu in
                    reglerZeit = von.addingTimeInterval(neu)
                    folgtRegler = true
                    gewaehlt = nil
                }
            ), in: 0...bis.timeIntervalSince(von))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.bar)
    }

    // MARK: Liste

    private var liste: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    Kennzahl(wert: schritteText,
                             beschriftung: "Schritte", symbol: "shoeprints.fill")
                    Kennzahl(wert: String(format: "%.2f km", bild.gesamtMeter / 1000),
                             beschriftung: "Draußen", symbol: "map")
                    Kennzahl(wert: Wegauswertung.minuten(bild.standzeit),
                             beschriftung: "Gestanden", symbol: "pause")
                }
                .padding(.vertical, 2)
            } footer: {
                Text("Die Strecke zählt nur, was draußen aufgezeichnet wurde. Schritte zählt das iPhone auch in der Halle weiter.")
            }

            if !bild.auffaelligkeiten.isEmpty {
                Section {
                    ForEach(bild.auffaelligkeiten) { p in
                        Button { waehle(p) } label: {
                            HStack(spacing: 12) {
                                Image(systemName: p.art.symbol)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 28, height: 28)
                                    .background(punktfarbe(p.art),
                                                in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(p.titel).font(.subheadline.weight(.medium))
                                    Text(p.text)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 6)
                                Text(p.zeit.uhrzeit)
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 2)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(gewaehlt?.id == p.id
                                           ? Color.accentColor.opacity(0.12) : nil)
                    }
                } header: {
                    Text("Auffälligkeiten")
                } footer: {
                    Text("Automatisch erkannt: längere Halte, Orte mit mehreren Besuchen und Abschnitte ohne Signal. Antippen zeigt die Stelle auf der Karte.")
                }
            }
        }
        .listStyle(.insetGrouped)
        .frame(height: 290)
    }

    // MARK: Hilfen

    private var schritteText: String {
        let n = schritte ?? schicht.schritte
        guard n > 0 else { return "—" }
        return n.formatted(.number.grouping(.automatic))
    }

    private func laden() {
        bild = Wegauswertung.auswerten(schicht.wegpunkte)
        reglerZeit = bild.von ?? schicht.start
    }

    private func waehle(_ p: Auffaelligkeit) {
        gewaehlt = p
        reglerZeit = p.zeit
        folgtRegler = false
        withAnimation {
            kamera = .region(MKCoordinateRegion(
                center: p.ort,
                latitudinalMeters: 140, longitudinalMeters: 140))
        }
    }

    private func punktfarbe(_ a: Auffaelligkeit.Art) -> Color {
        switch a {
        case .start:      return .green
        case .ende:       return .red
        case .halt:       return .orange
        case .aufenthalt: return .indigo
        case .luecke:     return .gray
        }
    }
}
