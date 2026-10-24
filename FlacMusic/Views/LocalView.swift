import SwiftUI

struct LocalView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var player: PlayerManager
    @EnvironmentObject private var downloader: DownloadManager

    var body: some View {
        NavigationStack {
            Group {
                if store.locals.isEmpty {
                    EmptyStateView(
                        systemImage: "internaldrive",
                        title: "本地还没有歌曲",
                        subtitle: "搜索歌曲后点「下载」，FLAC/MP3 会保存到这里，也能在「文件」App 中查看"
                    )
                } else {
                    List {
                        ForEach(store.locals) { track in
                            localRow(track)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                downloader.deleteTrack(store.locals[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("本地")
            .toolbar {
                if !store.locals.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            player.play(store.locals[0].song, in: store.locals.map(\.song))
                        } label: {
                            Label("播放全部", systemImage: "play.circle.fill")
                        }
                    }
                }
            }
        }
    }

    private func localRow(_ track: LocalTrack) -> some View {
        HStack(spacing: 12) {
            ArtworkView(urlString: track.song.picURL)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.song.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(track.song.displayArtist) · \(track.format?.uppercased() ?? "") · \(track.sizeText)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if downloader.active[track.id] != nil {
                ProgressView()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            player.play(track.song, in: store.locals.map(\.song))
        }
    }
}
