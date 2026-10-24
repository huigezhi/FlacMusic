import AVFoundation
import MediaPlayer
import UIKit

enum RepeatMode: String, CaseIterable {
    case off
    case all
    case one

    var icon: String {
        switch self {
        case .off, .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    var label: String {
        switch self {
        case .off: return "顺序播放"
        case .all: return "列表循环"
        case .one: return "单曲循环"
        }
    }
}

@MainActor
final class PlayerManager: NSObject, ObservableObject {
    static let shared = PlayerManager()

    @Published private(set) var current: Song?
    @Published private(set) var queue: [Song] = []
    @Published private(set) var isPlaying = false
    @Published private(set) var buffering = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published private(set) var lyrics: [LyricLine] = []
    @Published private(set) var lyricState: LyricState = .idle
    @Published var errorMessage: String?
    @Published var repeatMode: RepeatMode = .all
    @Published var shuffleOn = false

    enum LyricState { case idle, loading, loaded, empty }

    private var player = AVPlayer()
    /// 当前加载请求归属的歌曲 id，用于丢弃过期的异步回调
    private var pendingSongID: String?
    private var artworkCache: [String: UIImage] = [:]

    private override init() {
        super.init()
        configureAudioSession()
        configureRemoteCommands()
        player.automaticallyWaitsToMinimizeStalling = true

        player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in self?.syncProgress(at: time.seconds) }
        }

        NotificationCenter.default.addObserver(
            forName: AVPlayerItemDidPlayToEndTimeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.handleTrackEnded() }
        }
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    // MARK: - 播放控制

    func play(_ song: Song, in list: [Song]? = nil) {
        if let list, !list.isEmpty { queue = list }
        current = song
        pendingSongID = song.id
        isPlaying = false
        buffering = true
        currentTime = 0
        duration = TimeInterval(song.duration ?? 0)
        loadLyrics(for: song)
        updateNowPlayingInfo()
        Task { await startPlayback(song) }
    }

    private func startPlayback(_ song: Song) async {
        do {
            let url: URL
            if let local = LibraryStore.shared.localTrack(for: song) {
                url = DownloadManager.fileURL(named: local.fileName)
            } else if let quality = song.bestQuality {
                url = try await MusicAPI.shared.streamURL(
                    for: song, format: quality.format, bitrate: quality.bitrate
                )
            } else {
                throw APIError.server("该歌曲没有可用音质")
            }
            guard pendingSongID == song.id else { return }

            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            player.play()
            isPlaying = true
            buffering = false
            updateNowPlayingInfo()
            loadArtwork(for: song)

            if let d = try? await item.asset.load(.duration).seconds,
               d.isFinite, d > 0, pendingSongID == song.id {
                duration = d
                updateNowPlayingInfo()
            }
        } catch {
            guard pendingSongID == song.id else { return }
            buffering = false
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func resume() {
        guard current != nil else { return }
        player.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func seek(toSeconds seconds: TimeInterval) {
        let clamped = duration > 0 ? max(0, min(seconds, duration)) : max(0, seconds)
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        currentTime = clamped
        updateNowPlayingInfo()
    }

    func seek(toFraction fraction: Double) {
        guard duration > 0 else { return }
        seek(toSeconds: fraction * duration)
    }

    // MARK: - 队列 / 上下曲

    func removeFromQueue(_ song: Song) {
        queue.removeAll { $0.id == song.id }
    }

    private var currentIndex: Int? {
        guard let current else { return nil }
        return queue.firstIndex { $0.id == current.id }
    }

    private func pickNeighbor(offset: Int) -> Song? {
        guard !queue.isEmpty else { return nil }
        if shuffleOn, queue.count > 1 {
            let candidates = queue.filter { $0.id != current?.id }
            return candidates.randomElement()
        }
        guard let index = currentIndex else { return queue.first }
        var next = index + offset
        if next >= queue.count { next = 0 }
        if next < 0 { next = queue.count - 1 }
        return queue.indices.contains(next) ? queue[next] : nil
    }

    func next() {
        guard let song = pickNeighbor(offset: 1) else { return }
        play(song)
    }

    func previous() {
        if currentTime > 3 {
            seek(toSeconds: 0)
            return
        }
        guard let song = pickNeighbor(offset: -1) else { return }
        play(song)
    }

    private func handleTrackEnded() {
        switch repeatMode {
        case .one:
            if let current { play(current) }
        case .all:
            next()
        case .off:
            if (currentIndex ?? -1) + 1 < queue.count {
                next()
            } else {
                pause()
                currentTime = 0
            }
        }
    }

    // MARK: - 歌词

    private func loadLyrics(for song: Song) {
        lyricState = .loading
        lyrics = []
        Task {
            var text: String?
            if let local = LibraryStore.shared.localTrack(for: song),
               let name = local.lyricFileName {
                text = try? String(contentsOf: DownloadManager.fileURL(named: name), encoding: .utf8)
            }
            if text == nil {
                text = try? await MusicAPI.shared.lyric(for: song)
            }
            guard pendingSongID == song.id else { return }
            guard let text, !text.isEmpty else {
                lyrics = []
                lyricState = .empty
                return
            }
            let parsed = LyricParser.parse(text)
            guard pendingSongID == song.id else { return }
            lyrics = parsed
            lyricState = parsed.isEmpty ? .empty : .loaded
        }
    }

    // MARK: - 进度同步

    private func syncProgress(at seconds: TimeInterval) {
        guard current != nil else { return }
        currentTime = max(0, seconds)
        if duration <= 0, let d = player.currentItem?.duration.seconds, d.isFinite, d > 0 {
            duration = d
        }
    }

    // MARK: - 后台播放与锁屏

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // 配置失败不影响前台播放
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.resume() }
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.pause() }
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.next() }
            return .success
        }
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in self?.previous() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in self?.seek(toSeconds: event.positionTime) }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let song = current else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: song.name,
            MPMediaItemPropertyArtist: song.displayArtist,
            MPMediaItemPropertyAlbumTitle: song.displayAlbum,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let image = artworkCache[song.id] {
            info[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadArtwork(for song: Song) {
        if artworkCache[song.id] != nil {
            updateNowPlayingInfo()
            return
        }
        guard let url = URLValidator.validURL(song.picURL) else { return }
        Task {
            if let (data, _) = try? await URLSession.shared.data(from: url),
               let image = UIImage(data: data) {
                artworkCache[song.id] = image
                if current?.id == song.id { updateNowPlayingInfo() }
            }
        }
    }
}
