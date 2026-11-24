import SwiftUI

struct Feiertagsansicht: View {
    @State private var jahr = Calendar.current.component(.year, from: Date())

    var body: some View {
        List {
            Section {
                ForEach(Feiertage.liste(jahr)) { f in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(f.name)
                            Text(f.datum.wochentag)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(f.datum.datumKurz)
                            .monospacedDigit()
                            .foregroundStyle(f.datum < Calendar.current.startOfDay(for: Date()) ? .secondary : .primary)
                    }
                }
            } footer: {
                Text("Gesetzliche Feiertage in Nordrhein-Westfalen. An diesen Tagen rechnet IVT kein Soll; wer trotzdem arbeitet, bekommt die Zeit als Plus.")
            }
        }
        .navigationTitle("Feiertage \(String(jahr))")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { jahr -= 1 } label: { Image(systemName: "chevron.left") }
                Button { jahr += 1 } label: { Image(systemName: "chevron.right") }
            }
        }
    }
}
