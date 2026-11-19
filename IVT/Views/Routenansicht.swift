import SwiftUI
import SwiftData
import MapKit
import CoreLocation

/// Schritte und die Route. Mehr nicht.
/// Stillstand wird nicht aufgezeichnet, die Linie reißt dort einfach ab.
struct Routenansicht: View {
    var schicht: Schicht
    /// Schrittzahl, bei laufender Schicht vom Bewegungsdienst durchgereicht
    var schritte: Int?

    @State private var bild = Wegbild()
    @State private var reglerZeit: Date = .distantPast
    @State private var kamera: MapCameraPosition = .automatic
    @State private var folgtRegler = false

    var body: some View {
        VStack(spacing: 0) {
            karte.frame(maxHeight: .infinity)

            if !bild.istLeer, let von = bild.von, let bis = bild.bis, bis > von {
                regler(von: von, bis: bis)
            }

            zahlen
        }
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: laden)
    }

    // MARK: Karte

    private var karte: some View {
        Map(position: $kamera) {
            ForEach(bild.abschnitte) { a in
                MapPolyline(coordinates: a.koordinaten)
                    .stroke(.accentColor,
                            style: StrokeStyle(lineWidth: 5.5,
                                               lineCap: .round, lineJoin: .round))
            }

            if let erster = bild.abschnitte.first?.koordinaten.first {
                Annotation("Start", coordinate: erster) {
                    punkt(.green, "play.fill")
                }
                .annotationTitles(.hidden)
            }
            if let letzter = bild.abschnitte.last?.koordinaten.last,
               bild.abschnitte.count > 1 || bild.abschnitte.first?.koordinaten.count ?? 0 > 2 {
                Annotation("Zuletzt", coordinate: letzter) {
                    punkt(.red, "stop.fill")
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
                    .opacity(bild.istPause(reglerZeit) ? 0.45 : 1)
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
                    description: Text("Für diese Schicht wurde draußen nichts aufgezeichnet. In der Halle ist das normal — die Schritte zählt das iPhone trotzdem weiter."))
                    .background(.background)
            }
        }
    }

    private func punkt(_ farbe: Color, _ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(farbe, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 1.5))
            .shadow(radius: 2, y: 1)
    }

    // MARK: Regler

    private func regler(von: Date, bis: Date) -> some View {
        VStack(spacing: 5) {
            HStack {
                Text(von.uhrzeit)
                Spacer()
                HStack(spacing: 5) {
                    Text(reglerZeit.uhrzeit)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(folgtRegler ? .primary : .secondary)
                    if folgtRegler, bild.istPause(reglerZeit) {
                        Text("· nicht aufgezeichnet")
                            .font(.caption)
                    }
                }
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
                }
            ), in: 0...bis.timeIntervalSince(von))
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .background(.bar)
    }

    // MARK: Zahlen

    private var zahlen: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    Kennzahl(wert: schritteText,
                             beschriftung: "Schritte", symbol: "shoeprints.fill")
                    Kennzahl(wert: String(format: "%.2f km", bild.gesamtMeter / 1000),
                             beschriftung: "Draußen", symbol: "map")
                    Kennzahl(wert: Wegauswertung.minuten(bild.unterwegs),
                             beschriftung: "Unterwegs", symbol: "figure.walk")
                }
                .padding(.vertical, 2)
            } footer: {
                Text("Aufgezeichnet wird nur, solange du dich bewegst. Stehst du, pausiert die Karte und die Linie reißt ab. Schritte zählt das iPhone auch in der Halle weiter — die kommen nicht aus GPS.")
            }
        }
        .listStyle(.insetGrouped)
        .frame(height: 185)
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
}
