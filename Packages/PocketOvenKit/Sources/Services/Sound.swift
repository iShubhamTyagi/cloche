import Foundation

/// Sound effects. All original (see LICENSES.md); no music.
public enum Sound: String, Sendable, CaseIterable {
    case readyChime = "ready-chime"
}

@MainActor
public protocol SoundPlaying: AnyObject {
    func play(_ sound: Sound)
}

#if canImport(AVFoundation)
import AVFoundation
import os

/// Plays effects through the `.ambient` audio session: the silent switch mutes them and
/// other audio keeps playing (BK-7, Guideline 2.5.9).
@MainActor
public final class AVSoundPlayer: SoundPlaying {
    private var players: [Sound: AVAudioPlayer] = [:]
    private var isSessionConfigured = false
    private let logger = Logger(subsystem: "com.shubhamtyagi.pocketoven", category: "Sound")

    public init() {}

    public func play(_ sound: Sound) {
        configureSessionIfNeeded()
        do {
            let player = try players[sound] ?? makePlayer(sound)
            players[sound] = player
            player.currentTime = 0
            player.play()
        } catch {
            logger.error("Could not play \(sound.rawValue, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makePlayer(_ sound: Sound) throws -> AVAudioPlayer {
        guard let url = Bundle.module.url(forResource: sound.rawValue, withExtension: "wav") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        return player
    }

    private func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            isSessionConfigured = true
        } catch {
            logger.error("Audio session: \(error.localizedDescription, privacy: .public)")
        }
    }
}
#endif
