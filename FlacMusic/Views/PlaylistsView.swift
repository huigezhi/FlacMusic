import SwiftUI

struct PlaylistsView: View {
    @EnvironmentObject private var store: LibraryStore
    @State private var showCreate = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.playlists.isEmpty {
                    EmptyStateView(
                        systemImage: "music.note.list",
                        title: "还没有歌单",
                        subtitle: "点右上角 + 新建歌单，把喜欢的歌归类"
                    )
                } else {
                    List {
                        ForEach(store.playlists) { playlist in
                            NavigationLink {
                                PlaylistDetailView(playlistID: playlist.id)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note.list")
                                        .font(.title3)
                                        .foregroundStyle(.white)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Color.accentColor,
                                            in: RoundedRectangle(cornerRadius: 10)
                                        )
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(playlist.name)
                                            .font(.subheadline.weight(.medium))
                                        Text("\(playlist.songs.count) 首")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.deletePlaylist(store.playlists[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("播放列表")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("新建歌单", isPresented: $showCreate) {
                TextField("歌单名称", text: $newPlaylistName)
                Button("创建") {
                    store.createPlaylist(named: newPlaylistName)
                    newPlaylistName = ""
                }
                Button("取消", role: .cancel) { newPlaylistName = "" }
            } message: {
                Text("给歌单起个名字")
            }
        }
    }
}

struct PlaylistDetailView: View {
    let playlistID: UUID

    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var player: PlayerManager

    private var playlist: Playlist? { store.playlist(with: playlistID) }

    var body: some View {
        Group {
            if let playlist {
                if playlist.songs.isEmpty {
                    EmptyStateView(
                        systemImage: "music.note",
                        title: "歌单是空的",
                        subtitle: "去搜索页把歌加进来"
                    )
                } else {
                    List {
                        ForEach(playlist.songs) { song in
                            SongRow(song: song, queue: playlist.songs)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                store.removeFromPlaylist(
                                    playlist.songs[index], playlistID: playlistID
                                )
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            } else {
                EmptyStateView(systemImage: "questionmark.circle", title: "歌单不存在")
            }
        }
        .navigationTitle(playlist?.name ?? "歌单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let playlist, !playlist.songs.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        player.play(playlist.songs[0], in: playlist.songs)
                    } label: {
                        Label("播放全部", systemImage: "play.circle.fill")
                    }
                }
            }
        }
    }
}
