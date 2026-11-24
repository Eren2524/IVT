import Foundation
import Speech
import AVFoundation

/// Sprache zu Text, auf Deutsch.
/// Standard: Erkennung nur auf dem iPhone, nichts verlaesst das Geraet.
/// Optional wird die Aufnahme als Datei mitgeschnitten (Sprachnotizen).
@MainActor
final class Diktierdienst: ObservableObject {

    @Published private(set) var text = ""
    @Published private(set) var laeuft = false
    @Published private(set) var pegel: Float = 0
    @Published private(set) var startZeit: Date?
    @Published var fehler: String?

    /// Datei der letzten Aufnahme (nur wenn mit Ton aufgenommen)
    private(set) var tonURL: URL?
    private(set) var dauer: TimeInterval = 0

    private let erkenner = SFSpeechRecognizer(locale: Locale(identifier: "de-DE"))
    private let motor = AVAudioEngine()
    private let weiche = Weiche()
    private var aufgabe: SFSpeechRecognitionTask?
    /// Text frueherer Abschnitte, falls die Erkennung zwischendurch neu startet
    private var bisher = ""
    private var nurAufGeraet = true
    private var anfrageSeit = Date()

    var kannAufGeraet: Bool { erkenner?.supportsOnDeviceRecognition ?? false }

    // MARK: Rechte

    func rechte() async -> Bool {
        let sprache: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { c in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard sprache == .authorized else {
            fehler = "Spracherkennung ist nicht erlaubt. Einstellungen > IVT > Spracherkennung einschalten."
            return false
        }
        let mikro = await AVAudioApplication.requestRecordPermission()
        guard mikro else {
            fehler = "Mikrofon ist nicht erlaubt. Einstellungen > IVT > Mikrofon einschalten."
            return false
        }
        return true
    }

    // MARK: Start / Stopp

    func starten(mitTon: Bool, nurAufGeraet: Bool) async {
        guard !laeuft else { return }
        fehler = nil
        guard await rechte() else { return }
        guard let erkenner, erkenner.isAvailable else {
            fehler = "Spracherkennung ist gerade nicht verfügbar."
            return
        }
        if nurAufGeraet && !erkenner.supportsOnDeviceRecognition {
            fehler = "Dieses iPhone kann Deutsch nicht ohne Apple-Server erkennen. In IVT > Einstellungen > Diktat kannst du die Apple-Spracherkennung erlauben."
            return
        }
        self.nurAufGeraet = nurAufGeraet

        let sitzung = AVAudioSession.sharedInstance()
        do {
            try sitzung.setCategory(.playAndRecord, mode: .measurement,
                                    options: [.duckOthers, .defaultToSpeaker, .allowBluetooth])
            try sitzung.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            fehler = "Mikrofon konnte nicht gestartet werden."
            return
        }

        text = ""
        bisher = ""
        tonURL = nil
        dauer = 0

        let eingang = motor.inputNode
        let format = eingang.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            fehler = "Kein Mikrofon gefunden."
            return
        }

        if mitTon {
            let url = Ablage.ordner.appendingPathComponent(
                "Diktat-\(Int(Date().timeIntervalSince1970)).m4a")
            let werte: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            if let datei = try? AVAudioFile(forWriting: url, settings: werte,
                                            commonFormat: format.commonFormat,
                                            interleaved: format.isInterleaved) {
                weiche.setzeDatei(datei)
                tonURL = url
            }
        }

        neueAnfrage()
        Diktierdienst.zapfen(eingang, format: format, weiche: weiche) { [weak self] p in
            Task { @MainActor in self?.pegel = p }
        }

        motor.prepare()
        do {
            try motor.start()
        } catch {
            eingang.removeTap(onBus: 0)
            fehler = "Aufnahme konnte nicht starten."
            return
        }
        startZeit = Date()
        laeuft = true
    }

