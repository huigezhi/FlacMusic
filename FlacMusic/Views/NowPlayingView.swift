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
            GlassControlButton(systemImage: "chevron.down", size: 40, tint: .secondary) {
                dismiss()
            }
            Spacer()
            GlassControlButton(systemImage: "list.bullet", size: 40, tint: .secondary) {
                showQueue = true
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
        Group {
            if #available(iOS 26.0, *) {
                GlassEffectContainer(spacing: 24) {
                    controlCluster
                }
            } else {
                controlCluster
            }
        }
        .padding(.top, 14)
    }

    private var controlCluster: some View {
        HStack(spacing: 18) {
            GlassControlButton(
                systemImage: "shuffle",
                tint: player.shuffleOn ? .accentColor : .secondary
            ) {
                player.shuffleOn.toggle()
            }

            GlassControlButton(systemImage: "backward.fill", font: .title3) {
                player.previous()
            }

            Button {
                player.togglePlayPause()
            } label: {
                Group {
                    if player.buffering {
                        ProgressView()
                    } else {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .padding(.leading, player.isPlaying ? 0 : 4)
                    }
                }
                .foregroundStyle(.primary)
                .frame(width: 70, height: 70)
            }
            .buttonStyle(.plain)
            .glassAdaptive(in: Circle(), interactive: true)

            GlassControlButton(systemImage: "forward.fill", font: .title3) {
                player.next()
            }

            GlassControlButton(
                systemImage: player.repeatMode.icon,
                tint: player.repeatMode == .off ? .secondary : .accentColor
            ) {
                player.repeatMode = nextRepeat
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 18) {
            actionButton("下载", icon: "square.and.arrow.down") {
                showQualityPicker = true
            }
            actionButton("歌单", icon: "music.note.list") {
                showAddToPlaylist = true
            }
        }
        .disabled(player.current == nil)
        .padding(.top, 14)
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .glassAdaptive(in: Capsule())
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
