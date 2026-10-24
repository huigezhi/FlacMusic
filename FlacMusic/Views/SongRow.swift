import SwiftUI

/// 歌曲行：封面 + 标题/歌手 + 音质角标 + 「···」菜单（收藏/歌单/下载）
struct SongRow: View {
    let song: Song
    var queue: [Song] = []
    var showsQuality = true
    /// 该歌曲的下载进度（0~1），nil 表示未在下载
    var downloadProgress: Double? = nil

    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var player: PlayerManager

    @State private var showAddToPlaylist = false
    @State private var showQualityPicker = false

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(urlString: song.picURL)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text(song.name)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text("\(song.displayArtist) · \(song.displayAlbum)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let progress = downloadProgress {
                Text("\(Int(progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.tint)
            } else if showsQuality, let tag = song.qualityBadge {
                Text(tag)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(tag == "FLAC" ? Color.red.opacity(0.14) : Color.blue.opacity(0.12))
                    .foregroundStyle(tag == "FLAC" ? Color.red : Color.blue)
                    .clipShape(Capsule())
            }

            Menu {
                if store.isFavorite(song) {
                    Button(role: .destructive) {
                        store.toggleFavorite(song)
                    } label: {
                        Label("取消收藏", systemImage: "heart.slash")
                    }
                } else {
                    Button {
                        store.toggleFavorite(song)
                    } label: {
                        Label("收藏", systemImage: "heart")
                    }
                }
                Button {
                    showAddToPlaylist = true
                } label: {
                    Label("加入歌单", systemImage: "music.note.list")
                }
                if song.minfo?.isEmpty == false {
                    Button {
                        showQualityPicker = true
                    } label: {
                        Label("下载音乐", systemImage: "square.and.arrow.down")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            player.play(song, in: queue.isEmpty ? nil : queue)
        }
        .sheet(isPresented: $showAddToPlaylist) {
            AddToPlaylistSheet(songs: [song])
        }
        .sheet(isPresented: $showQualityPicker) {
            DownloadQualitySheet(songs: [song])
        }
    }
}
