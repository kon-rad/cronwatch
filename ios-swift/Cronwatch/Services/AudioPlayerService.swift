import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayerService: ObservableObject {
    @Published private(set) var isPlaying: Bool = false

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var statusObserver: AnyCancellable?

    deinit {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
    }

    func load(urlString: String) -> Bool {
        guard let url = URL(string: urlString), !urlString.isEmpty else {
            return false
        }
        configureSession()
        let item = AVPlayerItem(url: url)
        if let player {
            player.replaceCurrentItem(with: item)
        } else {
            player = AVPlayer(playerItem: item)
        }
        attachEndObserver(to: item)
        return true
    }

    func play() {
        guard let player else { return }
        if player.currentItem == nil { return }
        player.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func toggle() {
        if isPlaying { pause() } else { restartIfFinished(); play() }
    }

    func stop() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        isPlaying = false
    }

    private func restartIfFinished() {
        guard let player, let item = player.currentItem else { return }
        let duration = item.duration.seconds
        if duration.isFinite && player.currentTime().seconds >= duration - 0.05 {
            player.seek(to: .zero)
        }
    }

    private func attachEndObserver(to item: AVPlayerItem) {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.isPlaying = false }
        }
    }

    private func configureSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true, options: [])
        #endif
    }
}