    func stoppen() {
        guard laeuft else { return }
        motor.stop()
        motor.inputNode.removeTap(onBus: 0)
        weiche.beenden()
        laeuft = false
        pegel = 0
        if let s = startZeit { dauer = Date().timeIntervalSince(s) }
        startZeit = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Text von Hand nachbessern, bevor er uebernommen wird
    func ersetzeText(_ neu: String) {
        text = neu
        bisher = neu
    }

    func verwerfen() {
        stoppen()
        aufgabe?.cancel()
        aufgabe = nil
        if let url = tonURL { try? FileManager.default.removeItem(at: url) }
        tonURL = nil
        text = ""
        bisher = ""
    }

    // MARK: Intern

    private func neueAnfrage() {
        guard let erkenner else { return }
        let r = SFSpeechAudioBufferRecognitionRequest()
        r.shouldReportPartialResults = true
        r.addsPunctuation = true
        r.taskHint = .dictation
        if erkenner.supportsOnDeviceRecognition {
            r.requiresOnDeviceRecognition = nurAufGeraet
        }
        weiche.setzeAnfrage(r)
        anfrageSeit = Date()

        aufgabe = erkenner.recognitionTask(with: r) { [weak self] ergebnis, f in
            let satz = ergebnis?.bestTranscription.formattedString
            let fertig = ergebnis?.isFinal ?? false
            let gescheitert = f != nil
            Task { @MainActor in
                guard let self else { return }
                if let satz, !satz.isEmpty {
                    self.text = self.bisher.isEmpty ? satz : self.bisher + " " + satz
                }
                // Erkennung hat aufgehoert, Aufnahme laeuft noch: weitermachen
                if (fertig || gescheitert) && self.laeuft {
                    // Bricht sie sofort wieder ab, stimmt etwas nicht: aufhoeren
                    if Date().timeIntervalSince(self.anfrageSeit) < 2 {
                        self.stoppen()
                        if self.text.isEmpty {
                            self.fehler = "Spracherkennung ist abgebrochen. Nochmal versuchen."
                        }
                    } else {
                        self.bisher = self.text
                        self.neueAnfrage()
                    }
                }
            }
        }
    }

    nonisolated private static func zapfen(_ knoten: AVAudioInputNode,
                                           format: AVAudioFormat,
                                           weiche: Weiche,
                                           pegel: @escaping @Sendable (Float) -> Void) {
        knoten.installTap(onBus: 0, bufferSize: 1024, format: format) { puffer, _ in
            weiche.weiter(puffer)
            pegel(Diktierdienst.messePegel(puffer))
        }
    }

    nonisolated private static func messePegel(_ p: AVAudioPCMBuffer) -> Float {
        guard let k = p.floatChannelData?[0] else { return 0 }
        let n = Int(p.frameLength)
        guard n > 0 else { return 0 }
        var summe: Float = 0
        var anzahl = 0
        var i = 0
        while i < n {
            summe += k[i] * k[i]
            anzahl += 1
            i += 4
        }
        return min(1, sqrt(summe / Float(max(1, anzahl))) * 10)
    }
}

/// Reicht Tonpuffer vom Audio-Thread an die aktuelle Erkennung und Datei weiter.
final class Weiche: @unchecked Sendable {
    private let schloss = NSLock()
    private var anfrage: SFSpeechAudioBufferRecognitionRequest?
    private var datei: AVAudioFile?

    func setzeAnfrage(_ a: SFSpeechAudioBufferRecognitionRequest) {
        schloss.lock()
        let alt = anfrage
        anfrage = a
        schloss.unlock()
        alt?.endAudio()
    }

    func setzeDatei(_ d: AVAudioFile?) {
        schloss.lock(); datei = d; schloss.unlock()
    }

    func weiter(_ puffer: AVAudioPCMBuffer) {
        schloss.lock()
        let a = anfrage, d = datei
        schloss.unlock()
        a?.append(puffer)
        try? d?.write(from: puffer)
    }

    func beenden() {
        schloss.lock()
        let a = anfrage
        anfrage = nil
        datei = nil   // schliesst die Datei
        schloss.unlock()
        a?.endAudio()
    }
}
