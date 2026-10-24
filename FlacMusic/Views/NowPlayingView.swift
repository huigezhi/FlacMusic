import SwiftUI

/// 全屏播放页：封面模式 / 歌词模式可切换
struct NowPlayingView: View {
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var mode: DisplayMode = .cover
    @State private var dragging = false
    @State private var dragValue = 0.0
    @State private var showQualityPicker = false
    @State private var showAddToPlaylist = false
    @State private var showQueue = false

    enum DisplayMode { case cover, lyrics }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                Spacer(minLength: 10)

                if mode == .cover {
                    coverArt
                        .aspectRatio(1, contentMode: .fit)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 8)
                } else {
                    LyricsView(
                        lines: player.lyrics,
                        currentIndex: LyricParser.currentIndex(
                            at: player.currentTime, in: player.lyrics
                        ),
                        onSeek: { player.seek(toSeconds: $0) }
                    )
                    .padding(.horizontal, 24)
                }

                Spacer(minLength: 10)
                songInfo
                modePicker
                sliderSection
                controls
                actions
            }
            .padding(.bottom, 10)
        }
        .sheet(isPresented: $showQualityPicker) {
            DownloadQualitySheet(songs: currentSongList)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(songs: currentSongList)
        }
        .sheet(isPresented: $showQueue) {
            QueueSheet()
        }
    }

    private var currentSongList: [Song] {
        player.current.map { [$0] } ?? []
    }

    // MARK: - 组件

    private var background: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            if let url = URLValidator.validURL(player.current?.picURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color.clear
                }
                .blur(radius: 70)
                .opacity(0.35)
            }
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Button {
                showQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var coverArt: some View {
        ArtworkView(urlString: player.current?.picURL, cornerRadius: 18)
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
    }

    private var songInfo: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(player.current?.name ?? "未在播放")
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                Text(player.current.map { "\($0.displayArtist) · \($0.displayAlbum)" } ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if let song = player.current {
                Button {
                    store.toggleFavorite(song)
                } label: {
                    Image(systemName: store.isFavorite(song) ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundStyle(store.isFavorite(song) ? Color.red : Color.secondary)
                }
            }
        }
        .padding(.horizontal, 28)
    }

    private var modePicker: some View {
        Picker("显示模式", selection: $mode) {
            Image(systemName: "photo").tag(DisplayMode.cover)
            Image(systemName: "text.alignleft").tag(DisplayMode.lyrics)
        }
        .pickerStyle(.segmented)
        .frame(width: 130)
        .padding(.top, 12)
    }

    private var sliderSection: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { dragging ? dragValue : player.progress },
                    set: { dragValue = $0 }
                ),
                onEditingChanged: { editing in
                    dragging = editing
                    if !editing {
                        player.seek(toFraction: dragValue)
                    }
                }
            )
            .padding(.horizontal, 22)

            HStack {
                Text(timeText(dragging ? dragValue * player.duration : player.currentTime))
                Spacer()
                Text(timeText(player.duration))
            }
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 26)
        }
        .padding(.top, 8)
    }

    private var controls: some View {
        HStack(spacing: 32) {
            Button {
                player.shuffleOn.toggle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.body)
                    .foregroundStyle(player.shuffleOn ? Color.accentColor : Color.secondary)
            }

            Button {
                player.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title2)
            }

            Button {
                player.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .strokeBorder(lineWidth: 1.5)
                        .frame(width: 64, height: 64)
                    if player.buffering {
                        ProgressView()
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .padding(.leading, player.isPlaying ? 0 : 3)
                    }
                }
                .foregroundStyle(.primary)
            }

            Button {
                player.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title2)
            }

            Button {
                player.repeatMode = nextRepeat
            } label: {
                Image(systemName: player.repeatMode.icon)
                    .font(.body)
                    .foregroundStyle(player.repeatMode == .off ? Color.secondary : Color.accentColor)
            }
        }
        .padding(.top, 14)
    }

    private var actions: some View {
        HStack(spacing: 56) {
            Button {
                showQualityPicker = true
            } label: {
                Label("下载", systemImage: "square.and.arrow.down")
                    .font(.footnote)
            }
            Button {
                showAddToPlaylist = true
            } label: {
                Label("歌单", systemImage: "music.note.list")
                    .font(.footnote)
            }
        }
        .buttonStyle(.borderless)
        .disabled(player.current == nil)
        .padding(.top, 12)
    }

    private var nextRepeat: RepeatMode {
        switch player.repeatMode {
        case .off: return .all
        case .all: return .one
        case .one: return .off
        }
    }

    private func timeText(_ t: TimeInterval) -> String {
        guard t.isFinite, t >= 0 else { return "0:00" }
        let s = Int(t)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
