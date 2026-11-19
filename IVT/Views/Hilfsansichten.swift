import SwiftUI
import UIKit

/// Kamera beziehungsweise Fotoauswahl als SwiftUI-Ansicht.
struct Kameraaufnahme: UIViewControllerRepresentable {
    enum Quelle { case kamera, bibliothek }

    var quelle: Quelle = .kamera
    var fertig: (UIImage) -> Void
    @Environment(\.dismiss) private var schliessen

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController()
        p.delegate = context.coordinator
        if quelle == .kamera, UIImagePickerController.isSourceTypeAvailable(.camera) {
            p.sourceType = .camera
            p.cameraCaptureMode = .photo
        } else {
            p.sourceType = .photoLibrary
        }
        return p
    }

    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(self) }

    final class Koordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let eltern: Kameraaufnahme
        init(_ eltern: Kameraaufnahme) { self.eltern = eltern }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let bild = info[.originalImage] as? UIImage {
                eltern.fertig(bild)
            }
            eltern.schliessen()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            eltern.schliessen()
        }
    }
}

/// Teilen-Dialog fuer PDFs und Bilder.
struct Teilenblatt: UIViewControllerRepresentable {
    var gegenstaende: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: gegenstaende, applicationActivities: nil)
    }

    func updateUIViewController(_ c: UIActivityViewController, context: Context) {}
}

/// PDF-Daten in eine Datei schreiben, damit das Teilen einen Namen hat.
enum Dateiablage {
    static func ablegen(_ daten: Data, name: String) -> URL? {
        let sauber = name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(sauber)
        do {
            try daten.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// Leerzustand im Apple-Stil.
struct Leerzustand: View {
    var symbol: String
    var titel: String
    var text: String
    var knopf: (titel: String, aktion: () -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 44))
                .foregroundStyle(.tertiary)
            Text(titel)
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let knopf {
                Button(knopf.titel, action: knopf.aktion)
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Kleine Huelle, damit eine Datei als .sheet(item:) taugt,
/// ohne URL rueckwirkend Identifiable zu machen.
struct Teilbare: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
    init(_ url: URL) { self.url = url }
}
