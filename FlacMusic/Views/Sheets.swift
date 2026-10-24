import SwiftUI

/// 加入歌单弹层（支持当场新建）
struct AddToPlaylistSheet: View {
    let songs: [Song]

    @EnvironmentObject private var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showCreate = true
                    } label: {
                        Label("新建歌单", systemImage: "plus.circle.fill")
                    }
                }
                Section("添加到") {
                    ForEach(store.playlists) { playlist in
                        Button {
                            var added = false
                            for song in songs {
                                added = store.addToPlaylist(song, playlistID: playlist.id) || added
                            }
                            if added { dismiss() }
                        } label: {
                            HStack {
                                Text(playlist.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if playlist.songs.contains(where: { song in
                                    songs.contains { $0.id == song.id }
                                }) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("加入歌单")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .alert("新建歌单", isPresented: $showCreate) {
                TextField("歌单名称", text: $newName)
                Button("创建并添加") {
                    let playlist = store.createPlaylist(named: newName)
                    for song in songs {
                        _ = store.addToPlaylist(song, playlistID: playlist.id)
                    }
                    newName = ""
                    dismiss()
                }
                Button("取消", role: .cancel) { newName = "" }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// 下载音质选择弹层
struct DownloadQualitySheet: View {
    let songs: [Song]

    @EnvironmentObject private var downloader: DownloadManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(songs) { song in
                    Section {
                        ForEach(song.minfo ?? []) { info in
                            Button {
                                downloader.download(song, quality: info)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(info.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if downloader.active[song.id] != nil {
                                        Text("下载中")
                                            .font(.caption)
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .disabled(downloader.active[song.id] != nil)
                        }
                    } header: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(song.name)
                                .font(.subheadline.weight(.medium))
                            Text("\(song.displayArtist) · 选择下载音质")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("下载")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// 当前播放队列
struct QueueSheet: View {
    @EnvironmentObject private var player: PlayerManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if player.queue.isEmpty {
                    EmptyStateView(systemImage: "list.bullet", title: "播放队列为空")
                } else {
                    List {
                        ForEach(player.queue) { song in
                            HStack(spacing: 10) {
                                if song.id == player.current?.id {
                                    Image(systemName: player.isPlaying ? "waveform" : "speaker.wave.2.fill")
                                        .font(.caption)
                                        .foregroundStyle(.tint)
                                }
                                Text(song.name)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .foregroundStyle(
                                        song.id == player.current?.id ? Color.accentColor : Color.primary
                                    )
                                Spacer(minLength: 8)
                                Text(song.displayArtist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { player.play(song) }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                player.removeFromQueue(player.queue[index])
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("当前播放（\(player.queue.count)）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
