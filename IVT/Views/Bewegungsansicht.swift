import SwiftUI
import SwiftData
import MapKit
import CoreLocation

struct Bewegungsansicht: View {
    @EnvironmentObject private var zeit: Zeitdienst
    @Query(sort: \Schicht.start, order: .reverse) private var schichten: [Schicht]

    @State private var gewaehlt: Schicht?
    @State private var suchzeit = Date()
    @State private var treffer: Wegpunkt?
    @State private var gesucht = false

    private var schicht: Schicht? {
        gewaehlt ?? zeit.laufendeSchicht ?? schichten.first
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 0) {
                    Kennzahl(wert: "\(zeit.bewegung.schritteHeute)",
                             beschriftung: "Schritte heute", symbol: "shoeprints.fill")
                    Kennzahl(wert: strecke, beschriftung: "Strecke", symbol: "map.fill")
                    Kennzahl(wert: punkte, beschriftung: "Punkte", symbol: "mappin")
                }
                .padding(.vertical, 4)
            } footer: {
                Text("In der Halle ist GPS praktisch unbrauchbar. Die Route ist nur im Freien belastbar, drinnen zählt der Schrittzähler weiter.")
            }

            if schichten.count > 1 {
                Section {
                    Picker("Schicht", selection: Binding(
                        get: { schicht },
                        set: { gewaehlt = $0 }
                    )) {
                        ForEach(schichten.prefix(30)) { s in
                            Text("\(s.start.datumKurz), \(s.start.uhrzeit)")
                                .tag(Optional(s))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            if let s = schicht, !s.wegpunkte.isEmpty {
                Section {
                    Routenkarte(punkte: s.wegpunkte, hervorgehoben: treffer)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .listRowInsets(EdgeInsets())

                    NavigationLink {
                        Routenansicht(schicht: s,
                                      schritte: s.laeuft ? zeit.bewegung.schritteSchicht : nil)
                    } label: {
                        Zeile(symbol: "point.topleft.down.to.point.bottomright.curvepath",
                              farbe: .indigo,
                              titel: "Route auf der Karte",
                              wert: auffaellig(s))
                    }
                } header: {
                    Text("Route")
                } footer: {
                    Text("Aufgezeichnet wird nur, solange du dich bewegst. Stehst du, pausiert die Karte.")
                }
            }

            Section {
                DatePicker("Uhrzeit", selection: $suchzeit)
                Button {
                    treffer = zeit.wegpunkt(nahe: suchzeit)
                    gesucht = true
                } label: {
                    Label("Wo war ich da?", systemImage: "magnifyingglass")
                }

                if gesucht {
                    if let t = treffer {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(t.zeit.datumUndZeit)
                                .font(.subheadline.weight(.medium))
                                .monospacedDigit()
                            Text(String(format: "%.5f, %.5f  (±%.0f m)",
                                        t.breite, t.laenge, t.genauigkeit))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Button {
                                inKartenAppOeffnen(t)
                            } label: {
                                Label("In Karten öffnen", systemImage: "arrow.up.right.square")
                                    .font(.footnote)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, 2)
                    } else {
                        Text("Für diese Uhrzeit liegt kein Punkt vor. Wahrscheinlich warst du in der Halle.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Wo war ich?")
            } footer: {
                Text("Praktisch, wenn ein Schlüssel oder Scanner liegen geblieben ist.")
            }
        }
        .navigationTitle("Bewegung")
        .onAppear { zeit.bewegung.heuteLaden() }
    }

    private var strecke: String {
        guard let s = schicht else { return "—" }
        let km = Routenhilfe.laenge(s.wegpunkte) / 1000
        return km < 0.05 ? "—" : String(format: "%.2f km", km)
    }

    private var punkte: String {
        "\(schicht?.wegpunkte.count ?? 0)"
    }

    /// Kurzform für die Zeile: wie weit er draußen gekommen ist.
    private func auffaellig(_ s: Schicht) -> String? {
        let m = Wegauswertung.auswerten(s.wegpunkte).gesamtMeter
        return m < 50 ? nil : String(format: "%.1f km", m / 1000)
    }

    private func inKartenAppOeffnen(_ w: Wegpunkt) {
        let ort = CLLocationCoordinate2D(latitude: w.breite, longitude: w.laenge)
        let ziel = MKMapItem(placemark: MKPlacemark(coordinate: ort))
        ziel.name = "Position \(w.zeit.uhrzeit)"
        ziel.openInMaps()
    }
}

private struct Routenkarte: View {
    var punkte: [Wegpunkt]
    var hervorgehoben: Wegpunkt?

    var body: some View {
        Map {
            let koordinaten = Routenhilfe.koordinaten(punkte)
            if koordinaten.count > 1 {
                MapPolyline(coordinates: koordinaten)
                    .stroke(.blue, lineWidth: 4)
            }
            if let erster = koordinaten.first {
                Marker("Start", systemImage: "play.fill", coordinate: erster)
                    .tint(.green)
            }
            if let letzter = koordinaten.last, koordinaten.count > 1 {
                Marker("Letzter Punkt", systemImage: "stop.fill", coordinate: letzter)
                    .tint(.red)
            }
            if let h = hervorgehoben {
                Marker(h.zeit.uhrzeit, systemImage: "mappin",
                       coordinate: CLLocationCoordinate2D(latitude: h.breite, longitude: h.laenge))
                    .tint(.orange)
            }
        }
        .mapStyle(.standard(elevation: .flat))
    }
}
