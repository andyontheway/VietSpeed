import Foundation
import AVFoundation

public final class VoiceAlertManager: NSObject, AVSpeechSynthesizerDelegate {
    public static let shared = VoiceAlertManager()
    private let synthesizer = AVSpeechSynthesizer()
    private var lastAlertTime: [String: Date] = [:]

    override private init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        // Cấu hình không block UI main thread
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let session = AVAudioSession.sharedInstance()
                // .duckOthers: tự động giảm nhỏ âm lượng nhạc/Google Maps khi có tiếng cảnh báo
                try session.setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
            } catch {
                print("Lỗi cấu hình Audio Session: \(error)")
            }
        }
    }

    /// Phát cảnh báo giọng nói tiếng Việt với khoảng đệm thời gian (cooldown)
    public func speak(key: String, message: String, cooldownSeconds: Double = 12.0) {
        let now = Date()
        if let lastTime = lastAlertTime[key], now.timeIntervalSince(lastTime) < cooldownSeconds {
            return // Còn trong thời gian chờ, không lặp lại
        }
        lastAlertTime[key] = now

        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "vi-VN")
        utterance.rate = 0.52 // Tốc độ nói tự nhiên, rõ ràng khi lái xe
        utterance.pitchMultiplier = 1.05

        DispatchQueue.global(qos: .userInteractive).async {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {}
            DispatchQueue.main.async {
                self.synthesizer.stopSpeaking(at: .immediate)
                self.synthesizer.speak(utterance)
            }
        }
    }

    public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Trả lại âm lượng bình thường cho Google Maps / Nhạc sau khi nói xong
        DispatchQueue.global(qos: .background).async {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    public func alertOverSpeed(limit: Int) {
        speak(
            key: "overspeed_\(limit)",
            message: "Tốc độ giới hạn \(limit). Bạn đang vượt quá tốc độ!",
            cooldownSeconds: 10.0
        )
    }

    public func alertSpeedLimitChanged(newLimit: Int, roadName: String) {
        speak(
            key: "speed_change",
            message: "\(roadName). Giới hạn tốc độ \(newLimit) ki-lô-mét một giờ.",
            cooldownSeconds: 15.0
        )
    }

    public func alertCamera(camera: CameraInfo) {
        let dist = Int(camera.distance)
        speak(
            key: "camera_\(camera.id)",
            message: "Chú ý! Phía trước cách \(dist) mét có \(camera.name), tốc độ \(camera.speedLimit).",
            cooldownSeconds: 30.0
        )
    }
}
